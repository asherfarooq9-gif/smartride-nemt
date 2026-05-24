from typing import Optional

from fastapi import HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import Patient, User, Ride
from app.schemas.patients import PatientUpdate


async def get_patient_by_user(user: User, db: AsyncSession) -> Patient:
    result = await db.execute(select(Patient).where(Patient.user_id == user.id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(404, "Patient profile not found")
    return patient


async def get_patient_total_rides(patient_id: str, db: AsyncSession) -> int:
    return (
        await db.execute(select(func.count()).select_from(Ride).where(Ride.patient_id == patient_id))
    ).scalar() or 0


async def update_patient(patient: Patient, body: PatientUpdate, db: AsyncSession) -> Patient:
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(patient, field, value)
    await db.commit()
    await db.refresh(patient)
    return patient


async def list_patients(
    db: AsyncSession,
    page: int,
    page_size: int,
    search: Optional[str] = None,
) -> tuple[list[tuple[Patient, User]], int]:
    base_q = select(Patient, User).join(User, Patient.user_id == User.id)
    if search:
        base_q = base_q.where(
            Patient.full_name.ilike(f"%{search}%") | User.phone.ilike(f"%{search}%")
        )
    total = (await db.execute(select(func.count()).select_from(base_q.subquery()))).scalar()
    rows = (await db.execute(
        base_q.order_by(Patient.created_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).all()
    return list(rows), total
