"""Busy hours ahead, for drivers: the average number of ride requests per hour.

The baseline is how many rides were requested in the same hour of the day, per
day, over the last four weeks. It reads the rides themselves, so it needs no
snapshot job and works from the first ride. It is a plain average, not a
trained model.

Hours are Pakistan time (UTC+5, no daylight saving): that is how drivers and
patients think about the day.
"""

import math
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Ride

LOOKBACK_DAYS = 28
METHOD = "hourly_average_28d"
_PAKISTAN_TIME = "Asia/Karachi"
_PAKISTAN_UTC_OFFSET = timedelta(hours=5)

# A level is relative to the day's busiest hour, so it reads the same in a
# quiet city and a busy one.
_HIGH_SHARE = 0.7
_MEDIUM_SHARE = 0.35


def _level(rides: float, busiest: float) -> str:
    if busiest <= 0:
        return "low"
    share = rides / busiest
    if share >= _HIGH_SHARE:
        return "high"
    if share >= _MEDIUM_SHARE:
        return "medium"
    return "low"


async def hourly_demand(
    db: AsyncSession,
    now: datetime,
    hours_ahead: int,
    lookback_days: int = LOOKBACK_DAYS,
) -> dict:
    """Predicted ride requests for each of the next `hours_ahead` hours."""
    since = now - timedelta(days=lookback_days)
    in_window = (Ride.requested_at >= since) & (Ride.requested_at <= now)

    pakistan_hour = func.extract(
        "hour", func.timezone(_PAKISTAN_TIME, Ride.requested_at)
    )
    counts = {
        int(hour): count
        for hour, count in (
            await db.execute(
                select(pakistan_hour, func.count())
                .where(in_window)
                .group_by(pakistan_hour)
            )
        ).all()
    }
    earliest = (
        await db.execute(select(func.min(Ride.requested_at)).where(in_window))
    ).scalar()

    # A young history is not diluted: one ride yesterday is one ride per day.
    days_observed = 1
    if earliest is not None:
        days = math.ceil((now - earliest).total_seconds() / 86400)
        days_observed = min(max(days, 1), lookback_days)

    average = {hour: count / days_observed for hour, count in counts.items()}
    busiest = max(average.values(), default=0.0)

    this_hour = now.astimezone(timezone.utc).replace(minute=0, second=0, microsecond=0)
    forecast = []
    for ahead in range(1, hours_ahead + 1):
        target = this_hour + timedelta(hours=ahead)
        rides = average.get((target + _PAKISTAN_UTC_OFFSET).hour, 0.0)
        forecast.append(
            {
                "hour": target.isoformat(),
                "predicted_rides": round(rides, 1),
                "level": _level(rides, busiest),
            }
        )

    return {
        "generated_at": now.isoformat(),
        "method": METHOD,
        "has_data": bool(counts),
        "forecast": forecast,
    }
