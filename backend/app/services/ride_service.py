import logging
from datetime import datetime, timezone
from math import radians, sin, cos, sqrt, atan2
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func, and_, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core import metrics

from app.models.models import (
    Ride,
    Patient,
    Driver,
    User,
    TriageEvent,
    RideType,
    RideStatus,
    DriverStatus,
)
from app.schemas.rides import (
    EmergencyRideRequest,
    ScheduledRideRequest,
    RideStatusUpdate,
)

log = logging.getLogger("smartride.rides")

# Cap the dispatch list: drivers only ever see the nearest pending rides, and
# loading every pending ride in the city into memory does not scale.
PENDING_RIDES_LIMIT = 100


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = (
        sin(dlat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    )
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))


DRIVER_TRANSITIONS = {
    RideStatus.driver_assigned: RideStatus.driver_en_route,
    RideStatus.driver_en_route: RideStatus.patient_picked_up,
    RideStatus.patient_picked_up: RideStatus.arrived_at_hospital,
    RideStatus.arrived_at_hospital: RideStatus.completed,
}


async def get_patient_by_user(user: User, db: AsyncSession) -> Patient:
    result = await db.execute(select(Patient).where(Patient.user_id == user.id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, "Patient profile not found")
    return patient


async def get_driver_by_user(user: User, db: AsyncSession) -> Driver:
    result = await db.execute(select(Driver).where(Driver.user_id == user.id))
    driver = result.scalar_one_or_none()
    if not driver:
        raise HTTPException(404, "Driver profile not found")
    return driver


async def create_emergency_ride(
    patient: Patient, body: EmergencyRideRequest, db: AsyncSession
) -> Ride:
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.emergency,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
    )
    db.add(ride)
    await db.commit()
    await db.refresh(ride)
    return ride


async def create_scheduled_ride(
    patient: Patient, body: ScheduledRideRequest, db: AsyncSession
) -> Ride:
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.scheduled,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
        dropoff_lat=body.dropoff_lat,
        dropoff_lng=body.dropoff_lng,
        dropoff_address=body.dropoff_address,
        scheduled_for=body.scheduled_for,
    )
    db.add(ride)
    await db.commit()
    await db.refresh(ride)
    return ride


async def get_ride_by_id(ride_id: str, db: AsyncSession) -> Ride:
    result = await db.execute(select(Ride).where(Ride.id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(404, "Ride not found")
    return ride


async def get_ride_with_relations(ride_id: str, db: AsyncSession) -> Ride:
    result = await db.execute(
        select(Ride)
        .where(Ride.id == ride_id)
        .options(
            selectinload(Ride.patient).selectinload(Patient.user),
            selectinload(Ride.driver).selectinload(Driver.user),
            selectinload(Ride.hospital),
        )
    )
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(404, "Ride not found")
    return ride


async def get_my_rides(
    user: User, db: AsyncSession, page: int, page_size: int
) -> tuple[list[Ride], int]:
    if "patient" in user.held_roles and user.role.value == "patient":
        patient = await get_patient_by_user(user, db)
        condition = Ride.patient_id == patient.id
    elif "driver" in user.held_roles:
        driver = await get_driver_by_user(user, db)
        condition = Ride.driver_id == driver.id
    else:
        raise HTTPException(403, "Forbidden")

    total = (
        await db.execute(select(func.count()).select_from(Ride).where(condition))
    ).scalar()
    rows = (
        (
            await db.execute(
                select(Ride)
                .where(condition)
                .order_by(Ride.requested_at.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        .scalars()
        .all()
    )
    return list(rows), total


async def get_triage_for_ride(ride_id: str, db: AsyncSession) -> Optional[TriageEvent]:
    result = await db.execute(
        select(TriageEvent)
        .where(TriageEvent.ride_id == ride_id)
        .order_by(TriageEvent.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def update_ride_status(
    ride: Ride,
    body: RideStatusUpdate,
    role: str,
    db: AsyncSession,
    patient: Optional[Patient] = None,
    driver: Optional[Driver] = None,
) -> Ride:
    new_status = body.status

    if role == "driver":
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Not your ride")
        allowed_next = DRIVER_TRANSITIONS.get(ride.status)
        if new_status == RideStatus.cancelled:
            ride.status = RideStatus.cancelled
            ride.cancelled_at = datetime.now(timezone.utc)
            driver.status = DriverStatus.available
        elif new_status != allowed_next:
            raise HTTPException(
                400, f"Cannot transition from {ride.status} to {new_status}"
            )
        else:
            ride.status = new_status
            now = datetime.now(timezone.utc)
            if new_status == RideStatus.patient_picked_up:
                ride.pickup_at = now
            elif new_status == RideStatus.arrived_at_hospital:
                ride.arrived_at = now
            elif new_status == RideStatus.completed:
                ride.completed_at = now
                driver.status = DriverStatus.available

    elif role == "admin":
        if new_status != RideStatus.cancelled:
            raise HTTPException(400, "Admin can only cancel rides")
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
        ride.cancel_reason = "Cancelled by admin"
        if ride.driver_id is not None:
            assigned_driver = (
                await db.execute(select(Driver).where(Driver.id == ride.driver_id))
            ).scalar_one_or_none()
            if assigned_driver:
                assigned_driver.status = DriverStatus.available

    elif role == "patient":
        if ride.patient_id != patient.id:
            raise HTTPException(403, "Not your ride")
        if new_status != RideStatus.cancelled:
            raise HTTPException(400, "Patient can only cancel rides")
        if ride.status not in (RideStatus.pending, RideStatus.driver_assigned):
            raise HTTPException(400, "Cannot cancel ride in current state")
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
        ride.cancel_reason = body.cancel_reason or "Cancelled by patient"

    else:
        raise HTTPException(403, "Forbidden")

    await db.commit()
    await db.refresh(ride)

    # Push notification to patient on status change
    try:
        from app.services.notifications import send_push_to_user

        patient_user = (
            await db.execute(
                select(User)
                .join(Patient, Patient.user_id == User.id)
                .where(Patient.id == ride.patient_id)
            )
        ).scalar_one_or_none()
        if patient_user:
            labels = {
                RideStatus.driver_assigned: (
                    "Driver Assigned",
                    "Your driver is on the way!",
                ),
                RideStatus.driver_en_route: (
                    "Driver En Route",
                    "Your driver is heading to you.",
                ),
                RideStatus.patient_picked_up: (
                    "Picked Up",
                    "You're on the way to the hospital.",
                ),
                RideStatus.arrived_at_hospital: (
                    "Arrived",
                    "You have arrived at the hospital.",
                ),
                RideStatus.completed: (
                    "Ride Complete",
                    "Your ride has been completed.",
                ),
                RideStatus.cancelled: (
                    "Ride Cancelled",
                    ride.cancel_reason or "Your ride was cancelled.",
                ),
            }
            if ride.status in labels:
                title, body_text = labels[ride.status]
                await send_push_to_user(
                    db,
                    patient_user.id,
                    title=title,
                    body=body_text,
                    data={"ride_id": str(ride.id)},
                )

        # A driver already en route has no other way to learn the ride was
        # pulled out from under them — patient/admin cancellation must reach
        # them directly. Not needed when the driver cancelled it themselves.
        if (
            ride.status == RideStatus.cancelled
            and role != "driver"
            and ride.driver_id is not None
        ):
            driver_user = (
                await db.execute(
                    select(User)
                    .join(Driver, Driver.user_id == User.id)
                    .where(Driver.id == ride.driver_id)
                )
            ).scalar_one_or_none()
            if driver_user:
                await send_push_to_user(
                    db,
                    driver_user.id,
                    title="Ride Cancelled",
                    body=ride.cancel_reason or "This ride was cancelled.",
                    data={"ride_id": str(ride.id)},
                )
    except Exception:
        # Notification failure must never block a status update, but it must
        # be visible — a silently dead push pipeline is a production incident.
        log.warning("push notification failed for ride %s", ride.id, exc_info=True)

    return ride


async def get_pending_rides(driver: Driver, db: AsyncSession) -> list[Ride]:
    """Unassigned pending rides, sorted by distance to driver (nearest first)."""
    rows = (
        (
            await db.execute(
                select(Ride)
                .where(
                    and_(Ride.status == RideStatus.pending, Ride.driver_id.is_(None))
                )
                .options(selectinload(Ride.hospital))
                .order_by(Ride.requested_at.asc())
                .limit(PENDING_RIDES_LIMIT)
            )
        )
        .scalars()
        .all()
    )

    if driver.current_lat is not None and driver.current_lng is not None:
        rows = sorted(
            rows,
            key=lambda r: _haversine_km(
                driver.current_lat, driver.current_lng, r.pickup_lat, r.pickup_lng
            ),
        )
    return list(rows)


async def accept_ride(ride_id: str, driver: Driver, db: AsyncSession) -> Ride:
    """Atomically assign a driver to a ride; raises 409 if already taken."""
    result = await db.execute(
        update(Ride)
        .where(
            and_(
                Ride.id == ride_id,
                Ride.status == RideStatus.pending,
                Ride.driver_id.is_(None),
            )
        )
        .values(
            driver_id=driver.id,
            status=RideStatus.driver_assigned,
            driver_assigned_at=datetime.now(timezone.utc),
        )
        .returning(Ride.id)
    )
    assigned_id = result.scalar_one_or_none()

    if assigned_id is None:
        # Either ride doesn't exist or was already taken
        check = (
            await db.execute(select(Ride).where(Ride.id == ride_id))
        ).scalar_one_or_none()
        if check is None:
            raise HTTPException(404, "Ride not found")
        metrics.ride_accept_conflicts_total.inc()
        raise HTTPException(409, "Ride already taken by another driver")

    # Atomically claim the driver only if they are not already on a ride. Without
    # this guard a driver already transporting another patient could accept a
    # second concurrent ride (double-booking a single vehicle onto two
    # emergencies). "busy" is the only status that means "currently on a ride" —
    # completing or cancelling a ride resets the driver to "available", and an
    # "offline" driver accepting from the pending list is coming on duty, which
    # is legitimate. If the driver is already busy, roll back the ride claim.
    driver_claim = await db.execute(
        update(Driver)
        .where(and_(Driver.id == driver.id, Driver.status != DriverStatus.busy))
        .values(status=DriverStatus.busy)
        .returning(Driver.id)
    )
    if driver_claim.scalar_one_or_none() is None:
        await db.execute(
            update(Ride)
            .where(Ride.id == ride_id)
            .values(
                driver_id=None,
                status=RideStatus.pending,
                driver_assigned_at=None,
            )
        )
        await db.commit()
        metrics.ride_accept_conflicts_total.inc()
        raise HTTPException(409, "Driver is already assigned to an active ride")

    await db.commit()

    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()

    # This was previously dead: the "Driver Assigned" label in
    # update_ride_status's push map was never reachable for this transition,
    # since accept_ride sets driver_assigned directly rather than going
    # through update_ride_status. The patient never actually learned a
    # driver had accepted.
    try:
        from app.services.notifications import send_push_to_user

        patient_user = (
            await db.execute(
                select(User)
                .join(Patient, Patient.user_id == User.id)
                .where(Patient.id == ride.patient_id)
            )
        ).scalar_one_or_none()
        if patient_user:
            await send_push_to_user(
                db,
                patient_user.id,
                title="Driver Assigned",
                body="Your driver is on the way!",
                data={"ride_id": str(ride.id)},
            )
    except Exception:
        log.warning(
            "driver-assigned push notification failed for ride %s",
            ride.id,
            exc_info=True,
        )

    return ride


async def list_rides_admin(
    db: AsyncSession,
    page: int,
    page_size: int,
    status: Optional[str] = None,
    ride_type: Optional[str] = None,
    search: Optional[str] = None,
) -> tuple[list[Ride], int]:
    conditions = []
    if status:
        try:
            conditions.append(Ride.status == RideStatus(status))
        except ValueError:
            pass
    if ride_type:
        try:
            conditions.append(Ride.ride_type == RideType(ride_type))
        except ValueError:
            pass
    if search:
        conditions.append(Ride.pickup_address.ilike(f"%{search}%"))

    base_q = select(Ride)
    if conditions:
        base_q = base_q.where(and_(*conditions))

    total = (
        await db.execute(select(func.count()).select_from(base_q.subquery()))
    ).scalar()
    rows = (
        (
            await db.execute(
                base_q.order_by(Ride.requested_at.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        .scalars()
        .all()
    )
    return list(rows), total
