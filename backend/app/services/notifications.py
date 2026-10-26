"""
Notification service: Twilio SMS + HL7 FHIR R4 hospital pre-alerts + FCM push.
Falls back gracefully when credentials are absent.
"""

import asyncio
import httpx
import logging
import os
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


def push_setup_problem() -> str | None:
    """Why push notifications cannot be delivered, or None when they can.

    Without a project id or the key file, send_push quietly does nothing, so a
    production deploy that forgot either looks healthy while no driver or patient
    ever receives a push.
    """
    if not settings.FIREBASE_PROJECT_ID:
        return "FIREBASE_PROJECT_ID is not set"
    if not os.path.isfile(settings.FIREBASE_CREDENTIALS_PATH):
        return f"credentials file not found at {settings.FIREBASE_CREDENTIALS_PATH}"
    return None


_pending_pushes: set[asyncio.Task] = set()


def _on_push_done(task: asyncio.Task, ride_id) -> None:
    """Forget a finished push task and make sure a crash in it is never silent."""
    _pending_pushes.discard(task)
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        log.error("push task failed ride_id=%s (%s)", ride_id, type(exc).__name__)


async def notify_user(
    db,
    *,
    title: str,
    body: str,
    data: dict | None = None,
    user_id=None,
    patient_id=None,
) -> bool:
    """Fire-and-forget push to a user (by user id, or by patient profile id).

    Never raises: a failed notification must not fail the request that caused it.
    Returns True only when a push was handed to the sender. False means nobody
    will be told (lookup failed or no device token), so callers whose message is
    safety-critical must log it.
    """
    from sqlalchemy import select

    from app.models.models import Patient, User

    ride_id = (data or {}).get("ride_id")
    try:
        query = select(User.fcm_token)
        if patient_id is not None:
            query = query.join(Patient, Patient.user_id == User.id).where(
                Patient.id == patient_id
            )
        else:
            query = query.where(User.id == user_id)
        token = (await db.execute(query)).scalar_one_or_none()
    except Exception as exc:
        log.warning("push lookup failed ride_id=%s (%s)", ride_id, type(exc).__name__)
        return False
    if not token:
        log.info("push skipped, no device token ride_id=%s", ride_id)
        return False
    task = asyncio.create_task(
        send_push(fcm_token=token, title=title, body=body, data=data)
    )
    _pending_pushes.add(task)  # keep a reference so it is not garbage-collected
    task.add_done_callback(lambda done: _on_push_done(done, ride_id))
    return True


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
        return True
    except Exception as exc:
        # Log the exception *type* only — the message text can echo body/phone.
        log.warning("SMS send failed to %s: %s", _mask_phone(to), type(exc).__name__)
        return False


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
    fhir_bundle = _build_fhir_bundle(
        ride=ride, triage=triage, patient=patient, ed_full=hospital.ed_full
    )

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
        f"{' | ED FULL per your last update, please confirm' if hospital.ed_full else ''}"
    )
    sent = await asyncio.to_thread(_send_sms, hospital.coordinator_phone, body)
    if not sent:
        log.error("Hospital pre-alert NOT delivered ride_id=%s: SMS failed", ride_id)
    return bool(sent)


async def send_sms_to_patient(db, *, patient_id, body: str) -> bool:
    """SMS the phone number on the patient's account. Never raises.

    For messages that must not depend on a push token being valid, such as the
    instruction to call 1122 when no driver could be found. True only when the
    SMS was handed to the sender.
    """
    from sqlalchemy import select

    from app.models.models import Patient, User

    try:
        phone = (
            await db.execute(
                select(User.phone)
                .join(Patient, Patient.user_id == User.id)
                .where(Patient.id == patient_id)
            )
        ).scalar_one_or_none()
    except Exception as exc:
        log.error("patient phone lookup failed (%s)", type(exc).__name__)
        return False
    if not phone:
        return False
    return bool(await asyncio.to_thread(_send_sms, phone, body))


async def tell_hospital_ride_stopped(db, *, ride_id, hospital_id) -> bool:
    """SMS the hospital coordinator that an earlier pre-alert no longer applies.

    Used when a ride is cancelled or goes back to the queue after the hospital
    was already alerted, so staff do not hold a bay for a patient who is not
    coming. Never raises. True only when the SMS was handed to the sender.
    """
    from sqlalchemy import select

    from app.core import metrics
    from app.models.models import Hospital

    try:
        phone = (
            await db.execute(
                select(Hospital.coordinator_phone).where(Hospital.id == hospital_id)
            )
        ).scalar_one_or_none()
    except Exception as exc:
        log.error(
            "hospital lookup failed, NOT told ride stopped ride_id=%s (%s)",
            ride_id,
            type(exc).__name__,
        )
        phone = None
    sent = False
    if phone:
        body = (
            f"SmartRide Update: Ride {ride_id} was cancelled or re-assigned. "
            "Disregard the earlier pre-alert."
        )
        sent = bool(await asyncio.to_thread(_send_sms, phone, body))
    if not sent:
        metrics.dispatch_failures_total.labels(
            reason="hospital_not_told_ride_stopped"
        ).inc()
        log.error("hospital NOT told the ride stopped ride_id=%s", ride_id)
    return sent


def _build_fhir_bundle(*, ride, triage: dict, patient, ed_full: bool = False) -> dict:
    tags = [{"code": f"severity-{triage.get('severity', '3')}"}]
    if ed_full:
        tags.append({"code": "ed-reported-full"})
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
                    "meta": {"tag": tags},
                }
            }
        ],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
