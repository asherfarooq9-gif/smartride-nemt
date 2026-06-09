import csv
import io
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user, require_patient, require_driver, require_admin
from app.models.models import Ride, Patient, Driver, User, RideStatus, RideType
from app.schemas.rides import (
    EmergencyRideRequest, ScheduledRideRequest,
    RideStatusUpdate, RateRideRequest, RideResponse, RideListResponse, RideDetailResponse,
)
from app.services import ride_service

router = APIRouter()


def _to_response(ride: Ride) -> RideResponse:
    return RideResponse.model_validate(ride)


async def _run_dispatch(ride_id: str, symptom_text: str) -> None:
    import logging
    from app.core.database import AsyncSessionLocal
    from app.services.emergency_dispatch import dispatch_emergency
    from sqlalchemy import select

    log = logging.getLogger("smartride.dispatch")
    try:
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(Ride).where(Ride.id == ride_id))
            ride = result.scalar_one_or_none()
            if ride is None:
                log.warning("dispatch skipped: ride %s not found", ride_id)
                return
            await dispatch_emergency(ride, symptom_text, db)
    except Exception:
        # Background tasks have no caller to surface errors to — log loudly so a
        # failed dispatch (e.g. triage service down) is visible, not silent.
        log.exception("emergency dispatch failed for ride %s", ride_id)


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

    # Use held_roles (set membership) not active role so multi-role accounts
    # are checked correctly regardless of which portal they are currently in.
    if "admin" not in current_user.held_roles:
        if "patient" in current_user.held_roles:
            patient = await ride_service.get_patient_by_user(current_user, db)
            if ride.patient_id != patient.id:
                raise HTTPException(403, "Forbidden")
        elif "driver" in current_user.held_roles:
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


# ── Driver endpoints ──────────────────────────────────────────────────────────
# IMPORTANT: /pending must be registered BEFORE /{ride_id} so FastAPI does not
# treat the literal string "pending" as a ride_id parameter.

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


@router.post("/{ride_id}/rate", response_model=RideResponse)
async def rate_ride(
    ride_id: str,
    body: RateRideRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.get_ride_by_id(ride_id, db)
    if ride.patient_id != patient.id:
        raise HTTPException(403, "Forbidden")
    if ride.status != RideStatus.completed:
        raise HTTPException(400, "Can only rate completed rides")
    if ride.patient_rating is not None:
        raise HTTPException(409, "Ride already rated")
    ride.patient_rating = body.rating
    ride.rating_comment = body.comment
    await db.commit()
    await db.refresh(ride)
    return _to_response(ride)


@router.patch("/{ride_id}/status", response_model=RideResponse)
async def update_ride_status(
    ride_id: str,
    body: RideStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_by_id(ride_id, db)
    role = next(
        (r for r in ("patient", "driver", "admin") if r in current_user.held_roles),
        current_user.role.value,
    )

    patient = await ride_service.get_patient_by_user(current_user, db) if role == "patient" else None
    driver = await ride_service.get_driver_by_user(current_user, db) if role == "driver" else None

    if driver and not driver.is_verified:
        raise HTTPException(403, "Driver not verified")

    ride = await ride_service.update_ride_status(ride, body, role, db, patient=patient, driver=driver)
    return _to_response(ride)


@router.get("/{ride_id}", response_model=RideResponse)
async def get_ride(
    ride_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_by_id(ride_id, db)
    if "admin" not in current_user.held_roles:
        if "patient" in current_user.held_roles:
            patient = await ride_service.get_patient_by_user(current_user, db)
            if ride.patient_id != patient.id:
                raise HTTPException(403, "Forbidden")
        elif "driver" in current_user.held_roles:
            driver = await ride_service.get_driver_by_user(current_user, db)
            if ride.driver_id != driver.id:
                raise HTTPException(403, "Forbidden")
    return _to_response(ride)


# ── Admin endpoints ───────────────────────────────────────────────────────────

@router.get("/export.csv")
async def export_rides_csv(
    status: Optional[RideStatus] = Query(None),
    ride_type: Optional[RideType] = Query(None),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    rows, _ = await ride_service.list_rides_admin(db, 1, 10_000, status, ride_type, search)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "id", "ride_type", "status", "pickup_address",
        "requested_at", "completed_at", "cancelled_at",
        "estimated_fare_pkr", "final_fare_pkr",
        "patient_id", "driver_id", "hospital_id",
    ])
    for r in rows:
        writer.writerow([
            str(r.id), r.ride_type.value, r.status.value,
            r.pickup_address or "",
            r.requested_at.isoformat() if r.requested_at else "",
            r.completed_at.isoformat() if r.completed_at else "",
            r.cancelled_at.isoformat() if r.cancelled_at else "",
            float(r.estimated_fare_pkr) if r.estimated_fare_pkr else "",
            float(r.final_fare_pkr) if r.final_fare_pkr else "",
            str(r.patient_id), str(r.driver_id) if r.driver_id else "",
            str(r.hospital_id) if r.hospital_id else "",
        ])
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=rides.csv"},
    )


@router.get("", response_model=RideListResponse)
async def list_rides(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: Optional[RideStatus] = Query(None),
    ride_type: Optional[RideType] = Query(None),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    rows, total = await ride_service.list_rides_admin(db, page, page_size, status, ride_type, search)
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)
