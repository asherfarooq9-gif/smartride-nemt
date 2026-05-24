from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import require_admin
from app.models.models import Hospital, User
from app.schemas.hospitals import (
    HospitalResponse, HospitalCreate, HospitalUpdate, HospitalListResponse,
)
from app.services import hospital_service

router = APIRouter()


def _to_response(h: Hospital) -> HospitalResponse:
    return HospitalResponse(
        id=str(h.id),
        name=h.name,
        address=h.address,
        city=h.city,
        lat=h.lat,
        lng=h.lng,
        phone=h.phone,
        specialties=h.specialties or [],
        ed_capacity=h.ed_capacity,
        ed_current_load=h.ed_current_load,
        fhir_endpoint=h.fhir_endpoint,
        coordinator_phone=h.coordinator_phone,
        is_active=h.is_active,
        created_at=h.created_at,
    )


# ── Public ────────────────────────────────────────────────────────────────────

@router.get("", response_model=HospitalListResponse)
async def list_hospitals(
    active_only: bool = Query(True),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    items, total = await hospital_service.list_hospitals(db, active_only, page, page_size)
    # items may be HospitalResponse (cached) or Hospital (DB); normalise
    responses = [
        item if isinstance(item, HospitalResponse) else _to_response(item)
        for item in items
    ]
    return HospitalListResponse(items=responses, total=total)


@router.get("/{hospital_id}", response_model=HospitalResponse)
async def get_hospital(hospital_id: str, db: AsyncSession = Depends(get_db)):
    h = await hospital_service.get_hospital_by_id(hospital_id, db)
    return _to_response(h)


# ── Admin ─────────────────────────────────────────────────────────────────────

@router.post("", response_model=HospitalResponse, status_code=201)
async def create_hospital(
    body: HospitalCreate,
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    h = await hospital_service.create_hospital(body, db)
    return _to_response(h)


@router.patch("/{hospital_id}", response_model=HospitalResponse)
async def update_hospital(
    hospital_id: str,
    body: HospitalUpdate,
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    h = await hospital_service.update_hospital(hospital_id, body, db)
    return _to_response(h)
