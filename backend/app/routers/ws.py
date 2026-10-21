"""
WebSocket endpoints for real-time GPS tracking.

Auth: client sends {"token": "<jwt>"} as the very first message after connecting.
This avoids embedding the token in the URL where it appears in server logs.
"""

import asyncio
import json
import time
import uuid
from collections import Counter
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select, update
import jwt

from app.core.security import decode_token
from app.core.database import AsyncSessionLocal
from app.core.redis_client import is_token_blocked
from app.models.models import User, Driver, Ride, RideStatus
from app.services.ws_manager import location_manager

router = APIRouter()

_AUTH_TIMEOUT_SECONDS = 5
_IDLE_TIMEOUT_SECONDS = 60  # a driver app sends GPS every few seconds
_MIN_GPS_INTERVAL_SECONDS = 0.2  # more than ~5 updates/s is abuse, not tracking
_MAX_STRIKES = 10  # bad or too-fast frames tolerated before the socket is closed
_MAX_SOCKETS_PER_USER = 5
_PING_SECONDS = 15
_ACTIVE = (
    RideStatus.driver_assigned,
    RideStatus.driver_en_route,
    RideStatus.patient_picked_up,
    RideStatus.arrived_at_hospital,
)

# Per-process cap on simultaneous sockets per user (stops one account hoarding connections).
_open_sockets: Counter = Counter()


def _expired(token: str) -> bool:
    try:
        return decode_token(token)["exp"] <= time.time()
    except jwt.PyJWTError:
        return True


async def _auth_user(token: str) -> User | None:
    """Decode JWT, check blocklist, return the User or None."""
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        jti = payload.get("jti")
        if not user_id or not jti:
            return None
        # #6 Reject revoked tokens
        if await is_token_blocked(jti):
            return None
    except jwt.PyJWTError:
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


# ── Driver → streams GPS ──────────────────────────────────────────────────────


@router.websocket("/driver/{ride_id}")
async def driver_location_ws(websocket: WebSocket, ride_id: str):
    await websocket.accept()
    try:
        uuid.UUID(ride_id)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

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

    if _open_sockets[user.id] >= _MAX_SOCKETS_PER_USER:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    _open_sockets[user.id] += 1
    strikes, last_update = 0, 0.0
    try:
        while True:
            try:
                data = await asyncio.wait_for(
                    websocket.receive_json(), timeout=_IDLE_TIMEOUT_SECONDS
                )
            except asyncio.TimeoutError:
                await websocket.close(code=status.WS_1001_GOING_AWAY)
                return
            if _expired(token):
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return

            now = time.monotonic()
            try:
                lat, lng = float(data["lat"]), float(data["lng"])
                ok = (
                    _valid_coords(lat, lng)
                    and (now - last_update) >= _MIN_GPS_INTERVAL_SECONDS
                )
            except (KeyError, TypeError, ValueError):
                ok = False
            if not ok:
                strikes += 1
                if strikes >= _MAX_STRIKES:
                    await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                    return
                await websocket.send_json({"error": "invalid or too frequent update"})
                continue
            last_update = now

            # Only a live ride may be streamed to; a finished one ends the socket.
            async with AsyncSessionLocal() as db:
                ride_status = (
                    await db.execute(select(Ride.status).where(Ride.id == ride_id))
                ).scalar_one_or_none()
            if ride_status not in _ACTIVE:
                await websocket.send_json({"event": "ride_ended"})
                await websocket.close(code=status.WS_1000_NORMAL_CLOSURE)
                return

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
    finally:
        _open_sockets[user.id] -= 1


# ── Patient/family → watches driver location ──────────────────────────────────


@router.websocket("/ride/{ride_id}")
async def ride_tracking_ws(websocket: WebSocket, ride_id: str):
    await websocket.accept()
    try:
        uuid.UUID(ride_id)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

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

    if _open_sockets[user.id] >= _MAX_SOCKETS_PER_USER:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    _open_sockets[user.id] += 1
    pubsub = await location_manager.subscribe(ride_id)
    try:
        while True:
            # Wake at least every _PING_SECONDS even when the driver is silent, so an
            # ended ride or an expired token closes the socket and a dead client is
            # noticed when the ping fails.
            message = await pubsub.get_message(
                ignore_subscribe_messages=True, timeout=_PING_SECONDS
            )
            if _expired(token):
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                break
            # Re-read the status from the DB: a cancelled or completed ride must
            # stop streaming GPS to the client.
            async with AsyncSessionLocal() as db:
                current_status = (
                    await db.execute(select(Ride.status).where(Ride.id == ride_id))
                ).scalar_one_or_none()
            if current_status in (RideStatus.completed, RideStatus.cancelled, None):
                ended = current_status.value if current_status else "deleted"
                await websocket.send_json({"event": "ride_ended", "status": ended})
                break
            if message is None:
                await websocket.send_json({"event": "ping"})
            else:
                await websocket.send_text(message["data"])
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        _open_sockets[user.id] -= 1
        await pubsub.unsubscribe()
        await pubsub.aclose()
