"""
Notification service: Twilio SMS + HL7 FHIR R4 hospital pre-alerts + FCM push.
Falls back gracefully when credentials are absent.
"""

import httpx
import logging
from datetime import datetime, timezone

from app.core.config import settings

log = logging.getLogger("smartride.notifications")


async def send_push(
    *, fcm_token: str, title: str, body: str, data: dict | None = None
) -> None:
    """Send an FCM push notification via the Firebase HTTP v1 API."""
    if not settings.FIREBASE_PROJECT_ID or not fcm_token:
        log.debug("FCM no-op (no project_id or token)")
        return
    try:
        import google.auth.transport.requests
        import google.oauth2.service_account

        credentials = (
            google.oauth2.service_account.Credentials.from_service_account_file(
                settings.FIREBASE_CREDENTIALS_PATH,
                scopes=["https://www.googleapis.com/auth/firebase.messaging"],
            )
        )
        credentials.refresh(google.auth.transport.requests.Request())
        token = credentials.token
        url = f"https://fcm.googleapis.com/v1/projects/{settings.FIREBASE_PROJECT_ID}/messages:send"
        payload: dict = {
            "message": {
                "token": fcm_token,
                "notification": {"title": title, "body": body},
            }
        }
        if data:
            payload["message"]["data"] = {k: str(v) for k, v in data.items()}
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                url, json=payload, headers={"Authorization": f"Bearer {token}"}
            )
            resp.raise_for_status()
    except Exception as exc:
        log.warning("FCM push failed: %s", exc)


def _send_sms(to: str, body: str) -> None:
    if not settings.TWILIO_ACCOUNT_SID:
        print(f"[SMS no-op] To {to}: {body}")
        return
    try:
        from twilio.rest import Client

        msg = Client(
            settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN
        ).messages.create(body=body, from_=settings.TWILIO_FROM_NUMBER, to=to)
        print(f"[SMS sent] SID={msg.sid}")
    except Exception as exc:
        print(f"[SMS error] {exc}")


async def send_family_sms(*, patient, ride, driver, hospital_name: str) -> None:
    if not patient.emergency_contact_phone:
        return
    body = (
        f"SmartRide Alert: {patient.full_name} is being transported to {hospital_name}. "
        f"Driver: {driver.full_name} ({driver.vehicle_plate}). "
        f"Ride ID: {ride.id}"
    )
    _send_sms(patient.emergency_contact_phone, body)


async def send_hospital_alert(*, ride, triage: dict, hospital, patient) -> None:
    fhir_bundle = _build_fhir_bundle(ride=ride, triage=triage, patient=patient)

    if hospital.has_fhir and hospital.fhir_endpoint:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    hospital.fhir_endpoint,
                    json=fhir_bundle,
                    headers={"Content-Type": "application/fhir+json"},
                )
                resp.raise_for_status()
                return
        except Exception as exc:
            print(f"[FHIR error] Falling back to SMS: {exc}")

    if not hospital.coordinator_phone:
        return
    body = (
        f"SmartRide Pre-Alert: Patient en route. "
        f"Specialty: {triage.get('specialty', 'unknown')} | "
        f"Severity: {triage.get('severity', '?')} | "
        f"Ride: {ride.id}"
    )
    _send_sms(hospital.coordinator_phone, body)


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
                    "reasonCode": [
                        {"text": triage.get("specialty", "general_emergency")}
                    ],
                    "meta": {
                        "tag": [{"code": f"severity-{triage.get('severity', '3')}"}]
                    },
                }
            }
        ],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
