"""
Emergency Dispatch Service
Orchestrates: triage → hospital matching → driver dispatch → family SMS → hospital pre-alert
Target: entire pipeline < 60 seconds
"""

import asyncio
import time
import httpx
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.config import settings
from app.core import metrics
from app.core.specialties import normalize_specialty
from app.models.models import Ride, Driver, DriverStatus, Patient, Hospital, RideStatus
from app.services.hospital_matching import match_hospitals, HospitalCandidate
from app.services.notifications import send_family_sms, send_hospital_alert


CRITICAL_KEYWORDS = {
    "chest pain",
    "heart attack",
    "not breathing",
    "stroke",
    "unconscious",
    "unresponsive",
    "seizure",
    "severe bleeding",
    "cardiac arrest",
    "overdose",
    "choking",
}


def detect_severity_override(symptom_text: str) -> bool:
    text_lower = symptom_text.lower()
    return any(kw in text_lower for kw in CRITICAL_KEYWORDS)


async def call_triage_service(symptom_text: str) -> dict:
    """Call AI triage microservice. Returns {specialty, confidence, severity}."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.post(
                f"{settings.TRIAGE_SERVICE_URL}/triage",
                json={"text": symptom_text},
            )
            resp.raise_for_status()
            return resp.json()
        except Exception:
            # Fallback if AI service unavailable
            return {
                "specialty": "general_emergency",
                "confidence": 0.5,
                "severity": "5" if detect_severity_override(symptom_text) else "3",
                "rule_override": True,
                "model_version": "fallback-rules-v1",
            }


async def find_nearest_available_driver(
    db: AsyncSession, patient_lat: float, patient_lng: float
) -> Optional[Driver]:
    """Fetch available verified drivers from DB, sort by proximity."""
    result = await db.execute(
        select(Driver).where(
            Driver.status == DriverStatus.available,
            Driver.is_verified == True,  # noqa: E712 — SQLAlchemy column comparison, not a bool test
            Driver.current_lat.is_not(None),
        )
    )
    drivers = result.scalars().all()
    if not drivers:
        return None

    from app.services.hospital_matching import haversine_km

    drivers_with_dist = [
        (d, haversine_km(patient_lat, patient_lng, d.current_lat, d.current_lng))
        for d in drivers
    ]
    drivers_with_dist.sort(key=lambda x: x[1])
    return drivers_with_dist[0][0]


async def dispatch_emergency(
    ride: Ride,
    symptom_text: str,
    db: AsyncSession,
) -> dict:
    """
    Full emergency pipeline. Runs triage + hospital matching in parallel.
    Returns dispatch summary dict.
    """
    pipeline_start = time.time()

    # ── STEP 1: triage HTTP runs concurrently while DB queries run sequentially
    # (asyncio.gather on two DB coroutines sharing one connection causes
    #  "concurrent operations not permitted" — only the HTTP call benefits from
    #  true parallelism here anyway)
    triage_task = asyncio.create_task(call_triage_service(symptom_text))
    hospital_rows = await load_active_hospitals(db)
    patient = await load_patient(db, ride.patient_id)
    triage_result = await triage_task

    # Normalize specialty to a canonical enum value before it reaches hospital
    # matching or the DB — the fine-tuned model emits richer dataset labels.
    triage_result["specialty"] = normalize_specialty(triage_result.get("specialty"))

    if detect_severity_override(symptom_text):
        triage_result["severity"] = "5"
        triage_result["rule_override"] = True

    # ── STEP 2: hospital matching ──────────────────────────────────────────
    candidates = [
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
        for h in hospital_rows
    ]
    matches = match_hospitals(
        patient_lat=ride.pickup_lat,
        patient_lng=ride.pickup_lng,
        required_specialty=triage_result["specialty"],
        candidates=candidates,
    )

    if not matches:
        metrics.dispatch_failures_total.labels(reason="no_hospital").inc()
        return {"error": "No hospitals available in range"}

    best_hospital_id = matches[0].hospital_id

    # ── STEP 3: find nearest available driver ──────────────────────────────
    driver = await find_nearest_available_driver(db, ride.pickup_lat, ride.pickup_lng)

    if not driver:
        metrics.dispatch_failures_total.labels(reason="no_driver").inc()
        return {"error": "No drivers available. Retrying in 30s."}

    # ── STEP 4: update ride + driver status ───────────────────────────────
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)

    await db.execute(
        update(Ride)
        .where(Ride.id == ride.id)
        .values(
            driver_id=driver.id,
            hospital_id=best_hospital_id,
            status=RideStatus.driver_assigned,
            driver_assigned_at=now,
        )
    )
    await db.execute(
        update(Driver).where(Driver.id == driver.id).values(status=DriverStatus.busy)
    )
    await db.commit()

    # ── STEP 5: parallel — family SMS + hospital pre-alert ─────────────────
    await asyncio.gather(
        send_family_sms(
            patient=patient,
            ride=ride,
            driver=driver,
            hospital_name=matches[0].hospital_name,
        ),
        send_hospital_alert(
            ride=ride, triage=triage_result, hospital=matches[0], patient=patient
        ),
        return_exceptions=True,
    )

    elapsed = round(time.time() - pipeline_start, 2)
    metrics.emergency_dispatch_seconds.observe(elapsed)

    return {
        "ride_id": str(ride.id),
        "driver_id": str(driver.id),
        "driver_name": driver.full_name,
        "driver_vehicle": driver.vehicle_plate,
        "hospital_id": best_hospital_id,
        "hospital_name": matches[0].hospital_name,
        "hospital_distance_km": matches[0].distance_km,
        "triage_specialty": triage_result["specialty"],
        "severity": triage_result["severity"],
        "pipeline_elapsed_seconds": elapsed,
        "under_target": elapsed < settings.EMERGENCY_PIPELINE_TARGET_SECONDS,
    }


async def load_active_hospitals(db: AsyncSession):
    result = await db.execute(
        select(Hospital).where(Hospital.is_active == True)  # noqa: E712 — SQLAlchemy column comparison
    )
    return result.scalars().all()


async def load_patient(db: AsyncSession, patient_id):
    result = await db.execute(select(Patient).where(Patient.id == patient_id))
    return result.scalar_one()
