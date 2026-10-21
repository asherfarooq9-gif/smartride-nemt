"""Keeps trying to place rides that the first dispatch could not.

The first dispatch runs as a request background task, so a restart, a missing
driver or a missing hospital used to strand the ride. This loop re-dispatches
stale pending rides, promotes scheduled rides that fall due, and closes rides
nobody accepted in time. Safe to run on several instances at once: assignment
is a guarded UPDATE, so only one dispatch can win a given ride or driver.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select, update

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.models import Ride, RideStatus, RideType, TriageEvent
from app.services.emergency_dispatch import dispatch_emergency
from app.services.notifications import notify_user

log = logging.getLogger("smartride.dispatch_loop")
BATCH = 20


async def _symptoms(db, ride: Ride) -> str:
    text = (
        await db.execute(
            select(TriageEvent.symptom_text)
            .where(TriageEvent.ride_id == ride.id)
            .order_by(TriageEvent.created_at)
            .limit(1)
        )
    ).scalar_one_or_none()
    return text or "scheduled transport"


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
                    and_(
                        Ride.ride_type == RideType.emergency, Ride.requested_at < cutoff
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
        await notify_user(
            db,
            patient_id=patient_id,
            title="No driver available",
            body="We could not find a driver. Please call 1122.",
            data={"ride_id": str(ride_id)},
        )


async def retry_pending_dispatches() -> None:
    now = datetime.now(timezone.utc)
    async with AsyncSessionLocal() as db:
        await _expire(db, now)
        stale = now - timedelta(seconds=settings.DISPATCH_RETRY_AFTER_SECONDS)
        lead = now + timedelta(minutes=settings.SCHEDULED_DISPATCH_LEAD_MINUTES)
        rides = (
            (
                await db.execute(
                    select(Ride)
                    .where(
                        Ride.status == RideStatus.pending,
                        or_(
                            and_(
                                Ride.ride_type == RideType.emergency,
                                Ride.requested_at < stale,
                            ),
                            and_(
                                Ride.ride_type == RideType.scheduled,
                                Ride.scheduled_for <= lead,
                            ),
                        ),
                    )
                    .order_by(Ride.requested_at)
                    .limit(BATCH)
                )
            )
            .scalars()
            .all()
        )
        for ride in rides:
            try:
                await dispatch_emergency(ride, await _symptoms(db, ride), db)
            except Exception:
                await db.rollback()
                log.exception("retry dispatch failed for ride %s", ride.id)


async def run_forever() -> None:
    while True:
        try:
            await retry_pending_dispatches()
        except Exception:
            log.exception("dispatch loop pass failed")
        await asyncio.sleep(settings.DISPATCH_LOOP_INTERVAL_SECONDS)
