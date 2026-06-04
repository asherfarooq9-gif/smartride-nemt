from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db
from app.core.security import require_driver, require_admin
from app.models.models import Driver, User
from app.schemas.drivers import (
    DriverResponse,
    DriverUpdate,
    DriverStatusUpdate,
    LocationUpdate,
    DriverListResponse,
)
from app.services import driver_service

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
    driver_id: str,
    body: VerifyBody = VerifyBody(),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    driver, user = await driver_service.set_driver_verified(
        driver_id, body.is_verified, db
    )
    return _to_response(driver, user)
