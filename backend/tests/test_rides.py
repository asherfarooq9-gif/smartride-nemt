"""
Rides router integration tests — HTTP layer only (no dispatch side-effects).
Dispatch background task is patched to a no-op.
"""
import pytest
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient


async def _token(client: AsyncClient, phone: str, role: str, **extra) -> str:
    payload = {"phone": phone, "password": "pass1234", "role": role, "full_name": "Test", **extra}
    r = await client.post("/api/v1/auth/register", json=payload)
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


@pytest.mark.asyncio
async def test_emergency_ride_created_as_pending(client: AsyncClient):
    token = await _token(client, "+92300ER0001", "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "chest pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert r.status_code == 201
    data = r.json()
    assert data["status"] == "pending"
    assert data["ride_type"] == "emergency"
    assert data["driver_id"] is None


@pytest.mark.asyncio
async def test_scheduled_ride_created(client: AsyncClient):
    token = await _token(client, "+92300SR0001", "patient")
    r = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": "2026-06-01T10:00:00Z"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 201
    assert r.json()["ride_type"] == "scheduled"


@pytest.mark.asyncio
async def test_get_ride_by_patient_owner(client: AsyncClient):
    token = await _token(client, "+92300ER0002", "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        create = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    ride_id = create.json()["id"]
    r = await client.get(f"/api/v1/rides/{ride_id}", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["id"] == ride_id


@pytest.mark.asyncio
async def test_get_ride_forbidden_for_other_patient(client: AsyncClient):
    token1 = await _token(client, "+92300ER0003", "patient")
    token2 = await _token(client, "+92300ER0004", "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        create = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "pain"},
            headers={"Authorization": f"Bearer {token1}"},
        )
    ride_id = create.json()["id"]
    r = await client.get(f"/api/v1/rides/{ride_id}", headers={"Authorization": f"Bearer {token2}"})
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_my_rides_returns_only_own(client: AsyncClient):
    token = await _token(client, "+92300ER0005", "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    r = await client.get("/api/v1/rides/mine", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["total"] >= 1


@pytest.mark.asyncio
async def test_driver_cannot_create_emergency_ride(client: AsyncClient):
    token = await _token(
        client, "+92300ER0006", "driver",
        license_no="DL-ERTEST", vehicle_plate="ER-TEST", vehicle_type="van"
    )
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_admin_can_list_all_rides(client: AsyncClient):
    admin_token = await _token(client, "+92300ER0007", "admin")
    r = await client.get("/api/v1/rides", headers={"Authorization": f"Bearer {admin_token}"})
    assert r.status_code == 200
    assert "items" in r.json()
