import logging
from datetime import datetime, timezone
from math import radians, sin, cos, sqrt, atan2
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func, and_, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core import metrics
from app.core.search import contains
from app.services.fare import commission_for, fare_for
from app.services.hospital_matching import haversine_km
from app.services.notifications import notify_user

from app.models.models import (
    Ride,
    Patient,
    Driver,
    User,
    TriageEvent,
    RideType,
    RideStatus,
    DriverStatus,
    Hospital,
    WalletEntry,
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


TERMINAL_STATUSES = (RideStatus.completed, RideStatus.cancelled)

DRIVER_TRANSITIONS = {
    RideStatus.driver_assigned: RideStatus.driver_en_route,
    RideStatus.driver_en_route: RideStatus.patient_picked_up,
    RideStatus.patient_picked_up: RideStatus.arrived_at_hospital,
    RideStatus.arrived_at_hospital: RideStatus.completed,
}


async def ride_fare(db: AsyncSession, ride: Ride):
    """Fare for pickup -> hospital; just the base fare while no hospital is set."""
    km = 0.0
    if ride.hospital_id is not None:
        hospital = (
            await db.execute(select(Hospital).where(Hospital.id == ride.hospital_id))
        ).scalar_one_or_none()
        if hospital is not None:
            km = haversine_km(
                ride.pickup_lat, ride.pickup_lng, hospital.lat, hospital.lng
            )
    return fare_for(km)


async def charge_commission(db: AsyncSession, ride: Ride, driver_id) -> bool:
    """Debit the driver's commission for a completed ride, exactly once.

    The ledger row and the balance change share the caller's transaction; the
    (ride_id, kind) unique key makes a repeat a no-op instead of a double charge.
    """
    amount = -commission_for(ride.final_fare_pkr)
    inserted = await db.execute(
        pg_insert(WalletEntry)
        .values(driver_id=driver_id, ride_id=ride.id, kind="commission", amount=amount)
        .on_conflict_do_nothing(constraint="uq_wallet_ride_kind")
        .returning(WalletEntry.id)
    )
    if inserted.first() is None:
        return False
    await db.execute(
        update(Driver)
        .where(Driver.id == driver_id)
        .values(wallet_balance_pkr=Driver.wallet_balance_pkr + amount)
    )
    return True


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

    if new_status == RideStatus.cancelled and ride.status in TERMINAL_STATUSES:
        raise HTTPException(400, f"Cannot cancel a {ride.status.value} ride")

    if role == "driver":
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Not your ride")
        allowed_next = DRIVER_TRANSITIONS.get(ride.status)
        if new_status == RideStatus.cancelled:
            if ride.status in (RideStatus.driver_assigned, RideStatus.driver_en_route):
                # Patient not on board yet: return the ride to the queue (the
                # dispatch loop re-places it) and take this driver offline so
                # they are not handed the same ride straight back.
                ride.status = RideStatus.pending
                ride.driver_id = None
                ride.driver_assigned_at = None
                ride.hospital_id = None
                driver.status = DriverStatus.offline
            else:
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
                ride.final_fare_pkr = await ride_fare(db, ride)
                await charge_commission(db, ride, driver.id)

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
        # Until the patient is on board they may change their mind.
        if ride.status not in (
            RideStatus.pending,
            RideStatus.driver_assigned,
            RideStatus.driver_en_route,
        ):
            raise HTTPException(400, "Cannot cancel ride in current state")
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
        ride.cancel_reason = body.cancel_reason or "Cancelled by patient"
        if ride.driver_id is not None:
            assigned_driver = (
                await db.execute(select(Driver).where(Driver.id == ride.driver_id))
            ).scalar_one_or_none()
            if assigned_driver:
                assigned_driver.status = DriverStatus.available

    else:
        raise HTTPException(403, "Forbidden")

    await db.commit()
    await db.refresh(ride)

    # Push notification to patient on status change
    labels = {
        RideStatus.driver_assigned: ("Driver Assigned", "Your driver is on the way!"),
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
        RideStatus.completed: ("Ride Complete", "Your ride has been completed."),
        RideStatus.cancelled: (
            "Ride Cancelled",
            ride.cancel_reason or "Your ride was cancelled.",
        ),
        RideStatus.pending: (
            "Finding another driver",
            "Your driver cancelled. We are finding you another one.",
        ),
    }
    if ride.status in labels:
        title, body_text = labels[ride.status]
        await notify_user(
            db,
            patient_id=ride.patient_id,
            title=title,
            body=body_text,
            data={"ride_id": str(ride.id)},
        )

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
    requester_user_id = (
        await db.execute(
            select(Patient.user_id)
            .join(Ride, Ride.patient_id == Patient.id)
            .where(Ride.id == ride_id)
        )
    ).scalar_one_or_none()
    if requester_user_id == driver.user_id:
        raise HTTPException(403, "You cannot accept your own ride")

    # Claim the driver first: only an available driver may take a ride, and two
    # simultaneous accepts by one driver cannot both succeed.
    claimed = await db.execute(
        update(Driver)
        .where(Driver.id == driver.id, Driver.status == DriverStatus.available)
        .values(status=DriverStatus.busy)
    )
    if claimed.rowcount != 1:
        raise HTTPException(409, "Go online and finish your current ride first")

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
        await db.rollback()  # releases the driver claimed above
        # Either ride doesn't exist or was already taken
        check = (
            await db.execute(select(Ride).where(Ride.id == ride_id))
        ).scalar_one_or_none()
        if check is None:
            raise HTTPException(404, "Ride not found")
        metrics.ride_accept_conflicts_total.inc()
        raise HTTPException(409, "Ride already taken by another driver")

    await db.commit()

    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
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
        conditions.append(Ride.pickup_address.ilike(contains(search), escape="\\"))

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
