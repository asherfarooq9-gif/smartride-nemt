"""
Notification service: Twilio SMS + HL7 FHIR R4 hospital pre-alerts.
Falls back gracefully when credentials are absent.
"""
import httpx
from datetime import datetime, timezone

from app.core.config import settings


async def send_family_sms(*, patient, ride, driver, hospital_name: str) -> None:
    if not patient.emergency_contact_phone:
        return

    body = (
        f"SmartRide Alert: {patient.full_name} is being transported to {hospital_name}. "
        f"Driver: {driver.full_name} ({driver.vehicle_plate}). "
        f"Ride ID: {ride.id}"
    )

    if not settings.TWILIO_ACCOUNT_SID:
        # No-op fallback — log only
        print(f"[SMS no-op] To {patient.emergency_contact_phone}: {body}")
        return

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        msg = client.messages.create(
            body=body,
            from_=settings.TWILIO_FROM_NUMBER,
            to=patient.emergency_contact_phone,
        )
        print(f"[SMS sent] SID={msg.sid}")
    except Exception as exc:
        print(f"[SMS error] {exc}")


async def send_hospital_alert(*, ride, triage: dict, hospital, patient) -> None:
    """
    Send HL7 FHIR R4 ADT^A01 bundle to hospital FHIR endpoint.
    Falls back to coordinator SMS if no FHIR endpoint.
    """
    fhir_bundle = _build_fhir_bundle(ride=ride, triage=triage, patient=patient)

    if hospital.has_fhir and getattr(hospital, 'has_fhir', False):
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    hospital.coordinator_phone,  # fhir_endpoint in MatchResult
                    json=fhir_bundle,
                    headers={"Content-Type": "application/fhir+json"},
                )
                resp.raise_for_status()
                return
        except Exception as exc:
            print(f"[FHIR error] Falling back to SMS: {exc}")

    # SMS fallback to coordinator
    coordinator = getattr(hospital, 'coordinator_phone', None)
    if not coordinator:
        return

    body = (
        f"SmartRide Pre-Alert: Patient en route. "
        f"Specialty: {triage.get('specialty','unknown')} | "
        f"Severity: {triage.get('severity','?')} | "
        f"Ride: {ride.id}"
    )

    if not settings.TWILIO_ACCOUNT_SID:
        print(f"[Hospital SMS no-op] To {coordinator}: {body}")
        return

    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(body=body, from_=settings.TWILIO_FROM_NUMBER, to=coordinator)
    except Exception as exc:
        print(f"[Hospital SMS error] {exc}")


def _build_fhir_bundle(*, ride, triage: dict, patient) -> dict:
    return {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [
            {
                "resource": {
                    "resourceType": "Encounter",
                    "status": "in-progress",
                    "class": {"code": "EMER", "display": "emergency"},
                    "subject": {"reference": f"Patient/{patient.id}"},
                    "reasonCode": [{"text": triage.get("specialty", "general_emergency")}],
                    "meta": {"tag": [{"code": f"severity-{triage.get('severity','3')}"}]},
                }
            }
        ],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
