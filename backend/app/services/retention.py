"""Retention for raw symptom free-text (PHI).

Specialty and severity stay for analytics; the patient's own words are blanked
once the ride has been over for SYMPTOM_RETENTION_DAYS. 0 disables the purge.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select, update

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.models import Ride, TriageEvent
from app.services.ride_service import TERMINAL_STATUSES

log = logging.getLogger("smartride.retention")

PURGED_MARKER = "[purged]"
PURGE_INTERVAL_SECONDS = 6 * 3600


async def purge_old_symptoms(db, now: datetime | None = None) -> int:
    """Blank symptom text on rides over for longer than the retention window."""
    if settings.SYMPTOM_RETENTION_DAYS <= 0:
        return 0
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(
        days=settings.SYMPTOM_RETENTION_DAYS
    )
    ended_before_cutoff = (
        Ride.status.in_(TERMINAL_STATUSES),
        func.coalesce(Ride.completed_at, Ride.cancelled_at) < cutoff,
    )
    old_rides = select(Ride.id).where(*ended_before_cutoff)
    await db.execute(
        update(TriageEvent)
        .where(
            TriageEvent.ride_id.in_(old_rides),
            TriageEvent.symptom_text != PURGED_MARKER,
        )
        .values(symptom_text=PURGED_MARKER)
    )
    result = await db.execute(
        update(Ride)
        .where(*ended_before_cutoff, Ride.symptom_text.is_not(None))
        .values(symptom_text=None)
    )
    await db.commit()
    return result.rowcount or 0


async def run_forever() -> None:
    while True:
        try:
            async with AsyncSessionLocal() as db:
                purged = await purge_old_symptoms(db)
            if purged:
                log.info("retention purged symptom text on %d rides", purged)
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("retention purge failed")
        await asyncio.sleep(PURGE_INTERVAL_SECONDS)
