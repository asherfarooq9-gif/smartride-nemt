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
from app.models.models import User, Driver, Ride, RideStatus, DriverStatus
from app.services.ws_manager import location_manager

router = APIRouter()

_AUTH_TIMEOUT_SECONDS = 5


async def _auth_user(token: str) -> User | None:
    """Decode JWT, check blocklist, return the User or None."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
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
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=_AUTH_TIMEOUT_SECONDS)
        data = json.loads(raw)
        return data.get("token") if isinstance(data, dict) else None
    except (asyncio.TimeoutError, json.JSONDecodeError, Exception):
        return None


def _valid_coords(lat: float, lng: float) -> bool:
    """#7 Reject out-of-range GPS coordinates."""
    return -90 <= lat <= 90 and -180 <= lng <= 180


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

    try:
        while True:
            data = await websocket.receive_json()
            lat, lng = float(data["lat"]), float(data["lng"])

            # #7 Validate coordinates before persisting
            if not _valid_coords(lat, lng):
                await websocket.send_json({"error": "invalid coordinates"})
                continue

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

    role = user.role.value
    if role == "patient":
        async with AsyncSessionLocal() as db:
            from app.models.models import Patient
            p = (await db.execute(select(Patient).where(Patient.user_id == user.id))).scalar_one_or_none()
        if not p or ride.patient_id != p.id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    elif role == "driver":
        async with AsyncSessionLocal() as db:
            d = (await db.execute(select(Driver).where(Driver.user_id == user.id))).scalar_one_or_none()
        if not d or ride.driver_id != d.id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
    # admin: no further check

    pubsub = await location_manager.subscribe(ride_id)
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            if ride.status in (RideStatus.completed, RideStatus.cancelled):
                await websocket.send_json({"event": "ride_ended", "status": ride.status.value})
                break
            await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await pubsub.unsubscribe()
        await pubsub.aclose()
