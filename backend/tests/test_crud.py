import pytest
from httpx import AsyncClient


async def _register_and_token(client: AsyncClient, phone: str, role: str, **extra) -> str:
    payload = {
        "phone": phone,
        "password": "secret123",
        "role": role,
        "full_name": "Test User",
        **extra,
    }
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()["access_token"]


# ── Patient ──────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_patient_get_me(client: AsyncClient):
    token = await _register_and_token(client, "+92-311-1000001", "patient")
    resp = await client.get("/api/v1/patients/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["full_name"] == "Test User"
    assert data["phone"] == "+92-311-1000001"


@pytest.mark.asyncio
async def test_patient_update_me(client: AsyncClient):
    token = await _register_and_token(client, "+92-311-1000002", "patient")
    resp = await client.patch(
        "/api/v1/patients/me",
        json={"mobility_needs": "wheelchair"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["mobility_needs"] == "wheelchair"


@pytest.mark.asyncio
async def test_patient_me_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/patients/me")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_driver_cannot_access_patient_me(client: AsyncClient):
    token = await _register_and_token(
        client, "+92-311-1000003", "driver",
        license_no="LHR-DL-900", vehicle_plate="AAA-900", vehicle_type="ambulette"
    )
    resp = await client.get("/api/v1/patients/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 403


# ── Driver ───────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_driver_get_me(client: AsyncClient):
    token = await _register_and_token(
        client, "+92-311-2000001", "driver",
        license_no="LHR-DL-200", vehicle_plate="BBB-200", vehicle_type="sedan"
    )
    resp = await client.get("/api/v1/drivers/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["vehicle_type"] == "sedan"
    assert data["is_verified"] is False
    assert data["status"] == "offline"


@pytest.mark.asyncio
async def test_driver_update_status(client: AsyncClient):
    token = await _register_and_token(
        client, "+92-311-2000002", "driver",
        license_no="LHR-DL-201", vehicle_plate="BBB-201", vehicle_type="van"
    )
    resp = await client.patch(
        "/api/v1/drivers/status",
        json={"status": "available"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "available"


@pytest.mark.asyncio
async def test_driver_update_location(client: AsyncClient):
    token = await _register_and_token(
        client, "+92-311-2000003", "driver",
        license_no="LHR-DL-202", vehicle_plate="BBB-202", vehicle_type="van"
    )
    resp = await client.post(
        "/api/v1/drivers/location",
        json={"lat": 33.7215, "lng": 73.0433},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["current_lat"] == pytest.approx(33.7215, rel=1e-4)
    assert data["last_seen_at"] is not None


# ── Hospitals ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_list_hospitals_public(client: AsyncClient):
    resp = await client.get("/api/v1/hospitals")
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert isinstance(data["total"], int)


@pytest.mark.asyncio
async def test_get_hospital_not_found(client: AsyncClient):
    resp = await client.get("/api/v1/hospitals/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_admin_create_hospital(client: AsyncClient, admin_token: str):
    payload = {
        "name": "Test Hospital",
        "address": "123 Main St",
        "city": "Islamabad",
        "lat": 33.6844,
        "lng": 73.0479,
        "specialties": ["cardiology", "neurology"],
        "ed_capacity": 100,
    }
    resp = await client.post(
        "/api/v1/hospitals",
        json=payload,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Test Hospital"
    assert "id" in data


@pytest.mark.asyncio
async def test_patient_cannot_create_hospital(client: AsyncClient):
    token = await _register_and_token(client, "+92-311-9000002", "patient")
    resp = await client.post(
        "/api/v1/hospitals",
        json={"name": "X", "address": "Y", "city": "Z", "lat": 0, "lng": 0},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403
