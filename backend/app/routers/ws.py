"""
WebSocket endpoints for real-time GPS tracking.

Auth: client sends {"token": "<jwt>"} as the very first message after connecting.
This avoids embedding the token in the URL where it appears in server logs.

All connection counters here (_open_sockets, _preauth_sockets) are per process:
with several workers/instances each one enforces the caps on its own.
"""

import asyncio
import json
import logging
import os
import time
import uuid
from collections import Counter
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status
from redis.exceptions import RedisError
from sqlalchemy import select, update
from sqlalchemy.exc import SQLAlchemyError
import jwt

from app.core.security import decode_token
from app.core.database import AsyncSessionLocal
from app.core.redis_client import is_token_blocked
from app.models.models import User, Driver, Patient, Ride, RideStatus
from app.services.ws_manager import location_manager

router = APIRouter()
log = logging.getLogger("smartride.ws")

_AUTH_TIMEOUT_SECONDS = 5
_IDLE_TIMEOUT_SECONDS = 60  # a driver app sends GPS every few seconds
_MIN_GPS_INTERVAL_SECONDS = 0.2  # more than ~5 updates/s is abuse, not tracking
_MAX_STRIKES = 10  # bad or too-fast frames tolerated before the socket is closed
_MAX_SOCKETS_PER_USER = 5
_PING_SECONDS = 15
# Every frame is relayed to watchers, but the driver row and the ride status are
# only touched this often, so a 5 Hz GPS feed is not 5 write transactions/second.
_GPS_PERSIST_INTERVAL_SECONDS = float(os.getenv("WS_GPS_PERSIST_INTERVAL_SECONDS", "5"))
# Sockets that have connected but not authenticated yet, per client IP. Behind a
# reverse proxy this is the proxy's IP unless uvicorn runs with --proxy-headers.
_MAX_PREAUTH_PER_IP = int(os.getenv("WS_MAX_PREAUTH_PER_IP", "20"))
_ACTIVE = (
    RideStatus.driver_assigned,
    RideStatus.driver_en_route,
    RideStatus.patient_picked_up,
    RideStatus.arrived_at_hospital,
)
_REDIS_ERRORS = (RedisError, OSError, asyncio.TimeoutError)

# Per-process cap on simultaneous sockets per user (stops one account hoarding connections).
_open_sockets: Counter = Counter()
# Per-process cap on unauthenticated sockets per client IP.
_preauth_sockets: Counter = Counter()


def _acquire_slot(user_id) -> bool:
    if _open_sockets[user_id] >= _MAX_SOCKETS_PER_USER:
        return False
    _open_sockets[user_id] += 1
    return True


def _release_slot(user_id) -> None:
    _open_sockets[user_id] -= 1
    if _open_sockets[user_id] <= 0:
        del _open_sockets[user_id]


def _client_ip(websocket: WebSocket) -> str:
    return websocket.client.host if websocket.client else "unknown"


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
    """Wait up to _AUTH_TIMEOUT_SECONDS for {"token": "..."} from the client.

    Each way the handshake can fail is logged with its reason (never the token);
    anything unexpected propagates instead of being reported as a bad login.
    """
    try:
        raw = await asyncio.wait_for(
            websocket.receive_text(), timeout=_AUTH_TIMEOUT_SECONDS
        )
    except asyncio.TimeoutError:
        log.info("ws auth failed: no first message within %ss", _AUTH_TIMEOUT_SECONDS)
        return None
    except WebSocketDisconnect:
        log.debug("ws client left before authenticating")
        return None
    except KeyError:  # a binary frame has no "text" part
        log.info("ws auth failed: first message was not a text frame")
        return None

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        log.info("ws auth failed: first message was not valid JSON")
        return None
    token = data.get("token") if isinstance(data, dict) else None
    if not isinstance(token, str) or not token:
        log.info("ws auth failed: first message had no token")
        return None
    return token


def _valid_coords(lat: float, lng: float) -> bool:
    """#7 Reject out-of-range GPS coordinates."""
    return -90 <= lat <= 90 and -180 <= lng <= 180


async def _accept_and_authenticate(
    websocket: WebSocket, ride_id: str
) -> tuple[User, str] | None:
    """Accept, validate the ride id and authenticate. Closes the socket on failure.

    The number of connections that have not authenticated yet is capped per IP;
    over the cap the handshake is refused before it is accepted.
    """
    ip = _client_ip(websocket)
    if _preauth_sockets[ip] >= _MAX_PREAUTH_PER_IP:
        log.warning("ws refused: too many unauthenticated sockets from ip=%s", ip)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None
    _preauth_sockets[ip] += 1
    try:
        await websocket.accept()
        try:
            uuid.UUID(ride_id)
        except ValueError:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return None
        # #4 Auth via first message, not query param
        token = await _receive_auth(websocket)
        user = await _auth_user(token) if token else None
    finally:
        _preauth_sockets[ip] -= 1
        if _preauth_sockets[ip] <= 0:
            del _preauth_sockets[ip]

    if user is None:
        log.info("ws auth rejected for ride %s", ride_id)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None
    return user, token


async def _close_on_error(websocket: WebSocket, ride_id: str) -> None:
    """Log the active exception and close with 1011; a failing close is only noted."""
    log.exception("websocket handler failed for ride %s", ride_id)
    try:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
    except Exception:  # noqa: BLE001 - the socket may already be dead
        log.debug("close after error failed for ride %s", ride_id, exc_info=True)


async def _publish_safely(ride_id: str, lat: float, lng: float) -> None:
    """A Redis blip drops one GPS frame for watchers; it must not end the stream."""
    try:
        await location_manager.publish(ride_id, lat, lng)
    except _REDIS_ERRORS:
        log.warning(
            "GPS publish failed for ride %s; frame dropped", ride_id, exc_info=True
        )


async def _close_pubsub(pubsub, ride_id: str) -> None:
    for step in (pubsub.unsubscribe, pubsub.aclose):
        try:
            await step()
        except _REDIS_ERRORS:
            log.warning("pubsub cleanup failed for ride %s", ride_id, exc_info=True)


# ── Driver → streams GPS ──────────────────────────────────────────────────────


async def _load_driver_ride(
    user: User, ride_id: str
) -> tuple[Ride | None, Driver | None]:
    async with AsyncSessionLocal() as db:
        ride = (
            await db.execute(select(Ride).where(Ride.id == ride_id))
        ).scalar_one_or_none()
        driver = (
            await db.execute(select(Driver).where(Driver.user_id == user.id))
        ).scalar_one_or_none()
    return ride, driver


async def _persist_location(ride_id: str, driver_id, lat: float, lng: float) -> bool:
    """Save the driver's position in one transaction. False once the ride is over.

    A database failure is logged and treated as "still active": watchers keep
    getting GPS from Redis and the next interval retries the write.
    """
    try:
        async with AsyncSessionLocal() as db:
            ride_status = (
                await db.execute(select(Ride.status).where(Ride.id == ride_id))
            ).scalar_one_or_none()
            if ride_status not in _ACTIVE:
                return False
            await db.execute(
                update(Driver)
                .where(Driver.id == driver_id)
                .values(
                    current_lat=lat,
                    current_lng=lng,
                    last_seen_at=datetime.now(timezone.utc),
                )
            )
            await db.commit()
    except (SQLAlchemyError, OSError):
        log.warning(
            "GPS persist failed for ride %s; streaming continues",
            ride_id,
            exc_info=True,
        )
    return True


def _parse_frame(data, seconds_since_last: float) -> tuple[float, float] | None:
    """(lat, lng) from a valid, not-too-frequent frame, else None."""
    try:
        lat, lng = float(data["lat"]), float(data["lng"])
    except (KeyError, TypeError, ValueError):
        return None
    if not _valid_coords(lat, lng) or seconds_since_last < _MIN_GPS_INTERVAL_SECONDS:
        return None
    return lat, lng


async def _receive_frame(websocket: WebSocket):
    """The next JSON frame; undecodable text comes back as None (an invalid frame)."""
    try:
        return await asyncio.wait_for(
            websocket.receive_json(), timeout=_IDLE_TIMEOUT_SECONDS
        )
    except json.JSONDecodeError:
        return None


async def _stream_driver_gps(
    websocket: WebSocket, ride_id: str, driver_id, token: str
) -> None:
    strikes, last_update, last_persist = 0, 0.0, None
    while True:
        try:
            data = await _receive_frame(websocket)
        except asyncio.TimeoutError:
            await websocket.close(code=status.WS_1001_GOING_AWAY)
            return
        if _expired(token):
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        now = time.monotonic()
        position = _parse_frame(data, now - last_update)
        if position is None:
            strikes += 1
            if strikes >= _MAX_STRIKES:
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return
            await websocket.send_json({"error": "invalid or too frequent update"})
            continue
        last_update = now
        lat, lng = position

        # Only a live ride may be streamed to; a finished one ends the socket.
        if last_persist is None or now - last_persist >= _GPS_PERSIST_INTERVAL_SECONDS:
            last_persist = now
            if not await _persist_location(ride_id, driver_id, lat, lng):
                await websocket.send_json({"event": "ride_ended"})
                await websocket.close(code=status.WS_1000_NORMAL_CLOSURE)
                return

        await _publish_safely(ride_id, lat, lng)
        await websocket.send_json({"ack": True, "lat": lat, "lng": lng})


@router.websocket("/driver/{ride_id}")
async def driver_location_ws(websocket: WebSocket, ride_id: str):
    auth = await _accept_and_authenticate(websocket, ride_id)
    if auth is None:
        return
    user, token = auth
    if "driver" not in user.held_roles:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    ride, driver = await _load_driver_ride(user, ride_id)
    if not ride or not driver or ride.driver_id != driver.id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    if not _acquire_slot(user.id):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    try:
        await _stream_driver_gps(websocket, ride_id, driver.id, token)
    except WebSocketDisconnect:
        pass
    except Exception:
        await _close_on_error(websocket, ride_id)
    finally:
        _release_slot(user.id)


# ── Patient/family → watches driver location ──────────────────────────────────


async def _may_watch(user: User, ride: Ride) -> bool:
    """Authorize by held_roles + actual relationship to the ride. Using the
    active portal here would let a multi-role user in driver portal watch
    any ride's GPS stream."""
    held = user.held_roles
    if "admin" in held:
        return True
    async with AsyncSessionLocal() as db:
        if "patient" in held:
            p = (
                await db.execute(select(Patient).where(Patient.user_id == user.id))
            ).scalar_one_or_none()
            if p is not None and ride.patient_id == p.id:
                return True
        if "driver" in held:
            d = (
                await db.execute(select(Driver).where(Driver.user_id == user.id))
            ).scalar_one_or_none()
            if d is not None and ride.driver_id == d.id:
                return True
    return False


async def _relay_location(
    websocket: WebSocket, ride_id: str, pubsub, token: str
) -> None:
    while True:
        # Wake at least every _PING_SECONDS even when the driver is silent, so an
        # ended ride or an expired token closes the socket and a dead client is
        # noticed when the ping fails.
        message = await pubsub.get_message(
            ignore_subscribe_messages=True, timeout=_PING_SECONDS
        )
        if _expired(token):
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
        # Re-read the status from the DB: a cancelled or completed ride must
        # stop streaming GPS to the client.
        async with AsyncSessionLocal() as db:
            current_status = (
                await db.execute(select(Ride.status).where(Ride.id == ride_id))
            ).scalar_one_or_none()
        if current_status in (RideStatus.completed, RideStatus.cancelled, None):
            ended = current_status.value if current_status else "deleted"
            await websocket.send_json({"event": "ride_ended", "status": ended})
            return
        if message is None:
            await websocket.send_json({"event": "ping"})
        else:
            await websocket.send_text(message["data"])


@router.websocket("/ride/{ride_id}")
async def ride_tracking_ws(websocket: WebSocket, ride_id: str):
    auth = await _accept_and_authenticate(websocket, ride_id)
    if auth is None:
        return
    user, token = auth

    async with AsyncSessionLocal() as db:
        ride = (
            await db.execute(select(Ride).where(Ride.id == ride_id))
        ).scalar_one_or_none()
    if not ride or not await _may_watch(user, ride):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    if not _acquire_slot(user.id):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    pubsub = None
    try:
        pubsub = await location_manager.subscribe(ride_id)
        await _relay_location(websocket, ride_id, pubsub, token)
    except WebSocketDisconnect:
        pass
    except Exception:
        await _close_on_error(websocket, ride_id)
    finally:
        _release_slot(user.id)
        if pubsub is not None:
            await _close_pubsub(pubsub, ride_id)
