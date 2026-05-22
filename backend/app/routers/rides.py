from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.core.database import get_db
from app.core.security import get_current_user, require_patient, require_driver, require_admin
from app.models.models import (
    Ride, Patient, Driver, User, Hospital, TriageEvent,
    RideType, RideStatus, DriverStatus,
)
from app.schemas.rides import (
    EmergencyRideRequest, ScheduledRideRequest,
    RideStatusUpdate, RideResponse, RideListResponse, RideDetailResponse,
)

router = APIRouter()

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


@router.get("/{ride_id}/detail", response_model=RideDetailResponse)
async def get_ride_detail(
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
        patient_rec = await _get_patient(current_user, db)
        if ride.patient_id != patient_rec.id:
            raise HTTPException(403, "Forbidden")
    elif role == "driver":
        driver_rec = await _get_driver(current_user, db)
        if ride.driver_id != driver_rec.id:
            raise HTTPException(403, "Forbidden")

    # Load related records
    patient_data = None
    if ride.patient_id:
        pr = await db.execute(
            select(Patient, User).join(User, Patient.user_id == User.id).where(Patient.id == ride.patient_id)
        )
        row = pr.one_or_none()
        if row:
            p, u = row
            patient_data = {"full_name": p.full_name, "phone": u.phone, "mobility_needs": p.mobility_needs}

    driver_data = None
    if ride.driver_id:
        dr = await db.execute(
            select(Driver, User).join(User, Driver.user_id == User.id).where(Driver.id == ride.driver_id)
        )
        row = dr.one_or_none()
        if row:
            d, u = row
            driver_data = {"full_name": d.full_name, "phone": u.phone, "vehicle_plate": d.vehicle_plate, "vehicle_type": d.vehicle_type}

    hospital_data = None
    if ride.hospital_id:
        hr = await db.execute(select(Hospital).where(Hospital.id == ride.hospital_id))
        h = hr.scalar_one_or_none()
        if h:
            hospital_data = {"name": h.name, "address": h.address, "city": h.city}

    triage_data = None
    tr = await db.execute(select(TriageEvent).where(TriageEvent.ride_id == ride.id).order_by(TriageEvent.created_at.desc()).limit(1))
    t = tr.scalar_one_or_none()
    if t:
        triage_data = {
            "symptom_text": t.symptom_text,
            "predicted_specialty": t.predicted_specialty.value,
            "confidence_score": float(t.confidence_score),
            "severity_level": t.severity_level.value,
        }

    base = _to_response(ride)
    return RideDetailResponse(
        **base.model_dump(),
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

    return _to_response(ride)


# ── Driver endpoints ──────────────────────────────────────────────────────────

@router.patch("/{ride_id}/status", response_model=RideResponse)
async def update_ride_status(
    ride_id: str,
    body: RideStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Ride).where(Ride.id == ride_id))
    ride = result.scalar_one_or_none()
    if not ride:
        raise HTTPException(404, "Ride not found")

    role = current_user.role.value
    new_status = body.status

    if role == "driver":
        driver = await _get_driver(current_user, db)
        if ride.driver_id != driver.id:
            raise HTTPException(403, "Not your ride")
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
    elif role == "admin":
        # Admin can only cancel
        if new_status != RideStatus.cancelled:
            raise HTTPException(400, "Admin can only cancel rides")
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
        ride.cancel_reason = "Cancelled by admin"
    elif role == "patient":
        patient = await _get_patient(current_user, db)
        if ride.patient_id != patient.id:
            raise HTTPException(403, "Not your ride")
        if new_status != RideStatus.cancelled:
            raise HTTPException(400, "Patient can only cancel rides")
        if ride.status not in (RideStatus.pending, RideStatus.driver_assigned):
            raise HTTPException(400, "Cannot cancel ride in current state")
        ride.status = RideStatus.cancelled
        ride.cancelled_at = datetime.now(timezone.utc)
        ride.cancel_reason = body.cancel_reason or "Cancelled by patient"
    else:
        raise HTTPException(403, "Forbidden")

    await db.commit()
    await db.refresh(ride)
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
    conditions = []
    if status:
        try:
            conditions.append(Ride.status == RideStatus(status))
        except ValueError:
            pass
    if ride_type:
        try:
            conditions.append(Ride.ride_type == RideType(ride_type))
        except ValueError:
            pass
    if search:
        conditions.append(Ride.pickup_address.ilike(f"%{search}%"))

    base_q = select(Ride)
    if conditions:
        from sqlalchemy import and_
        base_q = base_q.where(and_(*conditions))

    total = (await db.execute(select(func.count()).select_from(base_q.subquery()))).scalar()
    rows = (await db.execute(
        base_q.order_by(Ride.requested_at.desc())
        .offset((page - 1) * page_size).limit(page_size)
    )).scalars().all()
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)
