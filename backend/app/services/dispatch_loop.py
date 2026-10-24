"""Keeps trying to place rides that the first dispatch could not.

The first dispatch runs as a request background task, so a restart, a missing
driver or a missing hospital used to strand the ride. This loop re-dispatches
stale pending rides (most severe first), promotes scheduled rides that fall due,
takes rides back from drivers who never acknowledged them, and closes rides
nobody accepted in time. Safe to run on several instances at once: assignment
is a guarded UPDATE, so only one dispatch can win a given ride or driver.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select, update

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.models import (
    Driver,
    DriverStatus,
    Ride,
    RideStatus,
    RideType,
    TriageEvent,
)
from app.services.emergency_dispatch import dispatch_emergency
from app.services.notifications import notify_user

log = logging.getLogger("smartride.dispatch_loop")
BATCH = 20
# A driver who was handed a ride and has not tapped "on my way" by now is
# assumed gone (phone locked, app killed); the ride goes back to the queue.
DRIVER_ACK_TIMEOUT_SECONDS = 90

_PLACEHOLDER_SYMPTOMS = {
    RideType.emergency: "emergency, symptoms not recorded",
    RideType.scheduled: "scheduled transport",
}


async def _symptoms(db, ride: Ride) -> str:
    """The patient's own words: saved on the ride, else from an earlier triage."""
    if ride.symptom_text:
        return ride.symptom_text
    text = (
        await db.execute(
            select(TriageEvent.symptom_text)
            .where(TriageEvent.ride_id == ride.id)
            .order_by(TriageEvent.created_at)
            .limit(1)
        )
    ).scalar_one_or_none()
    return text or _PLACEHOLDER_SYMPTOMS[ride.ride_type]


async def _expire(db, now: datetime) -> None:
    """Close rides nobody took, and tell the patient so they can call 1122."""
    cutoff = now - timedelta(seconds=settings.DISPATCH_MAX_AGE_SECONDS)
    due = Ride.scheduled_for + timedelta(seconds=settings.DISPATCH_MAX_AGE_SECONDS)
    expired = (
        await db.execute(
            update(Ride)
            .where(
                Ride.status == RideStatus.pending,
                or_(
                    # queued_at, not requested_at: a ride a driver gave back must
                    # get a fresh window instead of being closed on the spot.
                    and_(
                        Ride.ride_type == RideType.emergency, Ride.queued_at < cutoff
                    ),
                    and_(Ride.ride_type == RideType.scheduled, due < now),
                ),
            )
            .values(
                status=RideStatus.cancelled,
                cancelled_at=now,
                cancel_reason="No driver available",
            )
            .returning(Ride.id, Ride.patient_id)
        )
    ).all()
    await db.commit()
    for ride_id, patient_id in expired:
        log.warning("ride expired with no driver ride_id=%s", ride_id)
        told = await notify_user(
            db,
            patient_id=patient_id,
            title="No driver available",
            body="We could not find a driver. Please call 1122.",
            data={"ride_id": str(ride_id)},
        )
        if not told:
            log.error(
                "patient NOT told to call 1122 after expiry ride_id=%s", ride_id
            )


async def _requeue_unacknowledged(db, now: datetime) -> None:
    """Give rides back to the queue when the assigned driver never set off."""
    cutoff = now - timedelta(seconds=DRIVER_ACK_TIMEOUT_SECONDS)
    stuck = (
        await db.execute(
            select(Ride.id, Ride.driver_id, Ride.patient_id)
            .where(
                Ride.status == RideStatus.driver_assigned,
                Ride.driver_assigned_at < cutoff,
            )
            .order_by(Ride.driver_assigned_at)
            .limit(BATCH)
            .with_for_update(skip_locked=True)
        )
    ).all()
    requeued = []
    for ride_id, driver_id, patient_id in stuck:
        # Guarded: the driver may have just moved the ride on or cancelled.
        result = await db.execute(
            update(Ride)
            .where(
                Ride.id == ride_id,
                Ride.status == RideStatus.driver_assigned,
                Ride.driver_id == driver_id,
            )
            .values(
                status=RideStatus.pending,
                queued_at=now,
                driver_id=None,
                driver_assigned_at=None,
                hospital_id=None,
            )
        )
        if result.rowcount == 1:
            await db.execute(
                update(Driver)
                .where(Driver.id == driver_id)
                .values(status=DriverStatus.offline)
            )
            requeued.append((ride_id, patient_id))
    await db.commit()
    for ride_id, patient_id in requeued:
        log.warning("driver never acknowledged, ride requeued ride_id=%s", ride_id)
        told = await notify_user(
            db,
            patient_id=patient_id,
            title="Finding another driver",
            body="Your driver did not respond. We are finding you another one.",
            data={"ride_id": str(ride_id)},
        )
        if not told:
            log.warning("patient NOT told about the requeue ride_id=%s", ride_id)


async def _pending_ride_ids(db, now: datetime) -> list:
    """Ids of rides to retry: most severe first, then longest waiting.

    Rides with no triage yet sort as the most severe (we know nothing, so we
    assume the worst). SKIP LOCKED keeps two instances from picking the same
    ids in the same instant; the lock lasts only as long as this transaction
    (the real double-dispatch guard is the guarded UPDATEs in dispatch_emergency).
    """
    stale = now - timedelta(seconds=settings.DISPATCH_RETRY_AFTER_SECONDS)
    lead = now + timedelta(minutes=settings.SCHEDULED_DISPATCH_LEAD_MINUTES)
    result = await db.execute(
        select(Ride.id)
        .outerjoin(TriageEvent, TriageEvent.ride_id == Ride.id)
        .where(
            Ride.status == RideStatus.pending,
            or_(
                # A requeued ride keeps its old requested_at, so it retries at once.
                and_(Ride.ride_type == RideType.emergency, Ride.requested_at < stale),
                and_(Ride.ride_type == RideType.scheduled, Ride.scheduled_for <= lead),
            ),
        )
        .order_by(TriageEvent.severity_level.desc().nulls_first(), Ride.queued_at)
        .limit(BATCH)
        .with_for_update(skip_locked=True, of=Ride)
    )
    return list(result.scalars().all())


async def _dispatch_one(ride_id) -> None:
    """Dispatch one ride in its own session so one failure cannot poison the rest."""
    try:
        async with AsyncSessionLocal() as db:
            ride = (
                await db.execute(
                    select(Ride).where(
                        Ride.id == ride_id, Ride.status == RideStatus.pending
                    )
                )
            ).scalar_one_or_none()
            if ride is None:
                return  # cancelled or placed since the ids were read
            await dispatch_emergency(ride, await _symptoms(db, ride), db)
    except Exception as exc:
        # Type only: SQL errors echo statement parameters, which hold symptom text.
        log.error("retry dispatch failed ride_id=%s (%s)", ride_id, type(exc).__name__)


async def retry_pending_dispatches() -> None:
    now = datetime.now(timezone.utc)
    async with AsyncSessionLocal() as db:
        await _expire(db, now)
        await _requeue_unacknowledged(db, now)
        ride_ids = await _pending_ride_ids(db, now)
    for ride_id in ride_ids:
        await _dispatch_one(ride_id)


async def run_forever() -> None:
    while True:
        try:
            await retry_pending_dispatches()
        except Exception:
            log.exception("dispatch loop pass failed")
        await asyncio.sleep(settings.DISPATCH_LOOP_INTERVAL_SECONDS)
