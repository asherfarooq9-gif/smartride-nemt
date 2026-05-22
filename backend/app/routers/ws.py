"""
WebSocket endpoints for real-time GPS tracking.

Auth: JWT passed as ?token= query param (WebSocket handshake can't carry headers
in most mobile clients, so query-param is the standard workaround).
"""
import json
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, status
from sqlalchemy import select, update
from jose import JWTError, jwt

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.models import User, Driver, Ride, RideStatus, DriverStatus
from app.services.ws_manager import location_manager

router = APIRouter()


async def _auth_user(token: str) -> User | None:
    """Decode JWT and return the User, or None on failure."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            return None
    except JWTError:
        return None

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
    return user if (user and user.is_active) else None


# ── Driver → streams GPS ──────────────────────────────────────────────────────

@router.websocket("/driver/{ride_id}")
async def driver_location_ws(
    websocket: WebSocket,
    ride_id: str,
    token: str = Query(...),
):
    user = await _auth_user(token)
    if not user or user.role.value != "driver":
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Verify this driver is assigned to the ride
    async with AsyncSessionLocal() as db:
        ride_row = await db.execute(select(Ride).where(Ride.id == ride_id))
        ride = ride_row.scalar_one_or_none()
        driver_row = await db.execute(select(Driver).where(Driver.user_id == user.id))
        driver = driver_row.scalar_one_or_none()

    if not ride or not driver or ride.driver_id != driver.id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            lat, lng = float(data["lat"]), float(data["lng"])

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
async def ride_tracking_ws(
    websocket: WebSocket,
    ride_id: str,
    token: str = Query(...),
):
    user = await _auth_user(token)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Patient must own the ride; driver must be assigned; admin sees all
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

    await websocket.accept()
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
