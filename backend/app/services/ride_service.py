import logging
from datetime import datetime, timezone
from math import atan2, ceil, cos, radians, sin, sqrt
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func, and_, exists, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core import metrics
from app.core.config import settings
from app.core.search import contains
from app.services.driver_service import ACTIVE_RIDE_STATUSES, apply_balance_delta
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


# Status -> the Ride column holding when the leg leading into it started.
_LEG_START_FIELD = {
    RideStatus.arrived_at_hospital: "pickup_at",
    RideStatus.completed: "arrived_at",
}


def ensure_in_service_area(lat: float, lng: float) -> None:
    """Reject pickups outside SERVICE_AREA_BBOX (no-op when it is unset)."""
    bbox = settings.service_area_bbox()
    if bbox is None:
        return
    min_lat, min_lng, max_lat, max_lng = bbox
    if not (min_lat <= lat <= max_lat and min_lng <= lng <= max_lng):
        raise HTTPException(422, "Pickup location is outside the service area")


def _ensure_leg_took_long_enough(
    ride: Ride, new_status: RideStatus, now: datetime
) -> None:
    """Refuse a status that follows its predecessor faster than any real trip."""
    minimum = settings.RIDE_MIN_TRANSITION_SECONDS
    field = _LEG_START_FIELD.get(new_status)
    started = getattr(ride, field) if field else None
    if minimum <= 0 or started is None:
        return
    elapsed = (now - started).total_seconds()
    if elapsed < minimum:
        raise HTTPException(
            400,
            f"Too soon to mark {new_status.value}; try again in "
            f"{ceil(minimum - elapsed)}s",
        )


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
    # Commission is debited after the ride completes, so the balance may go
    # negative. That is intended; do not add a >= 0 check on the debit.
    await apply_balance_delta(db, driver_id, amount)
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
    ensure_in_service_area(body.pickup_lat, body.pickup_lng)
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.emergency,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
        # Saved with the ride so a restart before triage never loses the complaint.
        symptom_text=body.symptom_text,
        queued_at=func.now(),
    )
    db.add(ride)
    await db.commit()
    await db.refresh(ride)
    return ride


async def create_scheduled_ride(
    patient: Patient, body: ScheduledRideRequest, db: AsyncSession
) -> Ride:
    ensure_in_service_area(body.pickup_lat, body.pickup_lng)
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.scheduled,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
        scheduled_for=body.scheduled_for,
        queued_at=func.now(),
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


async def _lock_ride(db: AsyncSession, ride: Ride) -> None:
    """Re-read the ride FOR UPDATE and refresh the caller's instance in place.

    Transitions race (driver 'completed' vs admin cancel, patient cancel vs driver
    requeue). Taking the row lock before any check means the loser of the race sees
    the winner's committed state and fails validation instead of overwriting it.
    """
    await db.execute(
        select(Ride)
        .where(Ride.id == ride.id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )


async def _release_driver(db: AsyncSession, driver_id, ride_id) -> None:
    """Mark the driver available unless they have since taken another live ride."""
    on_another_ride = exists().where(
        Ride.driver_id == driver_id,
        Ride.id != ride_id,
        Ride.status.in_(ACTIVE_RIDE_STATUSES),
    )
    await db.execute(
        update(Driver)
        .where(Driver.id == driver_id, ~on_another_ride)
        .values(status=DriverStatus.available)
        .execution_options(synchronize_session="fetch")
    )


async def _cancel_ride(db: AsyncSession, ride: Ride, reason: str) -> None:
    ride.status = RideStatus.cancelled
    ride.cancelled_at = datetime.now(timezone.utc)
    ride.cancel_reason = reason
    if ride.driver_id is not None:
        await _release_driver(db, ride.driver_id, ride.id)


async def _apply_driver_transition(
    db: AsyncSession, ride: Ride, new_status: RideStatus, driver: Driver
) -> None:
    if ride.driver_id != driver.id:
        raise HTTPException(403, "Not your ride")
    if new_status == RideStatus.cancelled:
        if ride.status in (RideStatus.driver_assigned, RideStatus.driver_en_route):
            # Patient not on board yet: return the ride to the queue (the
            # dispatch loop re-places it) and take this driver offline so
            # they are not handed the same ride straight back.
            ride.status = RideStatus.pending
            ride.queued_at = func.now()
            ride.driver_id = None
            ride.driver_assigned_at = None
            ride.hospital_id = None
            driver.status = DriverStatus.offline
        else:
            ride.status = RideStatus.cancelled
            ride.cancelled_at = datetime.now(timezone.utc)
            await _release_driver(db, driver.id, ride.id)
        return
    if new_status != DRIVER_TRANSITIONS.get(ride.status):
        raise HTTPException(
            400, f"Cannot transition from {ride.status} to {new_status}"
        )
    now = datetime.now(timezone.utc)
    _ensure_leg_took_long_enough(ride, new_status, now)
    ride.status = new_status
    if new_status == RideStatus.patient_picked_up:
        ride.pickup_at = now
    elif new_status == RideStatus.arrived_at_hospital:
        ride.arrived_at = now
    elif new_status == RideStatus.completed:
        ride.completed_at = now
        ride.final_fare_pkr = await ride_fare(db, ride)
        await charge_commission(db, ride, driver.id)
        await _release_driver(db, driver.id, ride.id)


async def update_ride_status(
    ride: Ride,
    body: RideStatusUpdate,
    role: str,
    db: AsyncSession,
    patient: Optional[Patient] = None,
    driver: Optional[Driver] = None,
) -> Ride:
    new_status = body.status
    await _lock_ride(db, ride)

    if new_status == RideStatus.cancelled and ride.status in TERMINAL_STATUSES:
        raise HTTPException(400, f"Cannot cancel a {ride.status.value} ride")

    if role == "driver":
        await _apply_driver_transition(db, ride, new_status, driver)
    elif role == "admin":
        if new_status != RideStatus.cancelled:
            raise HTTPException(400, "Admin can only cancel rides")
        await _cancel_ride(db, ride, "Cancelled by admin")
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
        await _cancel_ride(db, ride, body.cancel_reason or "Cancelled by patient")
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
        delivered = await notify_user(
            db,
            patient_id=ride.patient_id,
            title=title,
            body=body_text,
            data={"ride_id": str(ride.id)},
        )
        if not delivered:
            # The status change is already committed; only the push was lost.
            log.warning(
                "status push not sent ride_id=%s status=%s", ride.id, ride.status.value
            )

    return ride


async def rate_completed_ride(
    db: AsyncSession, ride_id, patient_id, rating, comment: Optional[str]
) -> Ride:
    """Store a patient's rating exactly once.

    The checks live in the UPDATE's WHERE clause, so two simultaneous ratings
    cannot both succeed: the loser matches no row and gets a 409.
    """
    rated = await db.execute(
        update(Ride)
        .where(
            Ride.id == ride_id,
            Ride.patient_id == patient_id,
            Ride.status == RideStatus.completed,
            Ride.patient_rating.is_(None),
        )
        .values(patient_rating=rating, rating_comment=comment)
        .returning(Ride.id)
    )
    if rated.first() is None:
        await db.rollback()
        ride = await get_ride_by_id(ride_id, db)  # 404 if it does not exist
        if ride.patient_id != patient_id:
            raise HTTPException(403, "Forbidden")
        if ride.status != RideStatus.completed:
            raise HTTPException(400, "Can only rate completed rides")
        raise HTTPException(409, "Ride already rated")
    await db.commit()
    return await get_ride_by_id(ride_id, db)


async def get_pending_rides(driver: Driver, db: AsyncSession) -> list[Ride]:
    """Unassigned pending rides within DRIVER_SEARCH_RADIUS_KM of the driver, nearest first.

    A driver with no known location gets an empty list: showing every pending
    ride in the country would hand out patients' pickup points to drivers who
    cannot possibly reach them.
    """
    if driver.current_lat is None or driver.current_lng is None:
        return []
    lat, lng = driver.current_lat, driver.current_lng
    dlat = settings.DRIVER_SEARCH_RADIUS_KM / 111.0
    dlng = dlat / max(cos(radians(lat)), 0.01)
    rows = (
        (
            await db.execute(
                select(Ride)
                .where(
                    and_(
                        Ride.status == RideStatus.pending,
                        Ride.driver_id.is_(None),
                        Ride.pickup_lat.between(lat - dlat, lat + dlat),
                        Ride.pickup_lng.between(lng - dlng, lng + dlng),
                    )
                )
                .options(selectinload(Ride.hospital))
                .order_by(Ride.requested_at.asc())
                .limit(PENDING_RIDES_LIMIT)
            )
        )
        .scalars()
        .all()
    )
    with_km = [(r, _haversine_km(lat, lng, r.pickup_lat, r.pickup_lng)) for r in rows]
    nearby = [(r, km) for r, km in with_km if km <= settings.DRIVER_SEARCH_RADIUS_KM]
    nearby.sort(key=lambda pair: pair[1])
    return [r for r, _ in nearby]


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
    count_q = select(func.count()).select_from(Ride)
    if conditions:
        base_q = base_q.where(and_(*conditions))
        count_q = count_q.where(and_(*conditions))

    total = (await db.execute(count_q)).scalar()
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
