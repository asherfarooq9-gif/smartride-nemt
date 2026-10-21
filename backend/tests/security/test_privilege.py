"""Ordinary users must not give themselves more power or read other people's data."""

import uuid

import pytest
from sqlalchemy import select

from app.models.models import Driver
from tests.test_dispatch_endpoints import _create_emergency
from tests.test_review_fixes import _auth, _driver_extra, _register
from tests.test_ride_lifecycle import _assigned_ride, _set_ride_status


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


@pytest.mark.parametrize("field", ["role", "roles"])
async def test_nobody_can_self_register_as_admin(client, field):
    value = "admin" if field == "role" else ["admin"]
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": _phone(),
            "password": "pass1234",
            "full_name": "x",
            field: value,
        },
    )
    assert r.status_code in (403, 422)


async def test_cannot_add_or_switch_to_the_admin_role(client):
    token = await _register(client, _phone(), "patient")
    add = await client.post(
        "/api/v1/auth/add-role", json={"role": "admin"}, headers=_auth(token)
    )
    switch = await client.post(
        "/api/v1/auth/switch-role", json={"active_role": "admin"}, headers=_auth(token)
    )
    assert add.status_code == 403
    assert switch.status_code == 403


async def test_driver_cannot_verify_themselves_or_edit_their_wallet(client, db):
    token = await _register(client, _phone(), "driver", **_driver_extra())
    r = await client.patch(
        "/api/v1/drivers/me",
        json={
            "full_name": "Eve",
            "is_verified": True,
            "wallet_balance_pkr": 99999,
            "status": "available",
        },
        headers=_auth(token),
    )
    assert r.status_code == 200
    me = (await client.get("/api/v1/drivers/me", headers=_auth(token))).json()
    assert me["is_verified"] is False
    assert me["wallet_balance_pkr"] == 0
    driver = (
        await db.execute(select(Driver).where(Driver.id == me["id"]))
    ).scalar_one()
    assert driver.is_verified is False


async def test_unverified_driver_cannot_see_or_take_rides(client):
    token = await _register(client, _phone(), "driver", **_driver_extra())
    patient = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient)
    pending = await client.get("/api/v1/rides/pending", headers=_auth(token))
    accept = await client.post(f"/api/v1/rides/{ride_id}/accept", headers=_auth(token))
    assert pending.status_code == 403
    assert accept.status_code == 403


async def test_patient_cannot_read_or_change_another_patients_ride(client):
    owner = await _register(client, _phone(), "patient")
    stranger = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, owner)
    for path in (f"/api/v1/rides/{ride_id}", f"/api/v1/rides/{ride_id}/detail"):
        assert (await client.get(path, headers=_auth(stranger))).status_code == 403
    rate = await client.post(
        f"/api/v1/rides/{ride_id}/rate", json={"rating": 1}, headers=_auth(stranger)
    )
    assert rate.status_code in (403, 404)


async def test_driver_cannot_read_a_ride_that_is_not_theirs(
    client, verified_driver_token
):
    patient = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient)
    r = await client.get(
        f"/api/v1/rides/{ride_id}", headers=_auth(verified_driver_token)
    )
    assert r.status_code == 403


async def test_driver_cannot_move_another_drivers_ride_through_its_states(
    client, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    other = await _register(client, _phone(), "driver", **_driver_extra())
    r = await _set_ride_status(client, other, ride_id, "driver_en_route")
    assert r.status_code == 403


async def test_patient_cannot_use_the_driver_or_admin_apis(client):
    token = await _register(client, _phone(), "patient")
    for method, path in (
        ("GET", "/api/v1/drivers/wallet"),
        ("POST", "/api/v1/drivers/location"),
        ("GET", "/api/v1/patients"),
        ("GET", "/api/v1/rides"),
        ("GET", "/api/v1/analytics/summary"),
    ):
        r = await client.request(method, path, headers=_auth(token), json={})
        assert r.status_code == 403, (path, r.status_code)
