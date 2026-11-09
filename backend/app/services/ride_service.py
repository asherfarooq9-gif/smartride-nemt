import logging
import uuid
from datetime import datetime, timedelta, timezone
from math import atan2, ceil, cos, radians, sin, sqrt
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func, and_, exists, or_, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core import metrics
from app.core.config import settings
from app.core.search import contains
from app.services.driver_service import (
    ACTIVE_RIDE_STATUSES,
    apply_balance_delta,
    ensure_within_debt_limit,
)
from app.services.emergency_dispatch import (
    DRIVER_FRESH_SECONDS,
    match_hospital_for_ride,
)
from app.services.chat_service import purge_ride_messages
from app.services.fare import commission_for, fare_for
from app.services.hospital_matching import haversine_km
from app.services.notifications import notify_user, tell_hospital_ride_stopped

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
    RideIdempotencyKey,
    WalletEntry,
)
from app.schemas.rides import (
    EmergencyRideRequest,
    ScheduledRideRequest,
    ScheduledSeriesRequest,
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


def _ensure_driver_at_pickup(
    ride: Ride, new_status: RideStatus, driver: Driver, now: datetime
) -> None:
    """Refuse to start a scheduled ride while the driver is far from the patient.

    A guard against a stray tap, not a security check: it trusts the position the
    driver last reported. Emergencies are never blocked, and a missing or stale
    position lets the driver through, so a GPS fault cannot strand a patient.
    """
    radius_m = settings.PICKUP_ARRIVAL_RADIUS_M
    if (
        radius_m <= 0
        or new_status != RideStatus.patient_picked_up
        or ride.ride_type != RideType.scheduled
    ):
        return
    seen = driver.last_seen_at
    if (
        driver.current_lat is None
        or driver.current_lng is None
        or seen is None
        or (now - seen).total_seconds() > DRIVER_FRESH_SECONDS
    ):
        return
    away_m = (
        _haversine_km(
            driver.current_lat, driver.current_lng, ride.pickup_lat, ride.pickup_lng
        )
        * 1000
    )
    if away_m > radius_m:
        raise HTTPException(
            409,
            f"You are about {round(away_m)} m from the pickup. "
            f"Get within {round(radius_m)} m to start the ride.",
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


SCHEDULED_KEY_SCOPE = "scheduled"
SERIES_KEY_SCOPE = "scheduled_series"
_SERIES_STEP = {"daily": timedelta(days=1), "weekly": timedelta(days=7)}


async def _ride_for_key(
    db: AsyncSession,
    patient_id,
    key: str,
    fingerprint: str,
    scope: str = SCHEDULED_KEY_SCOPE,
) -> Optional[Ride]:
    """The ride this patient's key already produced, or None if it is new.

    Raises 409 when the key was used with a different body: that is a client bug,
    not a retry, and must not silently return the other booking.
    """
    row = (
        await db.execute(
            select(RideIdempotencyKey).where(
                RideIdempotencyKey.patient_id == patient_id,
                RideIdempotencyKey.scope == scope,
                RideIdempotencyKey.key == key,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        return None
    if row.fingerprint != fingerprint:
        raise HTTPException(
            409, "Idempotency-Key was already used with a different request body"
        )
    return (await db.execute(select(Ride).where(Ride.id == row.ride_id))).scalar_one()


async def _ensure_hospital_is_open(db: AsyncSession, hospital_id) -> None:
    """404 unless the chosen destination exists and is active (none is fine)."""
    if hospital_id is None:
        return
    hospital = (
        await db.execute(
            select(Hospital).where(
                Hospital.id == hospital_id, Hospital.is_active.is_(True)
            )
        )
    ).scalar_one_or_none()
    if hospital is None:
        raise HTTPException(404, "Hospital not found")


async def _series_rides(db: AsyncSession, series_id) -> list[Ride]:
    rows = await db.execute(
        select(Ride).where(Ride.series_id == series_id).order_by(Ride.scheduled_for)
    )
    return list(rows.scalars().all())


async def _ensure_room_to_book(db: AsyncSession, patient_id, adding: int) -> None:
    """409 when a patient would hold more upcoming scheduled rides than allowed.

    A soft cap: two requests at the same instant can overshoot it by one run.
    """
    open_rides = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(
                Ride.patient_id == patient_id,
                Ride.ride_type == RideType.scheduled,
                Ride.status.in_([RideStatus.pending, RideStatus.driver_assigned]),
                Ride.scheduled_for > func.now(),
            )
        )
    ).scalar_one()
    limit = settings.MAX_UPCOMING_SCHEDULED_RIDES
    if open_rides + adding > limit:
        raise HTTPException(
            409,
            f"You can have {limit} upcoming booked rides at once. "
            "Cancel one you no longer need first.",
        )


async def create_scheduled_series(
    patient: Patient,
    body: ScheduledSeriesRequest,
    db: AsyncSession,
    *,
    key: Optional[str] = None,
    fingerprint: Optional[str] = None,
) -> tuple[list[Ride], bool]:
    """Book a run of scheduled rides at once. Returns (rides, is_new).

    All or nothing: one transaction. With a [key], a retry or a request that
    lost a race gets the first run back (is_new False) and nothing is booked
    twice. The key row points at the run's first ride.
    """
    patient_id = patient.id
    if key and fingerprint:
        first = await _ride_for_key(db, patient_id, key, fingerprint, SERIES_KEY_SCOPE)
        if first is not None:
            return await _series_rides(db, first.series_id), False
    ensure_in_service_area(body.pickup_lat, body.pickup_lng)
    await _ensure_hospital_is_open(db, body.hospital_id)
    await _ensure_room_to_book(db, patient_id, body.occurrences)
    series_id = uuid.uuid4()
    step = _SERIES_STEP[body.repeat]
    rides = [
        Ride(
            id=uuid.uuid4(),
            series_id=series_id,
            patient_id=patient_id,
            hospital_id=body.hospital_id,
            ride_type=RideType.scheduled,
            status=RideStatus.pending,
            pickup_lat=body.pickup_lat,
            pickup_lng=body.pickup_lng,
            pickup_address=body.pickup_address,
            scheduled_for=body.scheduled_for + step * i,
            queued_at=func.now(),
        )
        for i in range(body.occurrences)
    ]
    db.add_all(rides)
    if key and fingerprint:
        await db.flush()
        saved = await db.execute(
            pg_insert(RideIdempotencyKey)
            .values(
                patient_id=patient_id,
                scope=SERIES_KEY_SCOPE,
                key=key,
                fingerprint=fingerprint,
                ride_id=rides[0].id,
            )
            .on_conflict_do_nothing()
            .returning(RideIdempotencyKey.key)
        )
        if saved.first() is None:
            await db.rollback()
            first = await _ride_for_key(
                db, patient_id, key, fingerprint, SERIES_KEY_SCOPE
            )
            return await _series_rides(db, first.series_id), False
    await db.commit()
    return await _series_rides(db, series_id), True


async def create_scheduled_ride(
    patient: Patient,
    body: ScheduledRideRequest,
    db: AsyncSession,
    *,
    key: Optional[str] = None,
    fingerprint: Optional[str] = None,
) -> tuple[Ride, bool]:
    """Book a scheduled ride. Returns (ride, is_new).

    With a [key], the ride and the key are saved in one transaction and the
    database decides: a retry, or a request that lost a race, gets the first
    request's ride with is_new False and nothing is created twice.
    """
    patient_id = patient.id  # read before a rollback expires the instance
    if key and fingerprint:
        replayed = await _ride_for_key(db, patient_id, key, fingerprint)
        if replayed is not None:
            return replayed, False
    ensure_in_service_area(body.pickup_lat, body.pickup_lng)
    await _ensure_hospital_is_open(db, body.hospital_id)
    await _ensure_room_to_book(db, patient_id, 1)
    ride = Ride(
        id=uuid.uuid4(),
        patient_id=patient_id,
        hospital_id=body.hospital_id,
        ride_type=RideType.scheduled,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
        scheduled_for=body.scheduled_for,
        queued_at=func.now(),
    )
    db.add(ride)
    if key and fingerprint:
        await db.flush()
        saved = await db.execute(
            pg_insert(RideIdempotencyKey)
            .values(
                patient_id=patient_id,
                scope=SCHEDULED_KEY_SCOPE,
                key=key,
                fingerprint=fingerprint,
                ride_id=ride.id,
            )
            .on_conflict_do_nothing()
            .returning(RideIdempotencyKey.key)
        )
        if saved.first() is None:
            # A concurrent request with this key committed first: drop our ride
            # and hand back theirs.
            await db.rollback()
            winner = await _ride_for_key(db, patient_id, key, fingerprint)
            return winner, False
    await db.commit()
    await db.refresh(ride)
    return ride, True


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
    """Free a busy driver unless they have since taken another live ride.

    Only a busy driver is touched: one who went offline mid-ride chose to stop
    taking rides and must not become dispatchable again by finishing this one.
    """
    on_another_ride = exists().where(
        Ride.driver_id == driver_id,
        Ride.id != ride_id,
        Ride.status.in_(ACTIVE_RIDE_STATUSES),
    )
    await db.execute(
        update(Driver)
        .where(
            Driver.id == driver_id, Driver.status == DriverStatus.busy, ~on_another_ride
        )
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
            # A driver who gives the ride up also gives up any claim on it, or
            # dispatch would keep handing it straight back.
            ride.claimed_driver_id = None
            ride.claimed_at = None
            driver.status = DriverStatus.offline
        elif ride.status in (
            RideStatus.patient_picked_up,
            RideStatus.arrived_at_hospital,
        ):
            # The patient is on board: cancelling would strand them with no
            # requeue. Dispatch (an admin) decides what happens to the ride.
            raise HTTPException(
                409, "The patient is on board. Call dispatch to cancel this ride."
            )
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
    _ensure_driver_at_pickup(ride, new_status, driver, now)
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


async def _tell_ride_stopped(
    db: AsyncSession, ride: Ride, role: str, driver_id, hospital_id
) -> None:
    """Tell the hospital (and the driver, unless they did it) the ride is off.

    Runs after the commit and never raises: the state change already happened,
    a lost notification must not turn it into an error. Failures are logged and
    counted by the senders.
    """
    try:
        if hospital_id is not None:
            await tell_hospital_ride_stopped(
                db, ride_id=ride.id, hospital_id=hospital_id
            )
        if driver_id is not None and role != "driver":
            driver_user_id = (
                await db.execute(select(Driver.user_id).where(Driver.id == driver_id))
            ).scalar_one_or_none()
            if driver_user_id is not None:
                await notify_user(
                    db,
                    user_id=driver_user_id,
                    title="Ride cancelled",
                    body=ride.cancel_reason or "This ride was cancelled.",
                    data={"ride_id": str(ride.id)},
                )
    except Exception as exc:
        log.error(
            "could not tell the hospital or driver the ride stopped ride_id=%s (%s)",
            ride.id,
            type(exc).__name__,
        )


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
    # A requeue or cancel clears these, so remember who was told about the ride.
    alerted_driver_id, alerted_hospital_id = ride.driver_id, ride.hospital_id

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

    # The chat ends with the trip (or when the driver gives the ride back): no
    # message outlives it, and the next driver never sees the last one's.
    if ride.status in TERMINAL_STATUSES or ride.status == RideStatus.pending:
        await purge_ride_messages(db, ride.id)

    await db.commit()
    await db.refresh(ride)

    if ride.status in (RideStatus.cancelled, RideStatus.pending):
        await _tell_ride_stopped(db, ride, role, alerted_driver_id, alerted_hospital_id)

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


def _dispatch_lead_cutoff() -> datetime:
    """A scheduled ride is open to drivers once its time is before this moment.

    The same lead the dispatch loop uses to start placing a scheduled ride.
    """
    return datetime.now(timezone.utc) + timedelta(
        minutes=settings.SCHEDULED_DISPATCH_LEAD_MINUTES
    )


async def get_pending_rides(driver: Driver, db: AsyncSession) -> list[Ride]:
    """Unassigned pending rides within DRIVER_SEARCH_RADIUS_KM of the driver, nearest first.

    A ride booked for later stays hidden until it is inside the dispatch lead
    window, so a driver cannot take a ride days before it is due.

    A driver with no known location gets an empty list: showing every pending
    ride in the country would hand out patients' pickup points to drivers who
    cannot possibly reach them.
    """
    if driver.current_lat is None or driver.current_lng is None:
        return []
    lat, lng = driver.current_lat, driver.current_lng
    dlat = settings.DRIVER_SEARCH_RADIUS_KM / 111.0
    dlng = dlat / max(cos(radians(lat)), 0.01)
    cutoff = _dispatch_lead_cutoff()
    rows = (
        (
            await db.execute(
                select(Ride)
                .where(
                    and_(
                        Ride.status == RideStatus.pending,
                        Ride.driver_id.is_(None),
                        # Another driver's claim is theirs; their own stays visible.
                        or_(
                            Ride.claimed_driver_id.is_(None),
                            Ride.claimed_driver_id == driver.id,
                        ),
                        or_(Ride.scheduled_for.is_(None), Ride.scheduled_for <= cutoff),
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


def _within_radius(rows: list[Ride], lat: float, lng: float) -> list[Ride]:
    """The rides inside DRIVER_SEARCH_RADIUS_KM, ordered by pickup time."""
    nearby = [
        r
        for r in rows
        if _haversine_km(lat, lng, r.pickup_lat, r.pickup_lng)
        <= settings.DRIVER_SEARCH_RADIUS_KM
    ]
    return sorted(nearby, key=lambda r: r.scheduled_for)


async def list_open_scheduled(driver: Driver, db: AsyncSession) -> list[Ride]:
    """Booked rides a driver can reserve now: nearby, still unclaimed, and not yet
    inside their pickup window (those are accepted from the live list instead)."""
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
                    Ride.ride_type == RideType.scheduled,
                    Ride.status == RideStatus.pending,
                    Ride.driver_id.is_(None),
                    Ride.claimed_driver_id.is_(None),
                    Ride.scheduled_for > _dispatch_lead_cutoff(),
                    Ride.pickup_lat.between(lat - dlat, lat + dlat),
                    Ride.pickup_lng.between(lng - dlng, lng + dlng),
                )
                .options(selectinload(Ride.hospital))
                .order_by(Ride.scheduled_for.asc())
                .limit(PENDING_RIDES_LIMIT)
            )
        )
        .scalars()
        .all()
    )
    return _within_radius(list(rows), lat, lng)


async def list_my_claims(driver: Driver, db: AsyncSession) -> list[Ride]:
    """The rides this driver reserved and still has to do, soonest first."""
    rows = (
        (
            await db.execute(
                select(Ride)
                .where(
                    Ride.claimed_driver_id == driver.id,
                    Ride.status.in_(
                        (
                            RideStatus.pending,
                            RideStatus.driver_assigned,
                            RideStatus.driver_en_route,
                        )
                    ),
                )
                .options(selectinload(Ride.hospital))
                .order_by(Ride.scheduled_for.asc())
            )
        )
        .scalars()
        .all()
    )
    return list(rows)


async def _tell_patient(db: AsyncSession, ride_id, title: str, body: str) -> None:
    patient_id = (
        await db.execute(select(Ride.patient_id).where(Ride.id == ride_id))
    ).scalar_one_or_none()
    if patient_id is not None:
        await notify_user(
            db,
            patient_id=patient_id,
            title=title,
            body=body,
            data={"ride_id": str(ride_id)},
        )


async def _ensure_not_own_ride(ride_id: str, driver: Driver, db: AsyncSession) -> None:
    requester_user_id = (
        await db.execute(
            select(Patient.user_id)
            .join(Ride, Ride.patient_id == Patient.id)
            .where(Ride.id == ride_id)
        )
    ).scalar_one_or_none()
    if requester_user_id == driver.user_id:
        raise HTTPException(403, "You cannot accept your own ride")


async def claim_scheduled_ride(ride_id: str, driver: Driver, db: AsyncSession) -> Ride:
    """Reserve a booked ride. Exactly one driver wins a race for it.

    The ride stays pending and disappears from other drivers; dispatch hands it to
    this driver when its pickup window opens. 409 if it is taken, already in its
    window (accept it from the live list), or the driver is at the claim limit.
    """
    ensure_within_debt_limit(driver)
    await _ensure_not_own_ride(ride_id, driver, db)
    await _ensure_driver_is_near(ride_id, driver, db)  # also 404s a missing ride
    driver_id = driver.id
    # One driver's claims run one at a time, so two at once cannot pass the limit.
    await db.execute(select(Driver.id).where(Driver.id == driver_id).with_for_update())
    held = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(
                Ride.claimed_driver_id == driver_id, Ride.status == RideStatus.pending
            )
        )
    ).scalar_one()
    if held >= settings.MAX_SCHEDULED_CLAIMS:
        await db.rollback()
        raise HTTPException(
            409,
            f"You can hold {settings.MAX_SCHEDULED_CLAIMS} booked rides at once. "
            "Release one first.",
        )
    claimed = await db.execute(
        update(Ride)
        .where(
            Ride.id == ride_id,
            Ride.ride_type == RideType.scheduled,
            Ride.status == RideStatus.pending,
            Ride.driver_id.is_(None),
            Ride.claimed_driver_id.is_(None),
            Ride.scheduled_for > _dispatch_lead_cutoff(),
        )
        .values(claimed_driver_id=driver_id, claimed_at=datetime.now(timezone.utc))
        .returning(Ride.id)
    )
    if claimed.scalar_one_or_none() is None:
        await db.rollback()
        raise HTTPException(
            409, "This ride is no longer open to claim. Another driver may have it."
        )
    await db.commit()
    await _tell_patient(
        db,
        ride_id,
        "A driver is lined up",
        "A driver has reserved your trip. We will confirm them closer to pickup.",
    )
    return await get_ride_by_id(ride_id, db)


async def release_scheduled_claim(
    ride_id: str, driver: Driver, db: AsyncSession
) -> Ride:
    """Give a claimed ride back, if there is still time for someone else to take it."""
    ride = (
        await db.execute(select(Ride).where(Ride.id == ride_id).with_for_update())
    ).scalar_one_or_none()
    if ride is None:
        raise HTTPException(404, "Ride not found")
    if ride.claimed_driver_id != driver.id:
        await db.rollback()
        raise HTTPException(403, "This is not your claim")
    if ride.status != RideStatus.pending:
        await db.rollback()
        raise HTTPException(
            409, "This ride is already yours to drive. Cancel it from the ride screen."
        )
    cutoff = datetime.now(timezone.utc) + timedelta(
        minutes=settings.SCHEDULED_RELEASE_CUTOFF_MINUTES
    )
    if ride.scheduled_for is None or ride.scheduled_for <= cutoff:
        await db.rollback()
        raise HTTPException(
            409,
            "Pickup is too close to give this ride back: the patient is counting on you.",
        )
    ride.claimed_driver_id = None
    ride.claimed_at = None
    await db.commit()
    await _tell_patient(
        db,
        ride_id,
        "Finding another driver",
        "Your reserved driver can no longer make it. We are finding you another one.",
    )
    return await get_ride_by_id(ride_id, db)


async def _ensure_driver_is_near(
    ride_id: str, driver: Driver, db: AsyncSession
) -> None:
    """Only a driver the ride could have been offered to may accept it.

    The pending list shows rides within DRIVER_SEARCH_RADIUS_KM of the driver's
    last position; accepting by id must follow the same rule, or anyone holding a
    ride id (it is in the family SMS) could take a ride from across the country.
    """
    pickup = (
        await db.execute(
            select(Ride.pickup_lat, Ride.pickup_lng).where(Ride.id == ride_id)
        )
    ).first()
    if pickup is None:
        raise HTTPException(404, "Ride not found")
    if driver.current_lat is None or driver.current_lng is None:
        raise HTTPException(403, "Your location is unknown. Turn on location first.")
    km = _haversine_km(
        driver.current_lat, driver.current_lng, pickup.pickup_lat, pickup.pickup_lng
    )
    if km > settings.DRIVER_SEARCH_RADIUS_KM:
        raise HTTPException(403, "This ride is too far from you")


async def _ensure_ride_is_open(ride_id: str, db: AsyncSession) -> None:
    """Refuse a scheduled ride that is not yet inside the dispatch lead window.

    Without this a driver could take a ride booked for next week, be stuck as
    driver_assigned for days, and be dropped when the acknowledgement times out.
    A missing ride is left for the later 404.
    """
    scheduled_for = (
        await db.execute(select(Ride.scheduled_for).where(Ride.id == ride_id))
    ).scalar_one_or_none()
    if scheduled_for is not None and scheduled_for > _dispatch_lead_cutoff():
        raise HTTPException(409, "This ride is booked for later and is not open yet")


async def _hospital_placement(ride_id: str, db: AsyncSession) -> dict:
    """Hospital and estimated fare for a ride that dispatch has not placed yet.

    Dispatch sets these when it assigns a driver itself. A driver who accepts a
    pending ride by hand skips that path, so without this the ride would have no
    destination, no hospital to pre-alert, and a 0 km base fare on completion.
    Returns {} (leave the ride as it is) when it already has a hospital, has no
    symptom text to triage, or no hospital is in range.
    """
    ride = (
        await db.execute(
            select(
                Ride.hospital_id, Ride.pickup_lat, Ride.pickup_lng, Ride.symptom_text
            ).where(Ride.id == ride_id)
        )
    ).first()
    if ride is None or ride.hospital_id is not None or not ride.symptom_text:
        return {}
    match = await match_hospital_for_ride(
        db, ride_id, ride.pickup_lat, ride.pickup_lng, ride.symptom_text
    )
    if match is None:
        return {}
    return {
        "hospital_id": match.hospital_id,
        "estimated_fare_pkr": fare_for(match.distance_km),
    }


async def accept_ride(
    ride_id: str, driver: Driver, db: AsyncSession
) -> tuple[Ride, bool]:
    """Atomically assign a driver to a ride; raises 409 if already taken.

    Returns the ride and whether accepting is what chose its hospital. Dispatch
    pre-alerts the hospital for rides it places itself, so only a True here means
    nobody has told the hospital yet.
    """
    ensure_within_debt_limit(driver)
    requester_user_id = (
        await db.execute(
            select(Patient.user_id)
            .join(Ride, Ride.patient_id == Patient.id)
            .where(Ride.id == ride_id)
        )
    ).scalar_one_or_none()
    if requester_user_id == driver.user_id:
        raise HTTPException(403, "You cannot accept your own ride")

    await _ensure_driver_is_near(ride_id, driver, db)
    await _ensure_ride_is_open(ride_id, db)
    placement = await _hospital_placement(ride_id, db)

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
                # Not a ride another driver has claimed.
                or_(
                    Ride.claimed_driver_id.is_(None),
                    Ride.claimed_driver_id == driver.id,
                ),
            )
        )
        .values(
            driver_id=driver.id,
            status=RideStatus.driver_assigned,
            driver_assigned_at=datetime.now(timezone.utc),
            **placement,
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
    return ride, "hospital_id" in placement


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
