import pytest
from httpx import AsyncClient


PATIENT_PAYLOAD = {
    "phone": "+923001111111",
    "password": "secret123",
    "role": "patient",
    "full_name": "Ahmed Khan",
}

DRIVER_PAYLOAD = {
    "phone": "+923002222222",
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
    payload = {**DRIVER_PAYLOAD, "phone": "+923009999999", "license_no": None}
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    phone = "+923003333333"
    await client.post("/api/v1/auth/register", json={**PATIENT_PAYLOAD, "phone": phone})
    resp = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": "secret123"}
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "patient"


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    phone = "+923004444444"
    await client.post("/api/v1/auth/register", json={**PATIENT_PAYLOAD, "phone": phone})
    resp = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": "wrongpass"}
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_login_unknown_phone(client: AsyncClient):
    resp = await client.post(
        "/api/v1/auth/login", json={"phone": "+923000000000", "password": "x"}
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_short_password_rejected(client: AsyncClient):
    payload = {**PATIENT_PAYLOAD, "phone": "+923005555555", "password": "ab"}
    resp = await client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_login_wrong_password_returns_standard_error_shape(client: AsyncClient):
    phone = "+923000000000"
    resp = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": "wrong"}
    )
    assert resp.status_code == 401
    body = resp.json()
    assert "detail" in body
    assert "code" in body


@pytest.mark.asyncio
async def test_refresh_returns_new_token(client):
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": "+92300000099",
            "password": "Passw0rd!",
            "role": "patient",
            "full_name": "Refresh User",
        },
    )
    assert resp.status_code == 201
    old_token = resp.json()["access_token"]

    resp2 = await client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {old_token}"},
    )
    assert resp2.status_code == 200
    new_token = resp2.json()["access_token"]
    assert new_token != old_token


@pytest.mark.asyncio
async def test_refresh_rejects_no_token(client):
    resp = await client.post("/api/v1/auth/refresh")
    assert resp.status_code in (401, 403, 422)
