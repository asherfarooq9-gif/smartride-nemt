import pytest
from httpx import AsyncClient


PATIENT_PAYLOAD = {
    "phone": "+92-300-1111111",
    "password": "secret123",
    "role": "patient",
    "full_name": "Ahmed Khan",
}

DRIVER_PAYLOAD = {
    "phone": "+92-300-2222222",
    "password": "secret123",
    "role": "driver",
    "full_name": "Ali Raza",
    "license_no": "LHR-DL-001",
    "vehicle_plate": "LEA-123",
    "vehicle_type": "ambulette",
}


@pytest.mark.asyncio
async def test_register_patient(client: AsyncClient):
    resp = await client.post("/api/v1/auth/register", json=PATIENT_PAYLOAD)
    assert resp.status_code == 201
    data = resp.json()
    assert data["token_type"] == "bearer"
    assert data["role"] == "patient"
    assert "access_token" in data
    assert "user_id" in data


@pytest.mark.asyncio
async def test_register_duplicate_phone(client: AsyncClient):
    await client.post("/api/v1/auth/register", json=PATIENT_PAYLOAD)
    resp = await client.post("/api/v1/auth/register", json=PATIENT_PAYLOAD)
    assert resp.status_code == 400
    assert "already registered" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_register_driver(client: AsyncClient):
    resp = await client.post("/api/v1/auth/register", json=DRIVER_PAYLOAD)
    assert resp.status_code == 201
    assert resp.json()["role"] == "driver"


@pytest.mark.asyncio
async def test_register_driver_missing_fields(client: AsyncClient):
    payload = {**DRIVER_PAYLOAD, "phone": "+92-300-9999999", "license_no": None}
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    phone = "+92-300-3333333"
    await client.post("/api/v1/auth/register", json={**PATIENT_PAYLOAD, "phone": phone})
    resp = await client.post("/api/v1/auth/login", json={"phone": phone, "password": "secret123"})
    assert resp.status_code == 200
    assert resp.json()["role"] == "patient"


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    phone = "+92-300-4444444"
    await client.post("/api/v1/auth/register", json={**PATIENT_PAYLOAD, "phone": phone})
    resp = await client.post("/api/v1/auth/login", json={"phone": phone, "password": "wrongpass"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_login_unknown_phone(client: AsyncClient):
    resp = await client.post("/api/v1/auth/login", json={"phone": "+92-000-0000000", "password": "x"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_short_password_rejected(client: AsyncClient):
    payload = {**PATIENT_PAYLOAD, "phone": "+92-300-5555555", "password": "ab"}
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422
