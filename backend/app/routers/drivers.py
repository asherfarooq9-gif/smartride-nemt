from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from pydantic import BaseModel

from app.core.database import get_db
from app.core.security import require_driver, require_admin
from app.models.models import Driver, User, DriverStatus
from app.schemas.drivers import (
    DriverResponse, DriverUpdate, DriverStatusUpdate,
    LocationUpdate, DriverListResponse,
)

router = APIRouter()


class VerifyBody(BaseModel):
    is_verified: bool = True


async def _get_driver_for_user(user: User, db: AsyncSession) -> Driver:
    result = await db.execute(select(Driver).where(Driver.user_id == user.id))
    driver = result.scalar_one_or_none()
    if not driver:
        raise HTTPException(status_code=404, detail="Driver profile not found")
    return driver


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
    driver = await _get_driver_for_user(current_user, db)
    return _to_response(driver, current_user)


@router.patch("/me", response_model=DriverResponse)
async def update_me(
    body: DriverUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await _get_driver_for_user(current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(driver, field, value)
    await db.commit()
    await db.refresh(driver)
    return _to_response(driver, current_user)


@router.patch("/status", response_model=DriverResponse)
async def update_status(
    body: DriverStatusUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await _get_driver_for_user(current_user, db)
    driver.status = body.status
    await db.commit()
    await db.refresh(driver)
    return _to_response(driver, current_user)


@router.post("/location", response_model=DriverResponse)
async def update_location(
    body: LocationUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await _get_driver_for_user(current_user, db)
    driver.current_lat = body.lat
    driver.current_lng = body.lng
    driver.last_seen_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(driver)
    return _to_response(driver, current_user)


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
    base_q = select(Driver, User).join(User, Driver.user_id == User.id)
    conditions = []
    if status:
        try:
            conditions.append(Driver.status == DriverStatus(status))
        except ValueError:
            pass
    if is_verified is not None:
        conditions.append(Driver.is_verified == (is_verified.lower() == 'true'))
    if search:
        conditions.append(
            or_(
                Driver.full_name.ilike(f"%{search}%"),
                User.phone.ilike(f"%{search}%"),
                Driver.vehicle_plate.ilike(f"%{search}%"),
            )
        )
    if conditions:
        from sqlalchemy import and_
        base_q = base_q.where(and_(*conditions))

    total = (await db.execute(
        select(func.count()).select_from(base_q.subquery())
    )).scalar()
    rows = (await db.execute(
        base_q.order_by(Driver.created_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).all()
    items = [_to_response(driver, user) for driver, user in rows]
    return DriverListResponse(items=items, total=total, page=page)


@router.patch("/{driver_id}/verify", response_model=DriverResponse)
async def verify_driver(
    driver_id: str,
    body: VerifyBody = VerifyBody(),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Driver, User)
        .join(User, Driver.user_id == User.id)
        .where(Driver.id == driver_id)
    )
    row = result.one_or_none()
    if not row:
        raise HTTPException(status_code=404, detail="Driver not found")
    driver, user = row
    driver.is_verified = body.is_verified
    await db.commit()
    await db.refresh(driver)
    return _to_response(driver, user)
