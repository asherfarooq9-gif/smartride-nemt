"""
Emergency Dispatch Service
Orchestrates: triage → hospital matching → driver dispatch → family SMS → hospital pre-alert
Target: entire pipeline < 60 seconds

Network calls (triage, SMS, FHIR) never run inside an open database transaction:
the ride, patient and hospitals are copied into plain data first, the transaction
is closed, and only then does the pipeline talk to the outside world.
"""

import asyncio
import logging
import math
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core import metrics
from app.models.models import (
    Driver,
    DriverStatus,
    Hospital,
    Patient,
    Ride,
    RideStatus,
    SeverityLevel,
    Specialty,
    TriageEvent,
)
from app.services.fare import fare_for
from app.services.hospital_matching import (
    HospitalCandidate,
    MatchResult,
    haversine_km,
    match_hospitals,
)
from app.services.notifications import (
    notify_user,
    send_family_sms,
    send_hospital_alert,
)
from app.services.triage_keywords import (
    KEYWORDS_VERSION,
    compute_severity,
    detect_severity_override,
    infer_specialty,
)

log = logging.getLogger("smartride.dispatch")

CANDIDATE_LIMIT = 200
# A driver whose last location report is older than this is treated as gone
# (app killed, no signal): dispatching to them wastes the patient's minutes.
DRIVER_FRESH_SECONDS = 120
TRIAGE_TIMEOUT_SECONDS = 10.0
# Unusable severity is escalated, never downgraded: over-triage costs a faster
# ambulance, under-triage costs a life.
FAIL_SAFE_SEVERITY = SeverityLevel.five.value
FAIL_SAFE_SPECIALTY = Specialty.general_emergency.value

_VALID_SEVERITIES = frozenset(s.value for s in SeverityLevel)
_VALID_SPECIALTIES = frozenset(s.value for s in Specialty)

# reason -> (caller-facing message, log level)
_FAILURES = {
    "no_hospital": ("No hospitals available in range", logging.ERROR),
    "no_driver": ("No drivers available. Retrying in 30s.", logging.WARNING),
    "ride_not_pending": ("Ride is no longer pending", logging.INFO),
}


# ── plain-data snapshots (safe to use after the session's transaction ends) ───


@dataclass(frozen=True)
class RideInfo:
    id: uuid.UUID
    patient_id: uuid.UUID
    pickup_lat: float
    pickup_lng: float
    pickup_address: Optional[str]
    symptom_text: str


@dataclass(frozen=True)
class PatientInfo:
    id: uuid.UUID
    user_id: uuid.UUID
    full_name: str
    emergency_contact_phone: Optional[str]


@dataclass(frozen=True)
class DriverInfo:
    id: uuid.UUID
    user_id: uuid.UUID
    full_name: str
    vehicle_plate: str


def _snapshot_ride(ride: Ride, symptom_text: str) -> RideInfo:
    # The text saved with the ride wins: it is the patient's own words, and the
    # retry loop must not replace it with a placeholder.
    return RideInfo(
        id=ride.id,
        patient_id=ride.patient_id,
        pickup_lat=ride.pickup_lat,
        pickup_lng=ride.pickup_lng,
        pickup_address=ride.pickup_address,
        symptom_text=ride.symptom_text or symptom_text,
    )


# ── triage ────────────────────────────────────────────────────────────────────


class TriageServiceResponse(BaseModel):
    """Shape the triage service must return; anything else is treated as down."""

    specialty: str
    severity: str | int
    confidence: float = 0.0
    rule_override: bool = False
    model_version: str = "unknown"
    inference_ms: int | None = None


def fallback_triage(symptom_text: str) -> dict:
    """Local rules (the vendored copy of the triage service's own)."""
    severity, rule_override = compute_severity(symptom_text)
    specialty, confidence = infer_specialty(symptom_text)
    return {
        "specialty": specialty,
        "confidence": confidence,
        "severity": severity,
        "rule_override": rule_override,
        "model_version": f"fallback-rules-{KEYWORDS_VERSION[:12]}",
    }


async def call_triage_service(symptom_text: str, ride_id=None) -> dict:
    """Call the AI triage microservice; fall back to local rules if it is unusable."""
    try:
        async with httpx.AsyncClient(timeout=TRIAGE_TIMEOUT_SECONDS) as client:
            resp = await client.post(
                f"{settings.TRIAGE_SERVICE_URL}/triage",
                json={"text": symptom_text},
            )
            resp.raise_for_status()
            return TriageServiceResponse.model_validate(resp.json()).model_dump()
    except (httpx.HTTPError, ValueError) as exc:  # ValueError covers bad JSON/shape
        # Exception type only: the message text can echo the symptom text (PHI).
        log.warning(
            "triage service unusable ride_id=%s (%s); using local rules",
            ride_id,
            type(exc).__name__,
        )
        metrics.dispatch_failures_total.labels(reason="triage_fallback").inc()
        return fallback_triage(symptom_text)


def _clamp_confidence(value) -> float:
    try:
        confidence = float(value)
    except (TypeError, ValueError):
        return 0.0
    return confidence if 0.0 <= confidence <= 1.0 else 0.0


def _note_keyword_mismatch(model_version) -> None:
    """The service stamps its keyword hash into model_version. If it differs from
    ours the two are scoring with different rules; the vendored copy is only
    compared in CI, so say so at runtime too."""
    if not isinstance(model_version, str) or not model_version.startswith("rules-v"):
        return
    if model_version.rsplit("-", 1)[-1] != KEYWORDS_VERSION[:8]:
        metrics.dispatch_failures_total.labels(reason="triage_keywords_mismatch").inc()
        log.warning(
            "triage service keyword version differs from the backend copy (%s)",
            model_version,
        )


def normalise_triage(raw: dict, symptom_text: str) -> dict:
    """The one place triage output is made safe; everything downstream uses this."""
    severity = str(raw.get("severity", "")).strip()
    if severity not in _VALID_SEVERITIES:
        severity = FAIL_SAFE_SEVERITY
    specialty = raw.get("specialty")
    if not isinstance(specialty, str) or specialty not in _VALID_SPECIALTIES:
        specialty = FAIL_SAFE_SPECIALTY
    rule_override = bool(raw.get("rule_override"))
    # The service may only raise severity. A stale, buggy or tampered one that says
    # "2" for a text our own rules score higher must not lower it.
    local_severity, _ = compute_severity(symptom_text)
    if int(local_severity) > int(severity):
        severity = local_severity
    if detect_severity_override(symptom_text):
        severity, rule_override = FAIL_SAFE_SEVERITY, True
    _note_keyword_mismatch(raw.get("model_version"))
    inference_ms = raw.get("inference_ms")
    return {
        "specialty": specialty,
        "severity": severity,
        "confidence": _clamp_confidence(raw.get("confidence")),
        "rule_override": rule_override,
        "model_version": str(raw.get("model_version") or "unknown")[:50],
        "inference_ms": inference_ms if isinstance(inference_ms, int) else None,
    }


async def load_stored_triage(db: AsyncSession, ride_id) -> Optional[dict]:
    row = (
        await db.execute(
            select(
                TriageEvent.predicted_specialty,
                TriageEvent.severity_level,
                TriageEvent.confidence_score,
                TriageEvent.rule_override,
                TriageEvent.model_version,
                TriageEvent.inference_ms,
            )
            .where(TriageEvent.ride_id == ride_id)
            .order_by(TriageEvent.created_at)
            .limit(1)
        )
    ).first()
    if row is None:
        return None
    return {
        "specialty": row.predicted_specialty.value,
        "severity": row.severity_level.value,
        "confidence": float(row.confidence_score),
        "rule_override": bool(row.rule_override),
        "model_version": row.model_version,
        "inference_ms": row.inference_ms,
    }


async def record_triage(
    db: AsyncSession, ride_id, symptom_text: str, triage: dict
) -> dict:
    """Store `triage` unless the ride already has a result; return what is stored.

    The unique key on ride_id makes the insert race-free, so two dispatches (or a
    retry) can never pile up rows, and the caller always acts on the stored row.
    """
    await db.execute(
        pg_insert(TriageEvent)
        .values(
            ride_id=ride_id,
            symptom_text=symptom_text,
            predicted_specialty=Specialty(triage["specialty"]),
            confidence_score=triage["confidence"],
            severity_level=SeverityLevel(triage["severity"]),
            rule_override=triage["rule_override"],
            model_version=triage["model_version"],
            inference_ms=triage["inference_ms"],
        )
        .on_conflict_do_nothing(constraint="uq_triage_events_ride_id")
    )
    stored = await load_stored_triage(db, ride_id)
    await db.commit()
    return stored or triage


async def _triage_and_record(db: AsyncSession, ride: RideInfo) -> dict:
    raw = await call_triage_service(ride.symptom_text, ride_id=ride.id)
    triage = normalise_triage(raw, ride.symptom_text)
    return await record_triage(db, ride.id, ride.symptom_text, triage)


# ── drivers ───────────────────────────────────────────────────────────────────


async def find_available_drivers_by_distance(
    db: AsyncSession, patient_lat: float, patient_lng: float
) -> list[Driver]:
    """Available, verified, recently-seen drivers from the DB, nearest first."""
    # Bounding box in SQL first, so a large fleet is never loaded into Python.
    dlat = settings.DRIVER_SEARCH_RADIUS_KM / 111.0
    dlng = dlat / max(math.cos(math.radians(patient_lat)), 0.01)
    fresh_since = datetime.now(timezone.utc) - timedelta(seconds=DRIVER_FRESH_SECONDS)
    result = await db.execute(
        select(Driver)
        .where(
            Driver.status == DriverStatus.available,
            Driver.is_verified == True,  # noqa: E712 — SQLAlchemy column comparison, not a bool test
            Driver.last_seen_at >= fresh_since,  # NULL (never reported) is excluded too
            Driver.current_lat.between(patient_lat - dlat, patient_lat + dlat),
            Driver.current_lng.between(patient_lng - dlng, patient_lng + dlng),
        )
        .limit(CANDIDATE_LIMIT)
    )
    drivers = result.scalars().all()

    drivers_with_dist = [
        (d, haversine_km(patient_lat, patient_lng, d.current_lat, d.current_lng))
        for d in drivers
    ]
    drivers_with_dist.sort(key=lambda x: x[1])
    return [d for d, _ in drivers_with_dist]


async def find_nearest_available_driver(
    db: AsyncSession, patient_lat: float, patient_lng: float
) -> Optional[Driver]:
    drivers = await find_available_drivers_by_distance(db, patient_lat, patient_lng)
    return drivers[0] if drivers else None


async def claim_driver(db: AsyncSession, candidates: list[Driver]) -> Optional[Driver]:
    """Atomically mark the first still-available candidate busy.

    The listing query above takes no lock, so two dispatches can pick the same
    driver. The guarded UPDATE row-locks the driver; a concurrent claim waits,
    re-checks `status = available`, matches nothing, and moves to the next
    candidate. The claim is part of the caller's transaction, so a later
    rollback releases the driver.
    """
    for candidate in candidates:
        result = await db.execute(
            update(Driver)
            .where(Driver.id == candidate.id, Driver.status == DriverStatus.available)
            .values(status=DriverStatus.busy)
        )
        if result.rowcount == 1:
            return candidate
    return None


async def _assign_driver(
    db: AsyncSession, ride: RideInfo, patient: PatientInfo, match: MatchResult
) -> tuple[Optional[DriverInfo], Optional[str]]:
    """Claim the nearest driver and assign the ride in one short transaction.

    Returns (driver, None) on success or (None, failure reason).
    """
    candidates = await find_available_drivers_by_distance(
        db, ride.pickup_lat, ride.pickup_lng
    )
    # Someone who is both patient and driver must not be sent to themselves.
    candidates = [d for d in candidates if d.user_id != patient.user_id]
    driver = await claim_driver(db, candidates)
    if driver is None:
        await db.commit()  # nothing claimed; just release the read transaction
        return None, "no_driver"
    info = DriverInfo(driver.id, driver.user_id, driver.full_name, driver.vehicle_plate)

    # Only a still-pending ride may be assigned: the patient may have cancelled
    # while triage was running.
    assigned = await db.execute(
        update(Ride)
        .where(Ride.id == ride.id, Ride.status == RideStatus.pending)
        .values(
            driver_id=driver.id,
            hospital_id=match.hospital_id,
            estimated_fare_pkr=fare_for(match.distance_km),
            status=RideStatus.driver_assigned,
            driver_assigned_at=datetime.now(timezone.utc),
        )
    )
    if assigned.rowcount != 1:
        await db.rollback()  # also releases the driver claimed above
        return None, "ride_not_pending"
    await db.commit()
    return info, None


# ── notifications ─────────────────────────────────────────────────────────────


def _report_notifications(ride_id, driver_pushed: bool, results: list) -> bool:
    """Log every undelivered notification; True when the hospital was pre-alerted."""
    family_sms, hospital_alert = results
    if not driver_pushed:
        metrics.dispatch_failures_total.labels(reason="driver_not_notified").inc()
        log.error("driver NOT notified of the assignment ride_id=%s", ride_id)
    if isinstance(family_sms, BaseException):
        log.error(
            "family SMS crashed ride_id=%s (%s)", ride_id, type(family_sms).__name__
        )
    if isinstance(hospital_alert, BaseException):
        log.error(
            "hospital pre-alert crashed ride_id=%s (%s)",
            ride_id,
            type(hospital_alert).__name__,
        )
    prealerted = hospital_alert is True
    if not prealerted:
        metrics.dispatch_failures_total.labels(reason="hospital_not_prealerted").inc()
        log.error("hospital NOT pre-alerted ride_id=%s", ride_id)
    return prealerted


async def _notify_everyone(
    db: AsyncSession,
    ride: RideInfo,
    patient: PatientInfo,
    driver: DriverInfo,
    match: MatchResult,
    triage: dict,
) -> bool:
    """Tell the driver, the family and the hospital. True if the hospital was told."""
    driver_pushed = await notify_user(
        db,
        user_id=driver.user_id,
        title="New ride assigned",
        body=ride.pickup_address or "Open the app for pickup details.",
        data={"ride_id": str(ride.id)},
    )
    await db.commit()  # the token lookup opened a transaction; free it before SMS/FHIR
    results = await asyncio.gather(
        send_family_sms(
            patient=patient, ride=ride, driver=driver, hospital_name=match.hospital_name
        ),
        send_hospital_alert(ride=ride, triage=triage, hospital=match, patient=patient),
        return_exceptions=True,
    )
    return _report_notifications(ride.id, driver_pushed, results)


# ── pipeline ──────────────────────────────────────────────────────────────────


def _fail(ride_id, reason: str) -> dict:
    message, level = _FAILURES[reason]
    metrics.dispatch_failures_total.labels(reason=reason).inc()
    log.log(level, "dispatch failed ride_id=%s reason=%s", ride_id, reason)
    return {"error": message}


async def _load_context(
    db: AsyncSession, ride: RideInfo
) -> tuple[Optional[dict], list[HospitalCandidate], PatientInfo]:
    """Read everything the pipeline needs, then end the transaction."""
    stored_triage = await load_stored_triage(db, ride.id)
    hospitals = await load_hospital_candidates(db)
    row = await load_patient(db, ride.patient_id)
    patient = PatientInfo(
        id=row.id,
        user_id=row.user_id,
        full_name=row.full_name,
        emergency_contact_phone=row.emergency_contact_phone,
    )
    await db.commit()
    return stored_triage, hospitals, patient


async def dispatch_emergency(
    ride: Ride,
    symptom_text: str,
    db: AsyncSession,
) -> dict:
    """
    Full emergency pipeline: triage, hospital match, driver claim, notifications.
    Returns a dispatch summary dict, or {"error": ...} (logged and counted) when
    the ride could not be placed.
    """
    pipeline_start = time.time()
    # Copy what we need now: a rollback below expires `ride` and every ORM object.
    info = _snapshot_ride(ride, symptom_text)

    stored_triage, hospitals, patient = await _load_context(db, info)
    # A retry reuses the stored result instead of asking the service again.
    triage = stored_triage or await _triage_and_record(db, info)

    matches = match_hospitals(
        patient_lat=info.pickup_lat,
        patient_lng=info.pickup_lng,
        required_specialty=triage["specialty"],
        candidates=hospitals,
    )
    if not matches:
        return _fail(info.id, "no_hospital")
    best = matches[0]

    driver, failure = await _assign_driver(db, info, patient, best)
    if driver is None:
        return _fail(info.id, failure)

    prealerted = await _notify_everyone(db, info, patient, driver, best, triage)

    elapsed = round(time.time() - pipeline_start, 2)
    metrics.emergency_dispatch_seconds.observe(elapsed)

    return {
        "ride_id": str(info.id),
        "driver_id": str(driver.id),
        "driver_name": driver.full_name,
        "driver_vehicle": driver.vehicle_plate,
        "hospital_id": best.hospital_id,
        "hospital_name": best.hospital_name,
        "hospital_distance_km": best.distance_km,
        "hospital_prealerted": prealerted,
        "triage_specialty": triage["specialty"],
        "severity": triage["severity"],
        "pipeline_elapsed_seconds": elapsed,
        "under_target": elapsed < settings.EMERGENCY_PIPELINE_TARGET_SECONDS,
    }


async def load_active_hospitals(db: AsyncSession):
    result = await db.execute(
        select(Hospital).where(Hospital.is_active == True)  # noqa: E712 — SQLAlchemy column comparison
    )
    return result.scalars().all()


async def load_hospital_candidates(db: AsyncSession) -> list[HospitalCandidate]:
    return [
        HospitalCandidate(
            id=str(h.id),
            name=h.name,
            lat=h.lat,
            lng=h.lng,
            specialties=h.specialties,
            ed_capacity=h.ed_capacity,
            ed_current_load=h.ed_current_load,
            fhir_endpoint=h.fhir_endpoint,
            coordinator_phone=h.coordinator_phone,
        )
        for h in await load_active_hospitals(db)
    ]


async def match_hospital_for_ride(
    db: AsyncSession, ride_id, pickup_lat: float, pickup_lng: float, symptom_text: str
) -> Optional[MatchResult]:
    """Best hospital for a ride that dispatch did not place (a driver accepted it).

    Uses the stored triage result when there is one, otherwise the local rules:
    the driver is waiting on this call, so it never makes a network request.
    """
    triage = await load_stored_triage(db, ride_id) or normalise_triage(
        fallback_triage(symptom_text), symptom_text
    )
    matches = match_hospitals(
        patient_lat=pickup_lat,
        patient_lng=pickup_lng,
        required_specialty=triage["specialty"],
        candidates=await load_hospital_candidates(db),
    )
    return matches[0] if matches else None


async def load_patient(db: AsyncSession, patient_id):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    return result.scalar_one()
