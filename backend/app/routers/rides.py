from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user, require_patient, require_driver, require_admin
from app.models.models import Ride, Patient, Driver, User
from app.schemas.rides import (
    EmergencyRideRequest, ScheduledRideRequest,
    RideStatusUpdate, RideResponse, RideListResponse, RideDetailResponse,
)
from app.services import ride_service

router = APIRouter()


def _to_response(ride: Ride) -> RideResponse:
    return RideResponse(
        id=str(ride.id),
        patient_id=str(ride.patient_id),
        driver_id=str(ride.driver_id) if ride.driver_id else None,
        hospital_id=str(ride.hospital_id) if ride.hospital_id else None,
        ride_type=ride.ride_type,
        status=ride.status,
        pickup_lat=ride.pickup_lat,
        pickup_lng=ride.pickup_lng,
        pickup_address=ride.pickup_address,
        scheduled_for=ride.scheduled_for,
        requested_at=ride.requested_at,
        driver_assigned_at=ride.driver_assigned_at,
        pickup_at=ride.pickup_at,
        arrived_at=ride.arrived_at,
        completed_at=ride.completed_at,
        cancelled_at=ride.cancelled_at,
        cancel_reason=ride.cancel_reason,
        estimated_fare_pkr=float(ride.estimated_fare_pkr) if ride.estimated_fare_pkr else None,
        final_fare_pkr=float(ride.final_fare_pkr) if ride.final_fare_pkr else None,
    )


async def _run_dispatch(ride_id: str, symptom_text: str) -> None:
    from app.core.database import AsyncSessionLocal
    from app.services.emergency_dispatch import dispatch_emergency
    from sqlalchemy import select

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Ride).where(Ride.id == ride_id))
        ride = result.scalar_one_or_none()
        if ride:
            await dispatch_emergency(ride, symptom_text, db)


# ── Patient endpoints ─────────────────────────────────────────────────────────

@router.post("/emergency", response_model=RideResponse, status_code=201)
async def create_emergency_ride(
    body: EmergencyRideRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.create_emergency_ride(patient, body, db)
    background_tasks.add_task(_run_dispatch, str(ride.id), body.symptom_text)
    return _to_response(ride)


@router.post("/scheduled", response_model=RideResponse, status_code=201)
async def create_scheduled_ride(
    body: ScheduledRideRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.create_scheduled_ride(patient, body, db)
    return _to_response(ride)


@router.get("/mine", response_model=RideListResponse)
async def my_rides(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rows, total = await ride_service.get_my_rides(current_user, db, page, page_size)
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)


@router.get("/{ride_id}/detail", response_model=RideDetailResponse)
async def get_ride_detail(
    ride_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_with_relations(ride_id, db)

    role = current_user.role.value
    if role == "patient":
        patient = await ride_service.get_patient_by_user(current_user, db)
        if ride.patient_id != patient.id:
            raise HTTPException(403, "Forbidden")
    elif role == "driver":
        driver = await ride_service.get_driver_by_user(current_user, db)
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Forbidden")

    patient_data = None
    if ride.patient:
        p, u = ride.patient, ride.patient.user
        patient_data = {"full_name": p.full_name, "phone": u.phone, "mobility_needs": p.mobility_needs}

    driver_data = None
    if ride.driver:
        d, u = ride.driver, ride.driver.user
        driver_data = {"full_name": d.full_name, "phone": u.phone, "vehicle_plate": d.vehicle_plate, "vehicle_type": d.vehicle_type}

    hospital_data = None
    if ride.hospital:
        h = ride.hospital
        hospital_data = {"name": h.name, "address": h.address, "city": h.city}

    triage_data = None
    t = await ride_service.get_triage_for_ride(ride_id, db)
    if t:
        triage_data = {
            "symptom_text": t.symptom_text,
            "predicted_specialty": t.predicted_specialty.value,
            "confidence_score": float(t.confidence_score),
            "severity_level": t.severity_level.value,
        }

    return RideDetailResponse(
        **_to_response(ride).model_dump(),
        patient=patient_data,
        driver=driver_data,
        hospital=hospital_data,
        triage=triage_data,
    )


@router.get("/{ride_id}", response_model=RideResponse)
async def get_ride(
    ride_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_by_id(ride_id, db)

    role = current_user.role.value
    if role == "patient":
        patient = await ride_service.get_patient_by_user(current_user, db)
        if ride.patient_id != patient.id:
            raise HTTPException(403, "Forbidden")
    elif role == "driver":
        driver = await ride_service.get_driver_by_user(current_user, db)
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Forbidden")

    return _to_response(ride)


# ── Driver endpoints ──────────────────────────────────────────────────────────

@router.get("/pending", response_model=RideListResponse)
async def pending_rides(
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await ride_service.get_driver_by_user(current_user, db)
    if not driver.is_verified:
        raise HTTPException(403, "Driver not verified")
    rides = await ride_service.get_pending_rides(driver, db)
    return RideListResponse(items=[_to_response(r) for r in rides], total=len(rides))


@router.post("/{ride_id}/accept", response_model=RideResponse)
async def accept_ride(
    ride_id: str,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await ride_service.get_driver_by_user(current_user, db)
    if not driver.is_verified:
        raise HTTPException(403, "Driver not verified")
    ride = await ride_service.accept_ride(ride_id, driver, db)
    return _to_response(ride)


@router.patch("/{ride_id}/status", response_model=RideResponse)
async def update_ride_status(
    ride_id: str,
    body: RideStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_by_id(ride_id, db)
    role = current_user.role.value

    patient = await ride_service.get_patient_by_user(current_user, db) if role == "patient" else None
    driver = await ride_service.get_driver_by_user(current_user, db) if role == "driver" else None

    if driver and not driver.is_verified:
        raise HTTPException(403, "Driver not verified")

    ride = await ride_service.update_ride_status(ride, body, role, db, patient=patient, driver=driver)
    return _to_response(ride)


# ── Admin endpoints ───────────────────────────────────────────────────────────

@router.get("", response_model=RideListResponse)
async def list_rides(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None),
    ride_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    rows, total = await ride_service.list_rides_admin(db, page, page_size, status, ride_type, search)
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)
