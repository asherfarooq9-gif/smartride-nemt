from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.security import get_current_user, require_patient, require_driver, require_admin
from app.models.models import (
    Ride, Patient, Driver, User, RideType, RideStatus, DriverStatus,
)
from app.schemas.rides import (
    EmergencyRideRequest, ScheduledRideRequest,
    RideStatusUpdate, RideResponse, RideListResponse,
)

router = APIRouter()

# Status transitions allowed per driver action
DRIVER_TRANSITIONS = {
    RideStatus.driver_assigned: RideStatus.driver_en_route,
    RideStatus.driver_en_route: RideStatus.patient_picked_up,
    RideStatus.patient_picked_up: RideStatus.arrived_at_hospital,
    RideStatus.arrived_at_hospital: RideStatus.completed,
}


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


async def _get_patient(user: User, db: AsyncSession) -> Patient:
    result = await db.execute(select(Patient).where(Patient.user_id == user.id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Patient profile not found")
    return p


async def _get_driver(user: User, db: AsyncSession) -> Driver:
    result = await db.execute(select(Driver).where(Driver.user_id == user.id))
    d = result.scalar_one_or_none()
    if not d:
        raise HTTPException(404, "Driver profile not found")
    return d


async def _run_dispatch(ride_id: str, symptom_text: str) -> None:
    """Background task — uses its own DB session so request session can close."""
    from app.core.database import AsyncSessionLocal
    from app.services.emergency_dispatch import dispatch_emergency

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
    patient = await _get_patient(current_user, db)
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.emergency,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
    )
    db.add(ride)
    await db.commit()
    await db.refresh(ride)
    background_tasks.add_task(_run_dispatch, str(ride.id), body.symptom_text)
    return _to_response(ride)


@router.post("/scheduled", response_model=RideResponse, status_code=201)
async def create_scheduled_ride(
    body: ScheduledRideRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await _get_patient(current_user, db)
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.scheduled,
        status=RideStatus.pending,
        pickup_lat=body.pickup_lat,
        pickup_lng=body.pickup_lng,
        pickup_address=body.pickup_address,
        scheduled_for=body.scheduled_for,
    )
    db.add(ride)
    await db.commit()
    await db.refresh(ride)
    return _to_response(ride)


@router.get("/mine", response_model=RideListResponse)
async def my_rides(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role.value == "patient":
        patient = await _get_patient(current_user, db)
        condition = Ride.patient_id == patient.id
    else:
        driver = await _get_driver(current_user, db)
        condition = Ride.driver_id == driver.id

    total = (await db.execute(select(func.count()).select_from(Ride).where(condition))).scalar()
    rows = (await db.execute(
        select(Ride).where(condition)
        .order_by(Ride.requested_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).scalars().all()
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)


@router.get("/{ride_id}", response_model=RideResponse)
async def get_ride(
    ride_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Ride).where(Ride.id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(404, "Ride not found")

    role = current_user.role.value
    if role == "patient":
        patient = await _get_patient(current_user, db)
        if ride.patient_id != patient.id:
            raise HTTPException(403, "Forbidden")
    elif role == "driver":
        driver = await _get_driver(current_user, db)
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Forbidden")
    # admin sees all

    return _to_response(ride)


# ── Driver endpoints ──────────────────────────────────────────────────────────

@router.patch("/{ride_id}/status", response_model=RideResponse)
async def update_ride_status(
    ride_id: str,
    body: RideStatusUpdate,
    current_user: User = Depends(require_driver),
    db: AsyncSession = Depends(get_db),
):
    driver = await _get_driver(current_user, db)
    result = await db.execute(select(Ride).where(Ride.id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(404, "Ride not found")
    if ride.driver_id != driver.id:
        raise HTTPException(403, "Not your ride")

    new_status = body.status
    allowed_next = DRIVER_TRANSITIONS.get(ride.status)
    if new_status == RideStatus.cancelled:
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
    elif new_status != allowed_next:
        raise HTTPException(400, f"Cannot transition from {ride.status} to {new_status}")
    else:
        ride.status = new_status
        now = datetime.now(timezone.utc)
        if new_status == RideStatus.patient_picked_up:
            ride.pickup_at = now
        elif new_status == RideStatus.arrived_at_hospital:
            ride.arrived_at = now
        elif new_status == RideStatus.completed:
            ride.completed_at = now
            driver.status = DriverStatus.available

    await db.commit()
    await db.refresh(ride)
    return _to_response(ride)


# ── Admin endpoints ───────────────────────────────────────────────────────────

@router.get("", response_model=RideListResponse)
async def list_rides(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    total = (await db.execute(select(func.count()).select_from(Ride))).scalar()
    rows = (await db.execute(
        select(Ride).order_by(Ride.requested_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).scalars().all()
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)
