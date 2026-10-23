from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select, func, and_, or_, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.search import contains
from app.models.models import (
    Driver,
    Ride,
    RideStatus,
    User,
    DriverStatus,
    WalletEntry,
)
from app.schemas.drivers import DriverUpdate, DriverStatusUpdate, LocationUpdate


ACTIVE_RIDE_STATUSES = (
    RideStatus.driver_assigned,
    RideStatus.driver_en_route,
    RideStatus.patient_picked_up,
    RideStatus.arrived_at_hospital,
)


async def get_driver_by_user(user: User, db: AsyncSession) -> Driver:
    result = await db.execute(select(Driver).where(Driver.user_id == user.id))
    driver = result.scalar_one_or_none()
    if not driver:
        raise HTTPException(404, "Driver profile not found")
    return driver


async def apply_balance_delta(db: AsyncSession, driver_id: UUID, delta: Decimal) -> None:
    """Add `delta` to a driver's wallet balance in SQL (no read-modify-write).

    Negative balances are allowed on purpose: commission is debited after the
    ride completes, so a driver may owe money. Do not add a >= 0 guard here.
    Exactly one row must change; anything else means the ledger and the driver
    row have diverged and the caller's transaction must not commit.
    """
    result = await db.execute(
        update(Driver)
        .where(Driver.id == driver_id)
        .values(wallet_balance_pkr=Driver.wallet_balance_pkr + delta)
    )
    if result.rowcount != 1:
        raise RuntimeError(
            f"wallet balance update for driver {driver_id} affected "
            f"{result.rowcount} rows, expected exactly 1"
        )


async def record_topup(
    db: AsyncSession,
    driver_id: UUID,
    amount: Decimal,
    admin_user_id: UUID,
    payment_method: str,
    idempotency_key: Optional[str],
) -> bool:
    """Credit a top-up once. Returns False when the idempotency key was a replay.

    The ledger insert and the balance change run in the caller's transaction.
    ON CONFLICT DO NOTHING on the idempotency key makes a replay (or a racing
    duplicate) a no-op instead of a second credit.
    """
    inserted = await db.execute(
        pg_insert(WalletEntry)
        .values(
            driver_id=driver_id,
            kind="topup",
            amount=amount,
            idempotency_key=idempotency_key,
            admin_user_id=admin_user_id,
            payment_method=payment_method,
        )
        .on_conflict_do_nothing(constraint="uq_wallet_idempotency_key")
        .returning(WalletEntry.id)
    )
    if inserted.first() is None:
        return False
    await apply_balance_delta(db, driver_id, amount)
    return True


async def get_topup_by_key(db: AsyncSession, idempotency_key: str) -> WalletEntry:
    return (
        await db.execute(
            select(WalletEntry).where(WalletEntry.idempotency_key == idempotency_key)
        )
    ).scalar_one()


async def update_driver_profile(
    driver: Driver, body: DriverUpdate, db: AsyncSession
) -> Driver:
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(driver, field, value)
    await db.commit()
    await db.refresh(driver)
    return driver


async def update_driver_status(
    driver: Driver, body: DriverStatusUpdate, db: AsyncSession
) -> Driver:
    if body.status == DriverStatus.available:
        # Going available mid-ride would let dispatch assign a second ride.
        on_ride = await db.execute(
            select(Ride.id)
            .where(Ride.driver_id == driver.id, Ride.status.in_(ACTIVE_RIDE_STATUSES))
            .limit(1)
        )
        if on_ride.first() is not None:
            raise HTTPException(409, "Finish or cancel your current ride first")
    driver.status = body.status
    await db.commit()
    await db.refresh(driver)
    return driver


async def update_driver_location(
    driver: Driver, body: LocationUpdate, db: AsyncSession
) -> Driver:
    driver.current_lat = body.lat
    driver.current_lng = body.lng
    driver.last_seen_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(driver)
    return driver


async def list_drivers(
    db: AsyncSession,
    page: int,
    page_size: int,
    status: Optional[str] = None,
    is_verified: Optional[str] = None,
    search: Optional[str] = None,
) -> tuple[list[tuple[Driver, User]], int]:
    base_q = select(Driver, User).join(User, Driver.user_id == User.id)
    conditions = []
    if status:
        try:
            conditions.append(Driver.status == DriverStatus(status))
        except ValueError:
            pass
    if is_verified is not None:
        conditions.append(Driver.is_verified == (is_verified.lower() == "true"))
    if search:
        conditions.append(
            or_(
                Driver.full_name.ilike(contains(search), escape="\\"),
                User.phone.ilike(contains(search), escape="\\"),
                Driver.vehicle_plate.ilike(contains(search), escape="\\"),
            )
        )
    if conditions:
        base_q = base_q.where(and_(*conditions))

    count_q = select(func.count()).select_from(Driver).join(User, Driver.user_id == User.id)
    if conditions:
        count_q = count_q.where(and_(*conditions))
    total = (await db.execute(count_q)).scalar()
    rows = (
        await db.execute(
            base_q.order_by(Driver.created_at.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).all()
    return list(rows), total


async def get_driver_by_id(driver_id: str, db: AsyncSession) -> tuple[Driver, User]:
    result = await db.execute(
        select(Driver, User)
        .join(User, Driver.user_id == User.id)
        .where(Driver.id == driver_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(404, "Driver not found")
    return row


async def set_driver_verified(
    driver_id: str, is_verified: bool, db: AsyncSession
) -> tuple[Driver, User]:
    driver, user = await get_driver_by_id(driver_id, db)
    driver.is_verified = is_verified
    await db.commit()
    await db.refresh(driver)
    return driver, user
