from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import require_patient, require_admin
from app.models.models import Patient, User, Ride
from app.schemas.patients import PatientResponse, PatientUpdate, PatientListResponse

router = APIRouter()


async def _get_patient_for_user(user: User, db: AsyncSession) -> Patient:
    result = await db.execute(select(Patient).where(Patient.user_id == user.id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    return patient


async def _to_response(patient: Patient, user: User, db: AsyncSession) -> PatientResponse:
    total_rides = (
        await db.execute(select(func.count()).select_from(Ride).where(Ride.patient_id == patient.id))
    ).scalar() or 0
    return PatientResponse(
        id=str(patient.id),
        phone=user.phone,
        full_name=patient.full_name,
        date_of_birth=patient.date_of_birth,
        mobility_needs=patient.mobility_needs,
        emergency_contact_name=patient.emergency_contact_name,
        emergency_contact_phone=patient.emergency_contact_phone,
        created_at=patient.created_at,
        total_rides=total_rides,
    )


@router.get("/me", response_model=PatientResponse)
async def get_me(
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await _get_patient_for_user(current_user, db)
    return await _to_response(patient, current_user, db)


@router.patch("/me", response_model=PatientResponse)
async def update_me(
    body: PatientUpdate,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await _get_patient_for_user(current_user, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(patient, field, value)
    await db.commit()
    await db.refresh(patient)
    return await _to_response(patient, current_user, db)


@router.get("", response_model=PatientListResponse)
async def list_patients(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    base_q = select(Patient, User).join(User, Patient.user_id == User.id)
    if search:
        base_q = base_q.where(
            Patient.full_name.ilike(f"%{search}%") | User.phone.ilike(f"%{search}%")
        )
    total = (await db.execute(
        select(func.count()).select_from(base_q.subquery())
    )).scalar()
    rows = (await db.execute(
        base_q.order_by(Patient.created_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    items = []
    for patient, user in rows:
        items.append(await _to_response(patient, user, db))

    return PatientListResponse(items=items, total=total)
