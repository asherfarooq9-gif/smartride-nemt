"""
Notification service: Twilio SMS + HL7 FHIR R4 hospital pre-alerts + FCM push.
Falls back gracefully when credentials are absent.
"""

import asyncio
import httpx
import logging
from datetime import datetime, timezone
from urllib.parse import urlsplit

from app.core.config import settings
from app.core.safe_url import UnsafeUrlError, resolve_public_ip

log = logging.getLogger("smartride.notifications")

TWILIO_TIMEOUT_SECONDS = 10
# A pre-alert is only useful in seconds; a slow hospital endpoint must not hold
# the dispatch pipeline (the SMS fallback takes over).
FHIR_TIMEOUT = httpx.Timeout(5.0, connect=3.0)
_FHIR_DEFAULT_PORTS = {"https": 443, "http": 80}
_fcm_credentials = None


def _fcm_access_token() -> str:
    """Blocking: reads the key file once, refreshes only when the token expires."""
    import google.auth.transport.requests
    import google.oauth2.service_account

    global _fcm_credentials
    if _fcm_credentials is None:
        _fcm_credentials = (
            google.oauth2.service_account.Credentials.from_service_account_file(
                settings.FIREBASE_CREDENTIALS_PATH,
                scopes=["https://www.googleapis.com/auth/firebase.messaging"],
            )
        )
    if not _fcm_credentials.valid:
        _fcm_credentials.refresh(google.auth.transport.requests.Request())
    return _fcm_credentials.token


async def send_push(
    *, fcm_token: str, title: str, body: str, data: dict | None = None
) -> None:
    """Send an FCM push notification via the Firebase HTTP v1 API."""
    if not settings.FIREBASE_PROJECT_ID or not fcm_token:
        log.debug("FCM no-op (no project_id or token)")
        return
    try:
        token = await asyncio.to_thread(_fcm_access_token)
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


_pending_pushes: set[asyncio.Task] = set()


async def notify_user(
    db,
    *,
    title: str,
    body: str,
    data: dict | None = None,
    user_id=None,
    patient_id=None,
) -> None:
    """Fire-and-forget push to a user (by user id, or by patient profile id).

    Never raises: a failed notification must not fail the request that caused it.
    """
    from sqlalchemy import select

    from app.models.models import Patient, User

    try:
        query = select(User.fcm_token)
        if patient_id is not None:
            query = query.join(Patient, Patient.user_id == User.id).where(
                Patient.id == patient_id
            )
        else:
            query = query.where(User.id == user_id)
        token = (await db.execute(query)).scalar_one_or_none()
        if token:
            task = asyncio.create_task(
                send_push(fcm_token=token, title=title, body=body, data=data)
            )
            _pending_pushes.add(task)  # keep a reference so it is not garbage-collected
            task.add_done_callback(_pending_pushes.discard)
    except Exception:
        log.warning("push lookup failed", exc_info=True)


def _mask_phone(phone: str) -> str:
    """Show only the last 3 digits so logs never carry a full PHI phone number."""
    if not phone or len(phone) < 4:
        return "***"
    return f"***{phone[-3:]}"


def _send_sms(to: str, body: str) -> bool:
    """True only if Twilio accepted the message."""
    # PHI discipline: never log the message body (carries patient name /
    # hospital / location) or the full recipient number.
    if not settings.TWILIO_ACCOUNT_SID:
        log.info("SMS no-op (Twilio unconfigured) to %s", _mask_phone(to))
        return False
    try:
        from twilio.http.http_client import TwilioHttpClient
        from twilio.rest import Client

        msg = Client(
            settings.TWILIO_ACCOUNT_SID,
            settings.TWILIO_AUTH_TOKEN,
            http_client=TwilioHttpClient(timeout=TWILIO_TIMEOUT_SECONDS),
        ).messages.create(body=body, from_=settings.TWILIO_FROM_NUMBER, to=to)
        log.info("SMS sent sid=%s to %s", msg.sid, _mask_phone(to))
    except Exception as exc:
        # Log the exception *type* only — the message text can echo body/phone.
        log.warning("SMS send failed to %s: %s", _mask_phone(to), type(exc).__name__)


async def send_family_sms(*, patient, ride, driver, hospital_name: str) -> None:
    if not patient.emergency_contact_phone:
        return
    body = (
        f"SmartRide Alert: {patient.full_name} is being transported to {hospital_name}. "
        f"Driver: {driver.full_name} ({driver.vehicle_plate}). "
        f"Ride ID: {ride.id}"
    )
    await asyncio.to_thread(_send_sms, patient.emergency_contact_phone, body)


async def _post_fhir_bundle(endpoint: str, bundle: dict) -> None:
    """POST to a hospital-supplied URL without letting it reach internal services.

    The hostname is resolved here, every answer must be a public address, and the
    connection goes to that exact IP (TLS still verifies the original hostname via
    SNI), so DNS cannot change its answer between check and use. Redirects are
    never followed and environment proxies are ignored.
    """
    parts = urlsplit(endpoint)
    if parts.scheme not in _FHIR_DEFAULT_PORTS or not parts.hostname:
        raise UnsafeUrlError("FHIR endpoint must be an http(s) URL")
    host = parts.hostname
    port = parts.port or _FHIR_DEFAULT_PORTS[parts.scheme]
    ip = await resolve_public_ip(host, port)
    ip_host = f"[{ip}]" if ":" in ip else ip
    pinned_url = parts._replace(netloc=f"{ip_host}:{port}").geturl()
    host_header = host if parts.port is None else f"{host}:{parts.port}"
    async with httpx.AsyncClient(
        timeout=FHIR_TIMEOUT, follow_redirects=False, trust_env=False
    ) as client:
        resp = await client.post(
            pinned_url,
            json=bundle,
            headers={"Content-Type": "application/fhir+json", "Host": host_header},
            extensions={"sni_hostname": host},
        )
        resp.raise_for_status()


async def send_hospital_alert(*, ride, triage: dict, hospital, patient) -> bool:
    """Pre-alert the hospital over FHIR, else by SMS. True if either channel delivered.

    Callers should record a False result: nobody at the hospital was told.
    """
    ride_id = getattr(ride, "id", None)
    fhir_bundle = _build_fhir_bundle(ride=ride, triage=triage, patient=patient)

    if hospital.has_fhir and hospital.fhir_endpoint:
        try:
            await _post_fhir_bundle(hospital.fhir_endpoint, fhir_bundle)
            return True
        except Exception as exc:
            log.warning(
                "FHIR pre-alert failed ride_id=%s, falling back to SMS: %s",
                ride_id,
                type(exc).__name__,
            )

    if not hospital.coordinator_phone:
        log.error(
            "Hospital pre-alert NOT delivered ride_id=%s: FHIR unavailable and no "
            "coordinator phone",
            ride_id,
        )
        return False
    body = (
        f"SmartRide Pre-Alert: Patient en route. "
        f"Specialty: {triage.get('specialty', 'unknown')} | "
        f"Severity: {triage.get('severity', '?')} | "
        f"Ride: {ride.id}"
    )
    sent = await asyncio.to_thread(_send_sms, hospital.coordinator_phone, body)
    if not sent:
        log.error("Hospital pre-alert NOT delivered ride_id=%s: SMS failed", ride_id)
    return bool(sent)


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
