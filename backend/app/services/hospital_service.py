from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis_client import get_cached, invalidate_cache
from app.models.models import Hospital
from app.schemas.hospitals import HospitalCreate, HospitalUpdate, HospitalResponse

HOSPITALS_CACHE_KEY = "cache:hospitals:active"
HOSPITALS_CACHE_TTL = 300


async def list_hospitals(
    db: AsyncSession,
    active_only: bool,
    page: int,
    page_size: int,
) -> tuple[list[Hospital], int]:
    if active_only:
        async def _load():
            result = await db.execute(
                select(Hospital).where(Hospital.is_active.is_(True)).order_by(Hospital.name)
            )
            hospitals = result.scalars().all()
            return [HospitalResponse.model_validate(h).model_dump(mode="json") for h in hospitals]

        items_data = await get_cached(HOSPITALS_CACHE_KEY, HOSPITALS_CACHE_TTL, _load)
        all_hospitals = [HospitalResponse.model_validate(item) for item in items_data]
        total = len(all_hospitals)
        start = (page - 1) * page_size
        return all_hospitals[start: start + page_size], total

    base_q = select(Hospital).order_by(Hospital.name)
    total = (await db.execute(select(func.count()).select_from(base_q.subquery()))).scalar()
    result = await db.execute(base_q.offset((page - 1) * page_size).limit(page_size))
    return list(result.scalars().all()), total


async def get_hospital_by_id(hospital_id: str, db: AsyncSession) -> Hospital:
    result = await db.execute(select(Hospital).where(Hospital.id == hospital_id))
    hospital = result.scalar_one_or_none()
    if not hospital:
        raise HTTPException(404, "Hospital not found")
    return hospital


async def create_hospital(body: HospitalCreate, db: AsyncSession) -> Hospital:
    hospital = Hospital(**body.model_dump())
    db.add(hospital)
    await db.commit()
    await db.refresh(hospital)
    await invalidate_cache(HOSPITALS_CACHE_KEY)
    return hospital


async def update_hospital(hospital_id: str, body: HospitalUpdate, db: AsyncSession) -> Hospital:
    hospital = await get_hospital_by_id(hospital_id, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(hospital, field, value)
    await db.commit()
    await db.refresh(hospital)
    await invalidate_cache(HOSPITALS_CACHE_KEY)
    return hospital
