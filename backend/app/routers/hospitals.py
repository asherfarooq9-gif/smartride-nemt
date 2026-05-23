from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import require_admin
from app.core.redis_client import get_cached, invalidate_cache
from app.models.models import Hospital, User
from app.schemas.hospitals import (
    HospitalResponse, HospitalCreate, HospitalUpdate, HospitalListResponse,
)

HOSPITALS_CACHE_KEY = "cache:hospitals:active"
HOSPITALS_CACHE_TTL = 300  # 5 minutes

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
    db: AsyncSession = Depends(get_db),
):
    if active_only:
        async def _load():
            result = await db.execute(
                select(Hospital).where(Hospital.is_active.is_(True)).order_by(Hospital.name)
            )
            hospitals = result.scalars().all()
            return [HospitalResponse.model_validate(h).model_dump(mode="json") for h in hospitals]

        items_data = await get_cached(HOSPITALS_CACHE_KEY, HOSPITALS_CACHE_TTL, _load)
        items = [HospitalResponse(**item) for item in items_data]
        return HospitalListResponse(items=items, total=len(items))

    query = select(Hospital)
    result = await db.execute(query)
    hospitals = result.scalars().all()
    return HospitalListResponse(items=[_to_response(h) for h in hospitals], total=len(hospitals))


@router.get("/{hospital_id}", response_model=HospitalResponse)
async def get_hospital(hospital_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Hospital).where(Hospital.id == hospital_id))
    h = result.scalar_one_or_none()
    if not h:
        raise HTTPException(status_code=404, detail="Hospital not found")
    return _to_response(h)


# ── Admin ─────────────────────────────────────────────────────────────────────

@router.post("", response_model=HospitalResponse, status_code=201)
async def create_hospital(
    body: HospitalCreate,
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    h = Hospital(**body.model_dump())
    db.add(h)
    await db.commit()
    await db.refresh(h)
    await invalidate_cache(HOSPITALS_CACHE_KEY)
    return _to_response(h)


@router.patch("/{hospital_id}", response_model=HospitalResponse)
async def update_hospital(
    hospital_id: str,
    body: HospitalUpdate,
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Hospital).where(Hospital.id == hospital_id))
    h = result.scalar_one_or_none()
    if not h:
        raise HTTPException(status_code=404, detail="Hospital not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(h, field, value)
    await db.commit()
    await db.refresh(h)
    await invalidate_cache(HOSPITALS_CACHE_KEY)
    return _to_response(h)
