"""Refreshes the gauges the alert rules watch.

Run by the dispatch loop each pass. Every check is isolated and none can raise:
a broken dependency must show up as a gauge at 0, not as a crashed loop.
"""

import logging
from datetime import datetime, timezone

from sqlalchemy import func, select

from app.core import metrics
from app.core.database import AsyncSessionLocal
from app.core.redis_client import ping_redis
from app.models.models import Driver, Ride, RideStatus, RideType, WalletEntry

log = logging.getLogger("smartride.health_metrics")


async def _oldest_pending_age_seconds(db) -> float:
    oldest = (
        await db.execute(
            select(func.min(Ride.queued_at)).where(
                Ride.status == RideStatus.pending, Ride.ride_type == RideType.emergency
            )
        )
    ).scalar_one_or_none()
    if oldest is None:
        return 0.0
    return max(0.0, (datetime.now(timezone.utc) - oldest).total_seconds())


async def _ledger_mismatch_count(db) -> int:
    ledger_total = func.coalesce(
        select(func.sum(WalletEntry.amount))
        .where(WalletEntry.driver_id == Driver.id)
        .scalar_subquery(),
        0,
    )
    return (
        await db.execute(
            select(func.count())
            .select_from(Driver)
            .where(Driver.wallet_balance_pkr != ledger_total)
        )
    ).scalar_one()


async def record_health_metrics() -> None:
    """Set smartride_dependency_up and the pending-ride and ledger gauges."""
    try:
        async with AsyncSessionLocal() as db:
            await db.execute(select(1))
            metrics.dependency_up.labels(dependency="database").set(1)
            metrics.oldest_pending_ride_age_seconds.set(
                await _oldest_pending_age_seconds(db)
            )
            metrics.wallet_ledger_mismatch_drivers.set(await _ledger_mismatch_count(db))
    except Exception as exc:
        metrics.dependency_up.labels(dependency="database").set(0)
        log.error("database health check failed (%s)", type(exc).__name__)
    try:
        metrics.dependency_up.labels(dependency="redis").set(
            1 if await ping_redis() else 0
        )
    except Exception as exc:
        metrics.dependency_up.labels(dependency="redis").set(0)
        log.error("redis health check failed (%s)", type(exc).__name__)
