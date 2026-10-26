"""Ride/driver state-machine invariants."""

import pytest
from httpx import AsyncClient

import uuid

from tests.test_dispatch_endpoints import _create_emergency, _register


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _assigned_ride(client: AsyncClient, patient_phone: str, driver_token: str):
    patient_token = await _register(client, patient_phone, "patient")
    ride_id = await _create_emergency(client, patient_token)
    r = await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(driver_token)
    )
    assert r.status_code == 200, r.text
    return patient_token, ride_id


async def _set_ride_status(client, token, ride_id, status):
    return await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": status},
        headers=_auth(token),
    )


async def _driver_status(client, token) -> str:
    return (await client.get("/api/v1/drivers/me", headers=_auth(token))).json()[
        "status"
    ]


async def test_completed_ride_cannot_be_cancelled(client, verified_driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_ride_status(client, verified_driver_token, ride_id, status)
        assert r.status_code == 200, r.text

    r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 400
    detail = (
        await client.get(
            f"/api/v1/rides/{ride_id}", headers=_auth(verified_driver_token)
        )
    ).json()
    assert detail["status"] == "completed"


@pytest.mark.parametrize("status", ["patient_picked_up", "arrived_at_hospital"])
async def test_driver_cannot_cancel_once_the_patient_is_on_board(
    client, verified_driver_token, status
):
    """Cancelling mid-journey would leave the patient stranded with no requeue."""
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    for step in ("driver_en_route", "patient_picked_up", "arrived_at_hospital"):
        r = await _set_ride_status(client, verified_driver_token, ride_id, step)
        assert r.status_code == 200, r.text
        if step == status:
            break

    r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 409, r.text
    assert "dispatch" in r.json()["detail"].lower()
    detail = (
        await client.get(
            f"/api/v1/rides/{ride_id}", headers=_auth(verified_driver_token)
        )
    ).json()
    assert detail["status"] == status


async def test_admin_can_still_cancel_a_ride_with_the_patient_on_board(
    client, verified_driver_token, admin_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    for step in ("driver_en_route", "patient_picked_up"):
        r = await _set_ride_status(client, verified_driver_token, ride_id, step)
        assert r.status_code == 200, r.text

    r = await _set_ride_status(client, admin_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"


async def test_patient_cancel_after_assignment_frees_the_driver(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    assert await _driver_status(client, verified_driver_token) == "busy"

    r = await _set_ride_status(client, patient_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert await _driver_status(client, verified_driver_token) == "available"


async def test_driver_cannot_go_available_while_on_a_ride(
    client, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    r = await client.patch(
        "/api/v1/drivers/status",
        json={"status": "available"},
        headers=_auth(verified_driver_token),
    )
    assert r.status_code == 409, r.text
    assert await _driver_status(client, verified_driver_token) == "busy"

    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        await _set_ride_status(client, verified_driver_token, ride_id, status)
    r = await client.patch(
        "/api/v1/drivers/status",
        json={"status": "available"},
        headers=_auth(verified_driver_token),
    )
    assert r.status_code == 200, r.text
