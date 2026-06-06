from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db
from app.core.security import require_driver, require_admin
from app.models.models import Driver, User
from app.schemas.drivers import (
    DriverResponse, DriverUpdate, DriverStatusUpdate,
    LocationUpdate, DriverListResponse,
)
from app.models.models import Ride, RideStatus
from app.services import driver_service
from sqlalchemy import select, func, and_

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


@router.get("/earnings")
async def get_earnings(
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await driver_service.get_driver_by_user(current_user, db)
    rows = (await db.execute(
        select(Ride).where(
            and_(Ride.driver_id == driver.id, Ride.status == RideStatus.completed)
        ).order_by(Ride.completed_at.desc())
    )).scalars().all()

    total_earned = sum(float(r.final_fare_pkr or r.estimated_fare_pkr or 0) for r in rows)
    rides = [
        {
            "id": str(r.id),
            "pickup_address": r.pickup_address,
            "completed_at": r.completed_at.isoformat() if r.completed_at else None,
            "fare_pkr": float(r.final_fare_pkr or r.estimated_fare_pkr or 0),
            "ride_type": r.ride_type.value,
        }
        for r in rows
    ]
    return {"total_earned_pkr": total_earned, "ride_count": len(rows), "rides": rides}


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
    rows, total = await driver_service.list_drivers(db, page, page_size, status, is_verified, search)
    items = [_to_response(driver, user) for driver, user in rows]
    return DriverListResponse(items=items, total=total, page=page)


@router.patch("/{driver_id}/verify", response_model=DriverResponse)
async def verify_driver(
    driver_id: str,
    body: VerifyBody = VerifyBody(),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    driver, user = await driver_service.set_driver_verified(driver_id, body.is_verified, db)
    return _to_response(driver, user)
