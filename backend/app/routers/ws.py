"""
WebSocket endpoints for real-time GPS tracking.

Auth: client sends {"token": "<jwt>"} as the very first message after connecting.
This avoids embedding the token in the URL where it appears in server logs.
"""

import asyncio
import json
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select, update
from jose import JWTError, jwt

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.core.redis_client import is_token_blocked
from app.models.models import User, Driver, Ride, RideStatus
from app.services.ws_manager import location_manager

router = APIRouter()

_AUTH_TIMEOUT_SECONDS = 5


async def _auth_user(token: str) -> User | None:
    """Decode JWT, check blocklist, return the User or None."""
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id = payload.get("sub")
        jti = payload.get("jti")
        if not user_id or not jti:
            return None
        # #6 Reject revoked tokens
        if await is_token_blocked(jti):
            return None
    except JWTError:
        return None

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
    return user if (user and user.is_active) else None


async def _receive_auth(websocket: WebSocket) -> str | None:
    """Wait up to _AUTH_TIMEOUT_SECONDS for {"token": "..."} from the client."""
    try:
        raw = await asyncio.wait_for(
            websocket.receive_text(), timeout=_AUTH_TIMEOUT_SECONDS
        )
        data = json.loads(raw)
        return data.get("token") if isinstance(data, dict) else None
    except (asyncio.TimeoutError, json.JSONDecodeError, Exception):
        return None


def _valid_coords(lat: float, lng: float) -> bool:
    """#7 Reject out-of-range GPS coordinates."""
    return -90 <= lat <= 90 and -180 <= lng <= 180


# The mobile client sends a GPS update roughly every 5s; a much smaller floor
# still leaves headroom for jitter/retries while stopping a buggy or
# malicious client from flooding the DB write + Redis publish on every frame.
_MIN_LOCATION_UPDATE_INTERVAL_SECONDS = 1.0


# ── Driver → streams GPS ──────────────────────────────────────────────────────


@router.websocket("/driver/{ride_id}")
async def driver_location_ws(websocket: WebSocket, ride_id: str):
    await websocket.accept()

    # #4 Auth via first message, not query param
    token = await _receive_auth(websocket)
    user = await _auth_user(token) if token else None
    if not user or "driver" not in user.held_roles:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    async with AsyncSessionLocal() as db:
        ride_row = await db.execute(select(Ride).where(Ride.id == ride_id))
        ride = ride_row.scalar_one_or_none()
        driver_row = await db.execute(select(Driver).where(Driver.user_id == user.id))
        driver = driver_row.scalar_one_or_none()

    if not ride or not driver or ride.driver_id != driver.id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    last_update_at: float | None = None

    try:
        while True:
            data = await websocket.receive_json()
            lat, lng = float(data["lat"]), float(data["lng"])

            # #7 Validate coordinates before persisting
            if not _valid_coords(lat, lng):
                await websocket.send_json({"error": "invalid coordinates"})
                continue

            now_monotonic = asyncio.get_event_loop().time()
            if (
                last_update_at is not None
                and now_monotonic - last_update_at
                < _MIN_LOCATION_UPDATE_INTERVAL_SECONDS
            ):
                await websocket.send_json({"error": "rate_limited"})
                continue
            last_update_at = now_monotonic

            async with AsyncSessionLocal() as db:
                await db.execute(
                    update(Driver)
                    .where(Driver.id == driver.id)
                    .values(
                        current_lat=lat,
                        current_lng=lng,
                        last_seen_at=datetime.now(timezone.utc),
                    )
                )
                await db.commit()

            await location_manager.publish(ride_id, lat, lng)
            await websocket.send_json({"ack": True, "lat": lat, "lng": lng})

    except WebSocketDisconnect:
        pass
    except Exception:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)


# ── Patient/family → watches driver location ──────────────────────────────────


@router.websocket("/ride/{ride_id}")
async def ride_tracking_ws(websocket: WebSocket, ride_id: str):
    await websocket.accept()

    # #4 Auth via first message, not query param
    token = await _receive_auth(websocket)
    user = await _auth_user(token) if token else None
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    async with AsyncSessionLocal() as db:
        ride_row = await db.execute(select(Ride).where(Ride.id == ride_id))
        ride = ride_row.scalar_one_or_none()

    if not ride:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Authorize by held_roles + actual relationship to the ride. Using the
    # active portal here would let a multi-role user in driver portal watch
    # any ride's GPS stream.
    authorized = "admin" in user.held_roles
    if not authorized and "patient" in user.held_roles:
        async with AsyncSessionLocal() as db:
            from app.models.models import Patient

            p = (
                await db.execute(select(Patient).where(Patient.user_id == user.id))
            ).scalar_one_or_none()
        authorized = p is not None and ride.patient_id == p.id
    if not authorized and "driver" in user.held_roles:
        async with AsyncSessionLocal() as db:
            d = (
                await db.execute(select(Driver).where(Driver.user_id == user.id))
            ).scalar_one_or_none()
        authorized = d is not None and ride.driver_id == d.id
    if not authorized:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    pubsub = await location_manager.subscribe(ride_id)
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            # Re-read the status from the DB — the `ride` object fetched before
            # the loop is stale, and a cancelled/completed ride must stop
            # streaming GPS to the client.
            async with AsyncSessionLocal() as db:
                current_status = (
                    await db.execute(select(Ride.status).where(Ride.id == ride_id))
                ).scalar_one_or_none()
            if current_status in (RideStatus.completed, RideStatus.cancelled, None):
                ended = current_status.value if current_status else "deleted"
                await websocket.send_json({"event": "ride_ended", "status": ended})
                break
            await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await pubsub.unsubscribe()
        await pubsub.aclose()
