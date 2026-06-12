from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import require_patient, require_admin
from app.models.models import User
from app.schemas.patients import PatientResponse, PatientUpdate, PatientListResponse  # noqa: F401 PatientResponse used in list_patients inline construction
from app.services import patient_service

router = APIRouter()


async def _to_response(patient, user, db) -> PatientResponse:
    total_rides = await patient_service.get_patient_total_rides(patient.id, db)
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
    patient = await patient_service.get_patient_by_user(current_user, db)
    return await _to_response(patient, current_user, db)


@router.patch("/me", response_model=PatientResponse)
async def update_me(
    body: PatientUpdate,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await patient_service.get_patient_by_user(current_user, db)
    patient = await patient_service.update_patient(patient, body, db)
    return await _to_response(patient, current_user, db)


@router.get("", response_model=PatientListResponse)
async def list_patients(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    rows, total, ride_counts = await patient_service.list_patients(
        db, page, page_size, search
    )
    items = []
    for patient, user in rows:
        total_rides = ride_counts.get(patient.id, 0)
        items.append(
            PatientResponse(
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
        )
    return PatientListResponse(items=items, total=total)
