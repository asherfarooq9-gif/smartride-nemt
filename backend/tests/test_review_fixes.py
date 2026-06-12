"""
Regression tests for the security/correctness fixes from the full code review:
- admin wallet top-up targets the specified driver
- ride status authorization uses held roles + ownership, not active portal
- pending rides include hospital_name
"""

import uuid

import pytest
from httpx import AsyncClient


async def _register(client: AsyncClient, phone: str, role: str, **extra) -> str:
    payload = {
        "phone": phone,
        "password": "pass1234",
        "role": role,
        "full_name": "T",
        **extra,
    }
    r = await client.post("/api/v1/auth/register", json=payload)
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _driver_extra() -> dict:
    uid = uuid.uuid4().hex[:8]
    return {
        "license_no": f"FX-{uid}",
        "vehicle_plate": f"FX-{uid[:6]}",
        "vehicle_type": "sedan",
    }


PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


@pytest.mark.asyncio
async def test_admin_topup_credits_target_driver(client: AsyncClient, admin_token: str):
    driver_token = await _register(client, "+92300750001", "driver", **_driver_extra())
    me = await client.get("/api/v1/drivers/me", headers=_auth(driver_token))
    driver_id = me.json()["id"]
    balance_before = me.json()["wallet_balance_pkr"]

    r = await client.post(
        f"/api/v1/drivers/{driver_id}/wallet/topup",
        json={"amount_pkr": 500, "payment_method": "jazzcash"},
        headers=_auth(admin_token),
    )
    assert r.status_code == 200, r.text
    assert r.json()["id"] == driver_id
    assert r.json()["wallet_balance_pkr"] == balance_before + 500


@pytest.mark.asyncio
async def test_topup_requires_admin(client: AsyncClient):
    driver_token = await _register(client, "+92300750002", "driver", **_driver_extra())
    me = await client.get("/api/v1/drivers/me", headers=_auth(driver_token))
    driver_id = me.json()["id"]

    r = await client.post(
        f"/api/v1/drivers/{driver_id}/wallet/topup",
        json={"amount_pkr": 500, "payment_method": "jazzcash"},
        headers=_auth(driver_token),
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_patient_cannot_cancel_another_patients_ride(client: AsyncClient):
    owner = await _register(client, "+92300750003", "patient")
    other = await _register(client, "+92300750004", "patient")

    from unittest.mock import AsyncMock, patch

    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "chest pain"},
            headers=_auth(owner),
        )
    ride_id = r.json()["id"]

    r = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(other),
    )
    assert r.status_code == 403

    # The owner can cancel their own ride.
    r = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(owner),
    )
    assert r.status_code == 200
    assert r.json()["status"] == "cancelled"


@pytest.mark.asyncio
async def test_multirole_user_can_cancel_own_ride_from_driver_portal(
    client: AsyncClient,
):
    """A patient+driver account in driver portal must still manage its own
    patient ride — the old code branched on the active portal and broke this."""
    phone = "+92300750005"
    await _register(client, phone, "patient")
    r = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": "pass1234"}
    )
    token = r.json()["access_token"]

    r = await client.post(
        "/api/v1/auth/add-role",
        json={"role": "driver", **_driver_extra()},
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text

    from unittest.mock import AsyncMock, patch

    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        ride = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "fall"},
            headers=_auth(token),
        )
    ride_id = ride.json()["id"]

    # Switch active portal to driver — ownership, not portal, must decide.
    r = await client.post(
        "/api/v1/auth/switch-role", json={"active_role": "driver"}, headers=_auth(token)
    )
    assert r.status_code == 200, r.text
    driver_portal_token = r.json()["access_token"]

    r = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(driver_portal_token),
    )
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"
