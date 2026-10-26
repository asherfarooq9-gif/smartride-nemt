from uuid import UUID
from typing import Optional
from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    BackgroundTasks,
    Query,
    Request,
    Response,
)
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import metrics
from app.core.database import get_db
from app.core.ratelimit import make_limiter
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
    RideDriverInfo,
    RideHospitalInfo,
    RidePatientInfo,
    RideTriageInfo,
)
from app.services import idempotency, ride_service
from app.services.ride_export import rides_csv_chunks

router = APIRouter()
limiter = make_limiter()

# Must match the predicate of the partial unique index
# uq_rides_active_emergency_per_patient (migration 0007).
_ACTIVE_EMERGENCY_STATUSES = (
    RideStatus.pending,
    RideStatus.driver_assigned,
    RideStatus.driver_en_route,
    RideStatus.patient_picked_up,
    RideStatus.arrived_at_hospital,
)
_ACTIVE_EMERGENCY_INDEX = "uq_rides_active_emergency_per_patient"
_EMERGENCY_IDEMPOTENCY_SCOPE = "emergency"
_SCHEDULED_IDEMPOTENCY_SCOPE = "scheduled"


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


async def _find_active_emergency(patient_id, db: AsyncSession) -> Optional[Ride]:
    result = await db.execute(
        select(Ride)
        .where(
            Ride.patient_id == patient_id,
            Ride.ride_type == RideType.emergency,
            Ride.status.in_(_ACTIVE_EMERGENCY_STATUSES),
        )
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _recall_ride(
    scope: str, patient_id, key: str, body_fingerprint: str, db: AsyncSession
) -> Optional[Ride]:
    """The ride this Idempotency-Key already produced; 409 if the body changed."""
    recalled = await idempotency.recall(scope, patient_id, key)
    if recalled is None:
        return None
    ride_id, stored_fingerprint = recalled
    if stored_fingerprint is not None and stored_fingerprint != body_fingerprint:
        raise HTTPException(
            409, "Idempotency-Key was already used with a different request body"
        )
    ride = (
        await db.execute(select(Ride).where(Ride.id == ride_id))
    ).scalar_one_or_none()
    if ride is not None and ride.patient_id == patient_id:
        return ride
    return None


async def _find_replayed_ride(
    patient_id, key: Optional[str], body_fingerprint: str, db: AsyncSession
) -> Optional[Ride]:
    """The ride a repeated request should get back, or None to create a new one."""
    if key:
        ride = await _recall_ride(
            _EMERGENCY_IDEMPOTENCY_SCOPE, patient_id, key, body_fingerprint, db
        )
        if ride is not None:
            return ride
    return await _find_active_emergency(patient_id, db)


@router.post(
    "/emergency",
    response_model=RideResponse,
    status_code=201,
    responses={
        200: {
            "description": (
                "The patient already has a live emergency ride (double tap, retry, "
                "or the same Idempotency-Key): that ride is returned and no new "
                "ride or dispatch is started."
            ),
            "model": RideResponse,
        }
    },
)
@limiter.limit("5/minute")
async def create_emergency_ride(
    request: Request,
    response: Response,
    body: EmergencyRideRequest,
    background_tasks: BackgroundTasks,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    key = idempotency.validate_key(idempotency_key)
    patient = await ride_service.get_patient_by_user(current_user, db)
    patient_id = patient.id  # read before any rollback expires the instance
    body_fingerprint = idempotency.fingerprint(body)

    ride = await _find_replayed_ride(patient_id, key, body_fingerprint, db)
    if ride is None:
        try:
            ride = await ride_service.create_emergency_ride(patient, body, db)
        except IntegrityError as exc:
            # A concurrent request created the patient's emergency ride first.
            await db.rollback()
            if _ACTIVE_EMERGENCY_INDEX not in str(exc.orig):
                raise
            ride = await _find_active_emergency(patient_id, db)
            if ride is None:
                raise HTTPException(409, "Emergency ride already in progress")
        else:
            metrics.rides_created_total.labels(ride_type="emergency").inc()
            background_tasks.add_task(_run_dispatch, str(ride.id), body.symptom_text)
            if key:
                await idempotency.remember(
                    _EMERGENCY_IDEMPOTENCY_SCOPE,
                    patient_id,
                    key,
                    ride.id,
                    body_fingerprint,
                )
            return _to_response(ride)

    response.status_code = 200
    if key:
        await idempotency.remember(
            _EMERGENCY_IDEMPOTENCY_SCOPE, patient_id, key, ride.id, body_fingerprint
        )
    return _to_response(ride)


@router.post(
    "/scheduled",
    response_model=RideResponse,
    status_code=201,
    responses={
        200: {
            "description": (
                "The same Idempotency-Key was already used for this request: the "
                "ride it created is returned and no new ride is made."
            ),
            "model": RideResponse,
        }
    },
)
@limiter.limit("10/minute")
async def create_scheduled_ride(
    request: Request,
    response: Response,
    body: ScheduledRideRequest,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    key = idempotency.validate_key(idempotency_key)
    patient = await ride_service.get_patient_by_user(current_user, db)
    patient_id = patient.id  # read before the commit expires the instance
    body_fingerprint = idempotency.fingerprint(body)

    if key:
        replayed = await _recall_ride(
            _SCHEDULED_IDEMPOTENCY_SCOPE, patient_id, key, body_fingerprint, db
        )
        if replayed is not None:
            response.status_code = 200
            return _to_response(replayed)

    ride = await ride_service.create_scheduled_ride(patient, body, db)
    metrics.rides_created_total.labels(ride_type="scheduled").inc()
    if key:
        await idempotency.remember(
            _SCHEDULED_IDEMPOTENCY_SCOPE, patient_id, key, ride.id, body_fingerprint
        )
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


async def _authorize_ride_access(ride: Ride, user: User, db: AsyncSession) -> str:
    """Return how `user` may see `ride` ("admin", "patient" or "driver"), else 403.

    Uses held_roles (set membership), not the active role, so multi-role accounts
    are checked by their actual relationship to the ride regardless of which
    portal they are in. A dual-role account that owns the ride is the patient;
    one that is driving it falls through to the driver check.
    """
    held = user.held_roles
    if "admin" in held:
        return "admin"
    if "patient" in held:
        patient = await ride_service.get_patient_by_user(user, db)
        if ride.patient_id == patient.id:
            return "patient"
    if "driver" in held:
        driver = await ride_service.get_driver_by_user(user, db)
        if ride.driver_id == driver.id:
            return "driver"
    raise HTTPException(403, "Forbidden")


def _patient_info(ride: Ride, authorized_as: str) -> Optional[RidePatientInfo]:
    if not ride.patient:
        return None
    p = ride.patient
    # The driver needs the patient's number and mobility needs to complete the
    # ride, not afterwards: once it is over, minimum necessary applies.
    if authorized_as == "driver" and ride.status in ride_service.TERMINAL_STATUSES:
        return RidePatientInfo(full_name=p.full_name)
    return RidePatientInfo(
        full_name=p.full_name, phone=p.user.phone, mobility_needs=p.mobility_needs
    )


def _driver_info(ride: Ride) -> Optional[RideDriverInfo]:
    if not ride.driver:
        return None
    d = ride.driver
    return RideDriverInfo(
        full_name=d.full_name,
        phone=d.user.phone,
        vehicle_plate=d.vehicle_plate,
        vehicle_type=d.vehicle_type,
    )


def _hospital_info(ride: Ride) -> Optional[RideHospitalInfo]:
    h = ride.hospital
    if not h:
        return None
    return RideHospitalInfo(name=h.name, address=h.address, city=h.city)


def _triage_info(triage, authorized_as: str) -> Optional[RideTriageInfo]:
    if not triage:
        return None
    # Raw symptom free-text is sensitive PHI. The assigned driver only needs
    # specialty + severity to prepare; the full complaint is shown to the
    # patient (their own data) and admins only - minimum necessary.
    can_see_symptoms = authorized_as in ("patient", "admin")
    return RideTriageInfo(
        predicted_specialty=triage.predicted_specialty.value,
        confidence_score=float(triage.confidence_score),
        severity_level=triage.severity_level.value,
        symptom_text=triage.symptom_text if can_see_symptoms else None,
    )


@router.get("/{ride_id}/detail", response_model=RideDetailResponse)
async def get_ride_detail(
    ride_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_with_relations(ride_id, db)
    authorized_as = await _authorize_ride_access(ride, current_user, db)
    triage = await ride_service.get_triage_for_ride(ride_id, db)

    return RideDetailResponse(
        **_to_response(ride).model_dump(),
        patient=_patient_info(ride, authorized_as),
        driver=_driver_info(ride),
        hospital=_hospital_info(ride),
        triage=_triage_info(triage, authorized_as),
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
    ride_id: UUID,
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
    ride_id: UUID,
    body: RateRideRequest,
    current_user: User = Depends(require_patient),
    db: AsyncSession = Depends(get_db),
):
    patient = await ride_service.get_patient_by_user(current_user, db)
    ride = await ride_service.rate_completed_ride(
        db, ride_id, patient.id, body.rating, body.comment
    )
    return _to_response(ride)


@router.patch("/{ride_id}/status", response_model=RideResponse)
async def update_ride_status(
    ride_id: UUID,
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
):
    # No get_db here: the streamed body runs after the request-scoped session may
    # be closed, so the generator opens its own.
    return StreamingResponse(
        rides_csv_chunks(status, ride_type, search),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=rides.csv"},
    )


@router.get("/{ride_id}", response_model=RideResponse)
async def get_ride(
    ride_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ride = await ride_service.get_ride_by_id(ride_id, db)
    await _authorize_ride_access(ride, current_user, db)
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
