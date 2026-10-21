from decimal import Decimal
from typing import Optional
from uuid import UUID
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.config import settings
from app.core.database import get_db
from app.core.security import require_driver, require_admin
from app.models.models import Driver, User
from app.schemas.drivers import (
    DriverResponse,
    DriverUpdate,
    DriverStatusUpdate,
    LocationUpdate,
    DriverListResponse,
    WalletResponse,
    WalletTopUpRequest,
    WalletTransaction,
    EarningsResponse,
    EarningsRide,
)
from app.models.models import Ride, RideStatus, WalletEntry
from app.services import driver_service
from sqlalchemy import select, func, and_, update

router = APIRouter()


class VerifyBody(BaseModel):
    is_verified: bool = True


def _to_response(driver: Driver, user: User) -> DriverResponse:
    return DriverResponse(
        id=str(driver.id),
        phone=user.phone,
        full_name=driver.full_name,
        license_no=driver.license_no,
        vehicle_plate=driver.vehicle_plate,
        vehicle_type=driver.vehicle_type,
        is_verified=driver.is_verified,
        status=driver.status,
        wallet_balance_pkr=float(driver.wallet_balance_pkr or 0),
        current_lat=driver.current_lat,
        current_lng=driver.current_lng,
        last_seen_at=driver.last_seen_at,
        created_at=driver.created_at,
    )


# ── Driver self-service ────────────────────────────────────────────────────────


@router.get("/me", response_model=DriverResponse)
async def get_me(
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    return _to_response(driver, current_user)


@router.patch("/me", response_model=DriverResponse)
async def update_me(
    body: DriverUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    driver = await driver_service.update_driver_profile(driver, body, db)
    return _to_response(driver, current_user)


@router.patch("/status", response_model=DriverResponse)
async def update_status(
    body: DriverStatusUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    driver = await driver_service.update_driver_status(driver, body, db)
    return _to_response(driver, current_user)


@router.post("/location", response_model=DriverResponse)
async def update_location(
    body: LocationUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    driver = await driver_service.update_driver_location(driver, body, db)
    return _to_response(driver, current_user)


@router.get("/earnings", response_model=EarningsResponse)
async def get_earnings(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    from app.models.models import Hospital

    driver = await driver_service.get_driver_by_user(current_user, db)
    completed = and_(Ride.driver_id == driver.id, Ride.status == RideStatus.completed)

    # Totals aggregate over ALL completed rides; the list below is paginated.
    total_earned, ride_count = (
        await db.execute(
            select(
                func.coalesce(
                    func.sum(
                        func.coalesce(Ride.final_fare_pkr, Ride.estimated_fare_pkr, 0)
                    ),
                    0,
                ),
                func.count(),
            ).where(completed)
        )
    ).one()

    rows = (
        (
            await db.execute(
                select(Ride)
                .where(completed)
                .order_by(Ride.completed_at.desc())
                .offset((page - 1) * page_size)
                .limit(page_size)
            )
        )
        .scalars()
        .all()
    )

    hospital_ids = list({r.hospital_id for r in rows if r.hospital_id})
    hospitals_map: dict = {}
    if hospital_ids:
        h_rows = (
            (await db.execute(select(Hospital).where(Hospital.id.in_(hospital_ids))))
            .scalars()
            .all()
        )
        hospitals_map = {str(h.id): h.name for h in h_rows}

    rides = [
        EarningsRide(
            id=str(r.id),
            pickup_address=r.pickup_address,
            hospital_name=hospitals_map.get(str(r.hospital_id))
            if r.hospital_id
            else None,
            completed_at=r.completed_at.isoformat() if r.completed_at else None,
            fare_pkr=float(r.final_fare_pkr or r.estimated_fare_pkr or 0),
            ride_type=r.ride_type.value,
        )
        for r in rows
    ]
    return EarningsResponse(
        total_earned_pkr=float(total_earned), ride_count=int(ride_count), rides=rides
    )


# ── Wallet ────────────────────────────────────────────────────────────────────

_PLANS = {
    "starter": {"rides": 7, "price_pkr": 250, "per_ride_pkr": 36, "savings_pct": 20},
    "standard": {"rides": 18, "price_pkr": 540, "per_ride_pkr": 30, "savings_pct": 33},
    "pro": {"rides": 36, "price_pkr": 900, "per_ride_pkr": 25, "savings_pct": 44},
}


@router.get("/wallet", response_model=WalletResponse)
async def get_wallet(
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    weekly_gross, weekly_commission = (
        await db.execute(
            select(
                func.coalesce(func.sum(Ride.final_fare_pkr), 0),
                func.coalesce(-func.sum(WalletEntry.amount), 0),
            )
            .select_from(Ride)
            .outerjoin(
                WalletEntry,
                and_(WalletEntry.ride_id == Ride.id, WalletEntry.kind == "commission"),
            )
            .where(
                Ride.driver_id == driver.id,
                Ride.status == RideStatus.completed,
                Ride.completed_at >= week_ago,
            )
        )
    ).one()

    entries = (
        (
            await db.execute(
                select(WalletEntry)
                .where(WalletEntry.driver_id == driver.id)
                .order_by(WalletEntry.created_at.desc())
                .limit(10)
            )
        )
        .scalars()
        .all()
    )

    balance = float(driver.wallet_balance_pkr or 0)
    return WalletResponse(
        balance_pkr=balance,
        commission_rate=settings.COMMISSION_RATE,
        plan=f"Pay Per Ride · {settings.COMMISSION_RATE:.0%}",
        low_balance=balance < 500,
        weekly_commission_paid=float(weekly_commission),
        weekly_net_earnings=float(weekly_gross - weekly_commission),
        transactions=[
            WalletTransaction(
                id=str(e.id),
                type=e.kind,
                amount_pkr=float(e.amount),
                description=e.kind.replace("_", " ").title(),
                created_at=e.created_at,
            )
            for e in entries
        ],
    )


@router.post("/{driver_id}/wallet/topup", response_model=DriverResponse)
async def topup_wallet(
    driver_id: UUID,
    body: WalletTopUpRequest,
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Admin credits a specific driver's wallet (manual JazzCash/EasyPaisa settlement)."""
    if body.plan_id and body.plan_id in _PLANS:
        amount = float(_PLANS[body.plan_id]["price_pkr"])
    else:
        if body.amount_pkr <= 0:
            raise HTTPException(status_code=422, detail="amount_pkr must be positive")
        amount = body.amount_pkr

    driver = (
        await db.execute(select(Driver).where(Driver.id == driver_id))
    ).scalar_one_or_none()
    if driver is None:
        raise HTTPException(status_code=404, detail="Driver not found")
    user = (
        await db.execute(select(User).where(User.id == driver.user_id))
    ).scalar_one()

    # Ledger row and balance change commit together; the increment is done in SQL
    # so concurrent top-ups cannot overwrite each other.
    db.add(WalletEntry(driver_id=driver.id, kind="topup", amount=Decimal(str(amount))))
    await db.execute(
        update(Driver)
        .where(Driver.id == driver.id)
        .values(wallet_balance_pkr=func.coalesce(Driver.wallet_balance_pkr, 0) + amount)
    )
    await db.commit()
    await db.refresh(driver)
    return _to_response(driver, user)


# ── Admin ─────────────────────────────────────────────────────────────────────


@router.get("", response_model=DriverListResponse)
async def list_drivers(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None),
    is_verified: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    rows, total = await driver_service.list_drivers(
        db, page, page_size, status, is_verified, search
    )
    items = [_to_response(driver, user) for driver, user in rows]
    return DriverListResponse(items=items, total=total, page=page)


@router.patch("/{driver_id}/verify", response_model=DriverResponse)
async def verify_driver(
    driver_id: UUID,
    body: VerifyBody = VerifyBody(),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    driver, user = await driver_service.set_driver_verified(
        driver_id, body.is_verified, db
    )
    return _to_response(driver, user)
