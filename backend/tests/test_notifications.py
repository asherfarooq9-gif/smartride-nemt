"""Notification fan-out: FHIR hospital pre-alerts, SMS fallback and PHI-safe logging.

The critical property here is that a pre-alert always reaches the hospital by
*some* channel: if the FHIR POST is refused (unsafe endpoint) or fails, the SMS
fallback must still fire.
"""

import types
import uuid

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.core.config import settings
from app.services import notifications
from app.services.notifications import (
    _build_fhir_bundle,
    _mask_phone,
    send_family_sms,
    send_hospital_alert,
    send_push,
)

TRIAGE = {"specialty": "cardiology", "severity": "1"}


def _hospital(
    *, fhir_endpoint: str | None, coordinator_phone: str | None = "+920000000000"
):
    return types.SimpleNamespace(
        name="Test General",
        has_fhir=bool(fhir_endpoint),
        fhir_endpoint=fhir_endpoint,
        coordinator_phone=coordinator_phone,
    )


def _ride():
    return types.SimpleNamespace(id=uuid.uuid4())


def _patient():
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        full_name="Test Patient",
        emergency_contact_phone="+920000000002",
    )


# ── phone masking ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "phone,expected",
    [
        ("+923001234567", "***567"),
        ("123", "***"),
        ("", "***"),
    ],
)
def test_mask_phone_keeps_only_the_last_three_digits(phone, expected):
    assert _mask_phone(phone) == expected


# ── FHIR bundle ──────────────────────────────────────────────────────────────


def test_fhir_bundle_shape():
    patient = _patient()
    bundle = _build_fhir_bundle(ride=_ride(), triage=TRIAGE, patient=patient)

    assert bundle["resourceType"] == "Bundle"
    assert bundle["type"] == "transaction"
    encounter = bundle["entry"][0]["resource"]
    assert encounter["resourceType"] == "Encounter"
    assert encounter["subject"]["reference"] == f"Patient/{patient.id}"
    assert encounter["reasonCode"][0]["text"] == "cardiology"
    assert bundle["timestamp"].endswith("+00:00")


def test_fhir_bundle_defaults_when_triage_is_empty():
    bundle = _build_fhir_bundle(ride=_ride(), triage={}, patient=_patient())
    encounter = bundle["entry"][0]["resource"]
    assert encounter["reasonCode"][0]["text"] == "general_emergency"


# ── hospital pre-alert ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_fhir_post_is_made_for_a_safe_endpoint():
    hospital = _hospital(fhir_endpoint="https://fhir.example-hospital.test/r4")
    response = MagicMock()
    response.raise_for_status = MagicMock()
    client = AsyncMock()
    client.post = AsyncMock(return_value=response)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)

    sms = MagicMock()
    with (
        patch.object(notifications, "assert_safe_outbound_url", AsyncMock()),
        patch.object(notifications.httpx, "AsyncClient", return_value=client),
        patch.object(notifications, "_send_sms", sms),
    ):
        await send_hospital_alert(
            ride=_ride(), triage=TRIAGE, hospital=hospital, patient=_patient()
        )

    client.post.assert_awaited_once()
    assert client.post.await_args.args[0] == "https://fhir.example-hospital.test/r4"
    # A successful FHIR delivery must not also send an SMS.
    sms.assert_not_called()


@pytest.mark.asyncio
async def test_unsafe_endpoint_is_never_posted_to_and_falls_back_to_sms():
    """The SSRF guard must block the request but still alert the hospital."""
    hospital = _hospital(fhir_endpoint="http://169.254.169.254/latest/meta-data/")
    client = AsyncMock()
    sms = MagicMock()

    with (
        patch.object(notifications.httpx, "AsyncClient", return_value=client),
        patch.object(notifications, "_send_sms", sms),
    ):
        await send_hospital_alert(
            ride=_ride(), triage=TRIAGE, hospital=hospital, patient=_patient()
        )

    client.post.assert_not_awaited()
    sms.assert_called_once()
    assert sms.call_args.args[0] == "+920000000000"


@pytest.mark.asyncio
async def test_fhir_failure_falls_back_to_sms():
    hospital = _hospital(fhir_endpoint="https://fhir.example-hospital.test/r4")
    client = AsyncMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.post = AsyncMock(side_effect=RuntimeError("connection reset"))

    sms = MagicMock()
    with (
        patch.object(notifications, "assert_safe_outbound_url", AsyncMock()),
        patch.object(notifications.httpx, "AsyncClient", return_value=client),
        patch.object(notifications, "_send_sms", sms),
    ):
        await send_hospital_alert(
            ride=_ride(), triage=TRIAGE, hospital=hospital, patient=_patient()
        )

    sms.assert_called_once()
    body = sms.call_args.args[1]
    assert "cardiology" in body
    assert "Severity: 1" in body


@pytest.mark.asyncio
async def test_hospital_without_fhir_goes_straight_to_sms():
    sms = MagicMock()
    with patch.object(notifications, "_send_sms", sms):
        await send_hospital_alert(
            ride=_ride(),
            triage=TRIAGE,
            hospital=_hospital(fhir_endpoint=None),
            patient=_patient(),
        )
    sms.assert_called_once()


@pytest.mark.asyncio
async def test_hospital_with_no_contact_route_is_a_noop():
    sms = MagicMock()
    with patch.object(notifications, "_send_sms", sms):
        await send_hospital_alert(
            ride=_ride(),
            triage=TRIAGE,
            hospital=_hospital(fhir_endpoint=None, coordinator_phone=None),
            patient=_patient(),
        )
    sms.assert_not_called()


# ── family SMS ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_family_sms_names_the_driver_and_hospital():
    driver = types.SimpleNamespace(full_name="Test Driver", vehicle_plate="PL-0001")
    sms = MagicMock()

    with patch.object(notifications, "_send_sms", sms):
        await send_family_sms(
            patient=_patient(),
            ride=_ride(),
            driver=driver,
            hospital_name="Test General",
        )

    sms.assert_called_once()
    to, body = sms.call_args.args
    assert to == "+920000000002"
    assert "Test Patient" in body
    assert "Test General" in body
    assert "PL-0001" in body


@pytest.mark.asyncio
async def test_family_sms_skipped_without_an_emergency_contact():
    patient = _patient()
    patient.emergency_contact_phone = None
    sms = MagicMock()

    with patch.object(notifications, "_send_sms", sms):
        await send_family_sms(
            patient=patient,
            ride=_ride(),
            driver=types.SimpleNamespace(full_name="D", vehicle_plate="P"),
            hospital_name="H",
        )
    sms.assert_not_called()


# ── SMS transport ────────────────────────────────────────────────────────────


def test_send_sms_is_a_noop_without_twilio_credentials(monkeypatch, caplog):
    monkeypatch.setattr(settings, "TWILIO_ACCOUNT_SID", "")
    with caplog.at_level("INFO", logger="smartride.notifications"):
        notifications._send_sms("+923001234567", "patient en route")

    # The body is PHI and the full number is identifying; neither may be logged.
    logged = " ".join(record.getMessage() for record in caplog.records)
    assert "patient en route" not in logged
    assert "+923001234567" not in logged
    assert "***567" in logged


# ── push ─────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_push_is_a_noop_without_a_firebase_project(monkeypatch):
    monkeypatch.setattr(settings, "FIREBASE_PROJECT_ID", "")
    # Must return without touching the network.
    await send_push(fcm_token="t", title="x", body="y")


@pytest.mark.asyncio
async def test_push_is_a_noop_without_a_token(monkeypatch):
    monkeypatch.setattr(settings, "FIREBASE_PROJECT_ID", "proj")
    await send_push(fcm_token="", title="x", body="y")


@pytest.mark.asyncio
async def test_push_failure_is_swallowed(monkeypatch):
    """A dead FCM pipeline must never propagate into a ride status update."""
    monkeypatch.setattr(settings, "FIREBASE_PROJECT_ID", "proj")
    monkeypatch.setattr(settings, "FIREBASE_CREDENTIALS_PATH", "/nonexistent.json")
    await send_push(fcm_token="tok", title="x", body="y", data={"ride_id": "1"})
