"""Push and hospital pre-alert delivery: what is sent, and what happens when it fails."""

import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
from sqlalchemy import select, update

from app.models.models import Patient, User
from app.services import notifications
from tests.test_dispatch_endpoints import _register

PATIENT = SimpleNamespace(
    id="p1", full_name="Test Patient", emergency_contact_phone="+923001234567"
)
RIDE = SimpleNamespace(id="r1")


# ── FCM push ─────────────────────────────────────────────────────────────────


def _fake_client(error=None):
    """A stand-in for httpx.AsyncClient that records what was posted."""

    class Client:
        posts: list = []

        def __init__(self, *args, **kwargs): ...

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def post(self, url, json=None, headers=None, **kwargs):
            if error:
                raise error
            Client.posts.append((url, json, headers))
            return SimpleNamespace(raise_for_status=lambda: None)

    return Client


async def test_push_is_a_noop_without_a_project_id_or_token():
    client = _fake_client()
    with (
        patch.object(notifications.settings, "FIREBASE_PROJECT_ID", ""),
        patch.object(notifications.httpx, "AsyncClient", client),
    ):
        await notifications.send_push(fcm_token="t", title="a", body="b")
    with (
        patch.object(notifications.settings, "FIREBASE_PROJECT_ID", "demo"),
        patch.object(notifications.httpx, "AsyncClient", client),
    ):
        await notifications.send_push(fcm_token="", title="a", body="b")

    assert client.posts == []


async def test_push_posts_the_message_to_fcm_with_a_bearer_token():
    client = _fake_client()
    with (
        patch.object(notifications.settings, "FIREBASE_PROJECT_ID", "demo"),
        patch.object(notifications, "_fcm_access_token", lambda: "access-token"),
        patch.object(notifications.httpx, "AsyncClient", client),
    ):
        await notifications.send_push(
            fcm_token="device-1", title="Hi", body="There", data={"ride_id": 7}
        )

    ((url, payload, headers),) = client.posts
    assert url == "https://fcm.googleapis.com/v1/projects/demo/messages:send"
    assert headers == {"Authorization": "Bearer access-token"}
    assert payload["message"]["token"] == "device-1"
    assert payload["message"]["notification"] == {"title": "Hi", "body": "There"}
    assert payload["message"]["data"] == {"ride_id": "7"}  # FCM wants strings


async def test_a_failing_push_never_raises_and_is_logged(caplog):
    client = _fake_client(error=httpx.ConnectError("fcm unreachable"))
    with (
        patch.object(notifications.settings, "FIREBASE_PROJECT_ID", "demo"),
        patch.object(notifications, "_fcm_access_token", lambda: "t"),
        patch.object(notifications.httpx, "AsyncClient", client),
        caplog.at_level("WARNING", logger="smartride.notifications"),
    ):
        await notifications.send_push(fcm_token="d", title="a", body="b")

    assert any("FCM push failed" in r.message for r in caplog.records)


async def test_a_push_task_that_crashes_is_reported_not_swallowed(caplog):
    async def boom():
        raise RuntimeError("push exploded")

    task = asyncio.create_task(boom())
    await asyncio.gather(task, return_exceptions=True)

    with caplog.at_level("ERROR", logger="smartride.notifications"):
        notifications._on_push_done(task, "ride-9")

    assert any("push task failed ride_id=ride-9" in r.message for r in caplog.records)


# ── notify_user ──────────────────────────────────────────────────────────────


async def _patient_id(db, phone):
    return (
        await db.execute(
            select(Patient.id)
            .join(User, User.id == Patient.user_id)
            .where(User.phone == phone)
        )
    ).scalar_one()


async def test_notify_user_reports_false_without_a_device_token(client, db):
    phone = "+923007770777"
    await _register(client, phone, "patient")

    delivered = await notifications.notify_user(
        db, patient_id=await _patient_id(db, phone), title="t", body="b"
    )

    assert delivered is False


async def test_notify_user_hands_the_push_to_the_sender_when_there_is_a_token(
    client, db
):
    phone = "+923007770778"
    await _register(client, phone, "patient")
    await db.execute(update(User).where(User.phone == phone).values(fcm_token="dev-9"))
    await db.commit()
    sender = AsyncMock()

    with patch.object(notifications, "send_push", sender):
        delivered = await notifications.notify_user(
            db,
            patient_id=await _patient_id(db, phone),
            title="t",
            body="b",
            data={"ride_id": "r"},
        )
        await asyncio.gather(*notifications._pending_pushes)

    assert delivered is True
    sender.assert_awaited_once_with(
        fcm_token="dev-9", title="t", body="b", data={"ride_id": "r"}
    )


async def test_notify_user_never_raises_when_the_lookup_fails():
    class BrokenSession:
        async def execute(self, *_args, **_kwargs):
            raise OSError("database gone")

    delivered = await notifications.notify_user(
        BrokenSession(), user_id="u", title="t", body="b"
    )

    assert delivered is False


# ── hospital pre-alert: FHIR failure modes and what the SMS reveals ───────────


def _hospital(fhir=True, phone="+923009998888", ed_full=False):
    return SimpleNamespace(
        has_fhir=fhir,
        fhir_endpoint="https://fhir.example.org/bundle" if fhir else None,
        coordinator_phone=phone,
        ed_full=ed_full,
    )


async def _alert(hospital, post=None):
    sent = []
    with (
        patch.object(notifications, "_post_fhir_bundle", post or AsyncMock()),
        patch.object(
            notifications, "_send_sms", lambda to, body: sent.append((to, body)) or True
        ),
    ):
        ok = await notifications.send_hospital_alert(
            ride=RIDE,
            triage={"specialty": "cardiology", "severity": "5"},
            hospital=hospital,
            patient=PATIENT,
        )
    return ok, sent


async def test_a_delivered_fhir_alert_sends_no_sms():
    ok, sent = await _alert(_hospital())

    assert ok is True
    assert sent == []


async def test_a_fhir_server_error_falls_back_to_sms():
    boom = httpx.HTTPStatusError(
        "503", request=httpx.Request("POST", "https://x"), response=httpx.Response(503)
    )

    ok, sent = await _alert(_hospital(), post=AsyncMock(side_effect=boom))

    assert ok is True
    assert [to for to, _ in sent] == ["+923009998888"]


async def test_a_fhir_timeout_falls_back_to_sms():
    ok, sent = await _alert(
        _hospital(), post=AsyncMock(side_effect=httpx.ReadTimeout("slow"))
    )

    assert ok is True
    assert len(sent) == 1


async def test_no_fhir_and_no_phone_reports_nobody_was_told():
    ok, sent = await _alert(_hospital(fhir=False, phone=None))

    assert ok is False
    assert sent == []


async def test_the_sms_carries_clinical_triage_but_not_the_patient_name():
    _, sent = await _alert(_hospital(fhir=False))

    body = sent[0][1]
    assert "cardiology" in body and "5" in body and "r1" in body
    assert PATIENT.full_name not in body
    assert PATIENT.emergency_contact_phone not in body


async def test_the_fhir_bundle_describes_an_emergency_encounter_for_the_patient():
    bundle = notifications._build_fhir_bundle(
        ride=RIDE, triage={"specialty": "cardiology", "severity": "5"}, patient=PATIENT
    )

    encounter = bundle["entry"][0]["resource"]
    assert bundle["type"] == "transaction"
    assert encounter["resourceType"] == "Encounter"
    assert encounter["class"]["code"] == "EMER"
    assert encounter["subject"] == {"reference": "Patient/p1"}
    assert encounter["reasonCode"] == [{"text": "cardiology"}]
    assert encounter["meta"]["tag"] == [{"code": "severity-5"}]


async def test_the_fhir_bundle_flags_an_ed_that_reported_full():
    bundle = notifications._build_fhir_bundle(
        ride=RIDE,
        triage={"specialty": "cardiology", "severity": "5"},
        patient=PATIENT,
        ed_full=True,
    )

    assert {"code": "ed-reported-full"} in bundle["entry"][0]["resource"]["meta"]["tag"]
