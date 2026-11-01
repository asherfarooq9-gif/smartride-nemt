"""A ride a driver accepts by hand must tell the patient and the family (audit F1)."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from app.core import metrics
from tests.test_dispatch_endpoints import _create_emergency, _register

PUSH = "app.services.emergency_dispatch.notify_user"
SMS = "app.services.emergency_dispatch.send_family_sms"


def _count(reason: str) -> float:
    return metrics.dispatch_failures_total.labels(reason=reason)._value.get()


async def _accept(client: AsyncClient, driver_token: str, phone: str):
    patient_token = await _register(client, phone, "patient")
    ride_id = await _create_emergency(client, patient_token)
    response = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    return ride_id, response


@pytest.mark.asyncio
async def test_manual_accept_pushes_the_patient_and_texts_the_family(
    client, verified_driver_token
):
    with (
        patch(PUSH, new=AsyncMock(return_value=True)) as push,
        patch(SMS, new=AsyncMock(return_value=True)) as sms,
    ):
        ride_id, r = await _accept(client, verified_driver_token, "+92300730201")

    assert r.status_code == 200, r.text
    push.assert_awaited_once()
    assert push.await_args.kwargs["patient_id"] is not None
    assert push.await_args.kwargs["data"] == {"ride_id": ride_id}
    sms.assert_awaited_once()
    assert str(sms.await_args.kwargs["ride"].id) == ride_id


@pytest.mark.asyncio
async def test_an_undelivered_patient_push_is_counted_and_keeps_the_accept(
    client, verified_driver_token
):
    before = _count("patient_not_notified")
    with (
        patch(PUSH, new=AsyncMock(return_value=False)),
        patch(SMS, new=AsyncMock(return_value=True)),
    ):
        _, r = await _accept(client, verified_driver_token, "+92300730202")

    assert r.status_code == 200, r.text
    assert _count("patient_not_notified") == before + 1


@pytest.mark.asyncio
async def test_crashing_notifications_do_not_fail_the_accept(
    client, verified_driver_token
):
    before = _count("patient_not_notified")
    with (
        patch(PUSH, new=AsyncMock(return_value=True)),
        patch(SMS, new=AsyncMock(side_effect=RuntimeError("boom"))),
    ):
        _, r = await _accept(client, verified_driver_token, "+92300730203")

    assert r.status_code == 200, r.text
    assert _count("patient_not_notified") == before + 1


@pytest.mark.asyncio
async def test_a_rejected_accept_notifies_nobody(client, verified_driver_token):
    with (
        patch(PUSH, new=AsyncMock(return_value=True)) as push,
        patch(SMS, new=AsyncMock(return_value=True)) as sms,
    ):
        ride_id, first = await _accept(client, verified_driver_token, "+92300730204")
        second = await client.post(
            f"/api/v1/rides/{ride_id}/accept",
            headers={"Authorization": f"Bearer {verified_driver_token}"},
        )

    assert first.status_code == 200 and second.status_code == 409
    push.assert_awaited_once()
    sms.assert_awaited_once()
