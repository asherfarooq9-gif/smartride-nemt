import csv
import io
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query, Request
from fastapi.responses import StreamingResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import metrics
from app.core.database import get_db
from app.core.security import (
    get_current_user,
    require_patient,
    require_driver,
    require_admin,
)
from app.models.models import Ride, User, RideStatus, RideType
from app.schemas.rides import (
    EmergencyRideRequest,
    ScheduledRideRequest,
    RideStatusUpdate,
    RateRideRequest,
    RideResponse,
    RideListResponse,
    RideDetailResponse,
)
from app.services import ride_service

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


def _to_response(ride: Ride) -> RideResponse:
    resp = RideResponse.model_validate(ride)
    # Only read the relation when it was eagerly loaded — touching a lazy
    # relation here would raise under the async session.
    hospital = ride.__dict__.get("hospital")
    if hospital is not None:
        resp.hospital_name = hospital.name
    return resp


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
@limiter.limit("5/minute")
async def create_emergency_ride(
    request: Request,
    body: EmergencyRideRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.create_emergency_ride(patient, body, db)
    metrics.rides_created_total.labels(ride_type="emergency").inc()
    background_tasks.add_task(_run_dispatch, str(ride.id), body.symptom_text)
    return _to_response(ride)


@router.post("/scheduled", response_model=RideResponse, status_code=201)
@limiter.limit("10/minute")
async def create_scheduled_ride(
    request: Request,
    body: ScheduledRideRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.create_scheduled_ride(patient, body, db)
    metrics.rides_created_total.labels(ride_type="scheduled").inc()
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
    # Track *how* the caller is authorized so we can scope PHI in the response:
    # a dual-role account that owns the ride is treated as the patient, not
    # merely the assigned driver.
    held = current_user.held_roles
    authorized_as = None
    if "admin" in held:
        authorized_as = "admin"
    else:
        if "patient" in held:
            patient = await ride_service.get_patient_by_user(current_user, db)
            if patient and ride.patient_id == patient.id:
                authorized_as = "patient"
        if authorized_as is None and "driver" in held:
            driver = await ride_service.get_driver_by_user(current_user, db)
            if driver and ride.driver_id == driver.id:
                authorized_as = "driver"
        if authorized_as is None:
            raise HTTPException(403, "Forbidden")

    patient_data = None
    if ride.patient:
        p, u = ride.patient, ride.patient.user
        patient_data = {
            "full_name": p.full_name,
            "phone": u.phone,
            "mobility_needs": p.mobility_needs,
        }

    driver_data = None
    if ride.driver:
        d, u = ride.driver, ride.driver.user
        driver_data = {
            "full_name": d.full_name,
            "phone": u.phone,
            "vehicle_plate": d.vehicle_plate,
            "vehicle_type": d.vehicle_type,
        }

    hospital_data = None
    if ride.hospital:
        h = ride.hospital
        hospital_data = {"name": h.name, "address": h.address, "city": h.city}

    triage_data = None
    t = await ride_service.get_triage_for_ride(ride_id, db)
    if t:
        triage_data = {
            "predicted_specialty": t.predicted_specialty.value,
            "confidence_score": float(t.confidence_score),
            "severity_level": t.severity_level.value,
        }
        # Raw symptom free-text is sensitive PHI. The assigned driver only
        # needs specialty + severity to prepare; the full complaint is shown
        # to the patient (their own data) and admins only — minimum necessary.
        if authorized_as in ("patient", "admin"):
            triage_data["symptom_text"] = t.symptom_text

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
    metrics.rides_accepted_total.inc()
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

    # Authorize by held_roles and actual relationship to the ride, not the
    # active portal — a multi-role account must act as whichever role owns
    # this ride, and must never touch rides that belong to someone else.
    held = current_user.held_roles

    if "admin" in held:
        ride = await ride_service.update_ride_status(ride, body, "admin", db)
        return _to_response(ride)

    if "driver" in held:
        driver = await ride_service.get_driver_by_user(current_user, db)
        if ride.driver_id == driver.id:
            if not driver.is_verified:
                raise HTTPException(403, "Driver not verified")
            ride = await ride_service.update_ride_status(
                ride, body, "driver", db, driver=driver
            )
            return _to_response(ride)

    if "patient" in held:
        patient = await ride_service.get_patient_by_user(current_user, db)
        if ride.patient_id == patient.id:
            ride = await ride_service.update_ride_status(
                ride, body, "patient", db, patient=patient
            )
            return _to_response(ride)

    raise HTTPException(403, "Forbidden")


# ── Admin endpoints ───────────────────────────────────────────────────────────
# NOTE: /export.csv must be registered BEFORE /{ride_id} to prevent route shadowing.


@router.get("/export.csv")
async def export_rides_csv(
    status: Optional[RideStatus] = Query(None),
    ride_type: Optional[RideType] = Query(None),
    search: Optional[str] = Query(None),
    _admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    async def generate_csv():
        # Stream page by page so we never hold the full export in memory.
        page, page_size = 1, 500
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(
            [
                "id",
                "ride_type",
                "status",
                "pickup_address",
                "requested_at",
                "completed_at",
                "cancelled_at",
                "estimated_fare_pkr",
                "final_fare_pkr",
                "patient_id",
                "driver_id",
                "hospital_id",
            ]
        )
        yield buf.getvalue()
        while True:
            rows, _ = await ride_service.list_rides_admin(
                db, page, page_size, status, ride_type, search
            )
            if not rows:
                break
            buf = io.StringIO()
            writer = csv.writer(buf)
            for r in rows:
                writer.writerow(
                    [
                        str(r.id),
                        r.ride_type.value,
                        r.status.value,
                        r.pickup_address or "",
                        r.requested_at.isoformat() if r.requested_at else "",
                        r.completed_at.isoformat() if r.completed_at else "",
                        r.cancelled_at.isoformat() if r.cancelled_at else "",
                        float(r.estimated_fare_pkr) if r.estimated_fare_pkr else "",
                        float(r.final_fare_pkr) if r.final_fare_pkr else "",
                        str(r.patient_id),
                        str(r.driver_id) if r.driver_id else "",
                        str(r.hospital_id) if r.hospital_id else "",
                    ]
                )
            yield buf.getvalue()
            if len(rows) < page_size:
                break
            page += 1

    return StreamingResponse(
        generate_csv(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=rides.csv"},
    )


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
    rows, total = await ride_service.list_rides_admin(
        db, page, page_size, status, ride_type, search
    )
    return RideListResponse(items=[_to_response(r) for r in rows], total=total)
