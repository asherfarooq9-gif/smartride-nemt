from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Driver, User, DriverStatus
from app.schemas.drivers import DriverUpdate, DriverStatusUpdate, LocationUpdate


async def get_driver_by_user(user: User, db: AsyncSession) -> Driver:
    result = await db.execute(select(Driver).where(Driver.user_id == user.id))
    driver = result.scalar_one_or_none()
    if not driver:
        raise HTTPException(404, "Driver profile not found")
    return driver


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
                Driver.full_name.ilike(f"%{search}%"),
                User.phone.ilike(f"%{search}%"),
                Driver.vehicle_plate.ilike(f"%{search}%"),
            )
        )
    if conditions:
        base_q = base_q.where(and_(*conditions))

    total = (
        await db.execute(select(func.count()).select_from(base_q.subquery()))
    ).scalar()
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
