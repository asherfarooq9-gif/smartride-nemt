"""Notifications must not stall the event loop: dispatch and login share it."""

import asyncio
import time
from types import SimpleNamespace
from unittest.mock import patch

from app.core.security import hash_password_async, verify_password_async
from app.services import notifications

PATIENT = SimpleNamespace(
    id="p1", full_name="Test Patient", emergency_contact_phone="+923001234567"
)
DRIVER = SimpleNamespace(full_name="Test Driver", vehicle_plate="ABC-123")
RIDE = SimpleNamespace(id="r1")


async def _ticks_while(coro, interval: float = 0.01) -> int:
    """Count how often the loop can run a timer while `coro` is in flight."""
    ticks = 0
    done = asyncio.Event()

    async def ticker():
        nonlocal ticks
        while not done.is_set():
            await asyncio.sleep(interval)
            ticks += 1

    task = asyncio.create_task(ticker())
    await coro
    done.set()
    await task
    return ticks


async def test_family_sms_does_not_block_the_event_loop():
    def slow_send(to, body):
        time.sleep(0.3)  # stands in for a Twilio HTTP round trip

    with patch.object(notifications, "_send_sms", slow_send):
        ticks = await _ticks_while(
            notifications.send_family_sms(
                patient=PATIENT, ride=RIDE, driver=DRIVER, hospital_name="PIMS"
            )
        )

    # A blocked loop manages ~1 tick in 0.3s; a free one manages ~30.
    assert ticks >= 10, f"event loop was blocked (ticks={ticks})"


async def test_sms_is_skipped_without_twilio_credentials():
    with patch.object(notifications.settings, "TWILIO_ACCOUNT_SID", ""):
        notifications._send_sms("+923001234567", "body")  # must not raise


async def test_hospital_alert_falls_back_to_sms_when_fhir_fails():
    hospital = SimpleNamespace(
        has_fhir=True,
        fhir_endpoint="https://fhir.invalid/bundle",
        coordinator_phone="+923009998888",
        ed_full=False,
    )
    sent = []

    class FailingClient:
        def __init__(self, *a, **k): ...
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            raise ConnectionError("fhir down")

    with (
        patch.object(notifications.httpx, "AsyncClient", FailingClient),
        patch.object(
            notifications, "_send_sms", lambda to, body: sent.append(to) or True
        ),
    ):
        await notifications.send_hospital_alert(
            ride=RIDE,
            triage={"specialty": "cardiology", "severity": "5"},
            hospital=hospital,
            patient=PATIENT,
        )

    assert sent == ["+923009998888"]


async def test_hospital_sms_says_when_the_ed_reports_full():
    sent = []

    async def send(ed_full: bool) -> str:
        sent.clear()
        hospital = SimpleNamespace(
            has_fhir=False,
            fhir_endpoint=None,
            coordinator_phone="+923009998888",
            ed_full=ed_full,
        )
        with patch.object(
            notifications, "_send_sms", lambda to, body: sent.append(body) or True
        ):
            await notifications.send_hospital_alert(
                ride=RIDE,
                triage={"specialty": "cardiology", "severity": "5"},
                hospital=hospital,
                patient=PATIENT,
            )
        return sent[0]

    assert "ED FULL" in await send(True)
    assert "ED FULL" not in await send(False)


async def test_password_hashing_does_not_block_the_event_loop():
    ticks = await _ticks_while(hash_password_async("correct horse battery"))
    assert ticks >= 3, f"bcrypt blocked the event loop (ticks={ticks})"

    hashed = await hash_password_async("pw-12345678")
    assert await verify_password_async("pw-12345678", hashed)
    assert not await verify_password_async("wrong", hashed)
