"""
Analytics endpoints.
- Hourly snapshot writer (Celery task hook / admin trigger)
- Dashboard summary (live counts from DB)
- Demand forecast (simple rolling 7-day average per city/hour)
"""

from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.core.security import require_admin
from app.models.models import (
    Ride,
    Driver,
    Hospital,
    AnalyticsHourly,
    RideType,
    RideStatus,
    DriverStatus,
    User,
)

router = APIRouter()


# ── Live dashboard summary ────────────────────────────────────────────────────


@router.get("/summary")
async def dashboard_summary(
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(hours=24)

    total_rides = (await db.execute(select(func.count()).select_from(Ride))).scalar()

    emergency_24h = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(
                and_(Ride.ride_type == RideType.emergency, Ride.requested_at >= day_ago)
            )
        )
    ).scalar()

    active_rides = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(
                Ride.status.in_(
                    [
                        RideStatus.driver_assigned,
                        RideStatus.driver_en_route,
                        RideStatus.patient_picked_up,
                    ]
                )
            )
        )
    ).scalar()

    available_drivers = (
        await db.execute(
            select(func.count())
            .select_from(Driver)
            .where(Driver.status == DriverStatus.available)
        )
    ).scalar()

    total_drivers = (
        await db.execute(select(func.count()).select_from(Driver))
    ).scalar()
    active_hospitals = (
        await db.execute(
            select(func.count())
            .select_from(Hospital)
            .where(Hospital.is_active.is_(True))
        )
    ).scalar()

    avg_eta = (
        await db.execute(
            select(func.avg(AnalyticsHourly.avg_eta_seconds)).where(
                AnalyticsHourly.snapshot_hour >= day_ago
            )
        )
    ).scalar()

    return {
        "total_rides": total_rides,
        "emergency_rides_24h": emergency_24h,
        "active_rides": active_rides,
        "available_drivers": available_drivers,
        "total_drivers": total_drivers,
        "active_hospitals": active_hospitals,
        "avg_eta_seconds_24h": round(float(avg_eta), 1) if avg_eta else None,
        "snapshot_at": now.isoformat(),
    }


# ── Hourly snapshot writer ────────────────────────────────────────────────────


@router.post("/snapshot", status_code=201)
async def write_hourly_snapshot(
    city: str = Query(..., description="City name to snapshot"),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Write one analytics snapshot for the current hour. Called by Celery or admin."""
    now = datetime.now(timezone.utc)
    hour_start = now.replace(minute=0, second=0, microsecond=0)
    next_hour = hour_start + timedelta(hours=1)

    hour_rides = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(and_(Ride.requested_at >= hour_start, Ride.requested_at < next_hour))
        )
    ).scalar()

    emergency_rides = (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(
                and_(
                    Ride.ride_type == RideType.emergency,
                    Ride.requested_at >= hour_start,
                    Ride.requested_at < next_hour,
                )
            )
        )
    ).scalar()

    total_drivers = (
        await db.execute(select(func.count()).select_from(Driver))
    ).scalar()
    busy_drivers = (
        await db.execute(
            select(func.count())
            .select_from(Driver)
            .where(Driver.status == DriverStatus.busy)
        )
    ).scalar()
    utilisation = (busy_drivers / max(total_drivers, 1)) * 100

    snapshot = AnalyticsHourly(
        snapshot_hour=hour_start,
        city=city,
        total_rides=hour_rides,
        emergency_rides=emergency_rides,
        driver_utilisation_pct=round(utilisation, 2),
    )
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)

    return {
        "id": str(snapshot.id),
        "snapshot_hour": hour_start.isoformat(),
        "city": city,
        "total_rides": hour_rides,
        "emergency_rides": emergency_rides,
        "driver_utilisation_pct": round(utilisation, 2),
    }


# ── Demand forecast ───────────────────────────────────────────────────────────


@router.get("/forecast")
async def demand_forecast(
    city: str = Query(...),
    hours_ahead: int = Query(6, ge=1, le=24),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """
    Rolling 7-day average per hour-of-day as the forecast baseline.
    Returns predicted ride counts for the next `hours_ahead` hours.
    """
    now = datetime.now(timezone.utc)
    lookback = now - timedelta(days=7)

    rows = (
        (
            await db.execute(
                select(AnalyticsHourly)
                .where(
                    and_(
                        AnalyticsHourly.city == city,
                        AnalyticsHourly.snapshot_hour >= lookback,
                    )
                )
                .order_by(AnalyticsHourly.snapshot_hour)
            )
        )
        .scalars()
        .all()
    )

    # Build avg rides per hour-of-day (0–23)
    hour_totals: dict[int, list[int]] = {h: [] for h in range(24)}
    for r in rows:
        h = r.snapshot_hour.hour
        hour_totals[h].append(r.total_rides)

    avgs = {h: round(sum(v) / len(v), 1) if v else 0.0 for h, v in hour_totals.items()}

    forecast = []
    for i in range(hours_ahead):
        target = now + timedelta(hours=i + 1)
        target_hour = target.replace(minute=0, second=0, microsecond=0)
        forecast.append(
            {
                "hour": target_hour.isoformat(),
                "predicted_rides": avgs.get(target_hour.hour, 0.0),
            }
        )

    return {
        "city": city,
        "generated_at": now.isoformat(),
        "method": "rolling_7day_hourly_avg",
        "forecast": forecast,
    }


# ── Historical ride counts ────────────────────────────────────────────────────


@router.get("/history")
async def ride_history(
    city: str = Query(...),
    days: int = Query(7, ge=1, le=30),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = (
        (
            await db.execute(
                select(AnalyticsHourly)
                .where(
                    and_(
                        AnalyticsHourly.city == city,
                        AnalyticsHourly.snapshot_hour >= since,
                    )
                )
                .order_by(AnalyticsHourly.snapshot_hour)
            )
        )
        .scalars()
        .all()
    )

    return {
        "city": city,
        "days": days,
        "snapshots": [
            {
                "hour": r.snapshot_hour.isoformat(),
                "total_rides": r.total_rides,
                "emergency_rides": r.emergency_rides,
                "driver_utilisation_pct": float(r.driver_utilisation_pct)
                if r.driver_utilisation_pct
                else None,
                "avg_eta_seconds": float(r.avg_eta_seconds)
                if r.avg_eta_seconds
                else None,
            }
            for r in rows
        ],
    }
