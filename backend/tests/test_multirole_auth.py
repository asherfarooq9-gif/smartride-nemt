"""Multi-role (Option A) auth: one account holds patient AND driver roles."""

import pytest
from httpx import AsyncClient

BOTH_PAYLOAD = {
    "phone": "+923011000001",
    "password": "secret123",
    "full_name": "Dual Role User",
    "roles": ["patient", "driver"],
    "license_no": "ISB-DL-900",
    "vehicle_plate": "ISB-900",
    "vehicle_type": "ambulette",
}


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_register_both_roles(client: AsyncClient):
    resp = await client.post("/api/v1/auth/register", json=BOTH_PAYLOAD)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert sorted(data["roles"]) == ["driver", "patient"]
    assert data["active_role"] == "patient"  # first requested role
    assert data["access_token"]


@pytest.mark.asyncio
async def test_me_shows_both_profiles(client: AsyncClient):
    phone = "+923011000002"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            **BOTH_PAYLOAD,
            "phone": phone,
            "license_no": "ISB-DL-901",
            "vehicle_plate": "ISB-901",
        },
    )
    token = reg.json()["access_token"]
    resp = await client.get("/api/v1/auth/me", headers=_auth(token))
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["has_patient_profile"] is True
    assert data["has_driver_profile"] is True
    assert sorted(data["roles"]) == ["driver", "patient"]
    assert data["driver_verified"] is False


@pytest.mark.asyncio
async def test_register_driver_missing_fields_rejected(client: AsyncClient):
    payload = {
        "phone": "+923011000003",
        "password": "secret123",
        "full_name": "No Vehicle",
        "roles": ["driver"],  # missing license/plate/type
    }
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_register_blocks_admin(client: AsyncClient):
    payload = {
        "phone": "+923011000004",
        "password": "secret123",
        "full_name": "Sneaky",
        "roles": ["admin"],
    }
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_add_role_patient_becomes_driver(client: AsyncClient):
    phone = "+923011000005"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": phone,
            "password": "secret123",
            "full_name": "Just Patient",
            "roles": ["patient"],
        },
    )
    token = reg.json()["access_token"]
    assert reg.json()["roles"] == ["patient"]

    resp = await client.post(
        "/api/v1/auth/add-role",
        headers=_auth(token),
        json={
            "role": "driver",
            "license_no": "ISB-DL-905",
            "vehicle_plate": "ISB-905",
            "vehicle_type": "sedan",
        },
    )
    assert resp.status_code == 200, resp.text
    assert sorted(resp.json()["roles"]) == ["driver", "patient"]

    me = await client.get("/api/v1/auth/me", headers=_auth(resp.json()["access_token"]))
    assert me.json()["has_driver_profile"] is True


@pytest.mark.asyncio
async def test_add_existing_role_rejected(client: AsyncClient):
    phone = "+923011000006"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": phone,
            "password": "secret123",
            "full_name": "P",
            "roles": ["patient"],
        },
    )
    token = reg.json()["access_token"]
    resp = await client.post(
        "/api/v1/auth/add-role", headers=_auth(token), json={"role": "patient"}
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_switch_role(client: AsyncClient):
    phone = "+923011000007"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            **BOTH_PAYLOAD,
            "phone": phone,
            "license_no": "ISB-DL-907",
            "vehicle_plate": "ISB-907",
        },
    )
    token = reg.json()["access_token"]
    assert reg.json()["active_role"] == "patient"

    resp = await client.post(
        "/api/v1/auth/switch-role", headers=_auth(token), json={"active_role": "driver"}
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["active_role"] == "driver"


@pytest.mark.asyncio
async def test_switch_to_unheld_role_rejected(client: AsyncClient):
    phone = "+923011000008"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": phone,
            "password": "secret123",
            "full_name": "P",
            "roles": ["patient"],
        },
    )
    token = reg.json()["access_token"]
    resp = await client.post(
        "/api/v1/auth/switch-role", headers=_auth(token), json={"active_role": "driver"}
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_both_role_user_passes_patient_and_driver_rbac(client: AsyncClient):
    phone = "+923011000009"
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            **BOTH_PAYLOAD,
            "phone": phone,
            "license_no": "ISB-DL-909",
            "vehicle_plate": "ISB-909",
        },
    )
    token = reg.json()["access_token"]
    # patient-only endpoint
    p = await client.get("/api/v1/patients/me", headers=_auth(token))
    assert p.status_code == 200, p.text
    # driver-only endpoint
    d = await client.get("/api/v1/drivers/me", headers=_auth(token))
    assert d.status_code == 200, d.text
