from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.security import require_patient
from app.models.models import Patient, User
from app.schemas.patients import PatientResponse, PatientUpdate

router = APIRouter()


async def _get_patient_for_user(user: User, db: AsyncSession) -> Patient:
    result = await db.execute(select(Patient).where(Patient.user_id == user.id))
    patient = result.scalar_one_or_none()
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    return patient


def _to_response(patient: Patient, user: User) -> PatientResponse:
    return PatientResponse(
        id=str(patient.id),
        phone=user.phone,
        full_name=patient.full_name,
        date_of_birth=patient.date_of_birth,
        mobility_needs=patient.mobility_needs,
        emergency_contact_name=patient.emergency_contact_name,
        emergency_contact_phone=patient.emergency_contact_phone,
        created_at=patient.created_at,
    )


@router.get("/me", response_model=PatientResponse)
async def get_me(
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await _get_patient_for_user(current_user, db)
    return _to_response(patient, current_user)


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
    return _to_response(patient, current_user)
