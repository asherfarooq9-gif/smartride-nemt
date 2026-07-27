"""Driver dispatch endpoint tests: GET /rides/pending, POST /rides/{id}/accept."""

import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.models import Driver, DriverStatus, Ride, RideStatus


PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


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


async def _create_emergency(client: AsyncClient, token: str) -> str:
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "chest pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest_asyncio.fixture
async def verified_driver_token(client: AsyncClient, db: AsyncSession) -> str:
    uid = uuid.uuid4().hex[:8]
    # Phone must be digits-only to pass the registration validator.
    digits = str(uuid.uuid4().int)[:7]
    token = await _register(
        client,
        f"+92300{digits}",
        "driver",
        license_no=f"DV-{uid}",
        vehicle_plate=f"DV-{uid[:6]}",
        vehicle_type="sedan",
    )
    result = await db.execute(
        select(Driver).order_by(Driver.created_at.desc()).limit(1)
    )
    driver = result.scalar_one()
    driver.is_verified = True
    await db.commit()
    return token


@pytest.mark.asyncio
async def test_pending_rides_returns_unassigned(
    client: AsyncClient, verified_driver_token: str
):
    patient_token = await _register(client, "+92300730010", "patient")
    await _create_emergency(client, patient_token)

    r = await client.get(
        "/api/v1/rides/pending",
        headers={"Authorization": f"Bearer {verified_driver_token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["total"] >= 1
    for ride in data["items"]:
        assert ride["driver_id"] is None
        assert ride["status"] == "pending"


@pytest.mark.asyncio
async def test_unverified_driver_cannot_see_pending(
    client: AsyncClient, db: AsyncSession
):
    token = await _register(
        client,
        "+92300730002",
        "driver",
        license_no="DV-LIC-002",
        vehicle_plate="DV-002",
        vehicle_type="van",
    )
    r = await client.get(
        "/api/v1/rides/pending", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_accept_assigns_ride(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    patient_token = await _register(client, "+92300730011", "patient")
    ride_id = await _create_emergency(client, patient_token)

    r = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {verified_driver_token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "driver_assigned"
    assert data["driver_id"] is not None


@pytest.mark.asyncio
async def test_accept_second_driver_gets_409(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    """Second driver accepting the same ride must get 409."""
    # Create a second verified driver
    token2 = await _register(
        client,
        "+92300730003",
        "driver",
        license_no="DV-LIC-003",
        vehicle_plate="DV-003",
        vehicle_type="sedan",
    )
    result = await db.execute(
        select(Driver).order_by(Driver.created_at.desc()).limit(1)
    )
    driver2 = result.scalar_one()
    driver2.is_verified = True
    await db.commit()

    patient_token = await _register(client, "+92300730012", "patient")
    ride_id = await _create_emergency(client, patient_token)

    # First accept succeeds
    r1 = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {verified_driver_token}"},
    )
    assert r1.status_code == 200

    # Second accept must conflict
    r2 = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert r2.status_code == 409


@pytest.mark.asyncio
async def test_accept_marks_driver_busy(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    """Accepting a ride must claim the driver so dispatch stops offering them work."""
    patient_token = await _register(client, "+92300730014", "patient")
    ride_id = await _create_emergency(client, patient_token)

    r = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {verified_driver_token}"},
    )
    assert r.status_code == 200

    driver = (
        await db.execute(
            select(Driver).where(Driver.id == uuid.UUID(r.json()["driver_id"]))
        )
    ).scalar_one()
    await db.refresh(driver)
    assert driver.status == DriverStatus.busy


@pytest.mark.asyncio
async def test_busy_driver_cannot_accept_second_ride(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    """A driver already transporting a patient must not double-book onto a
    second emergency, and the rejected ride must stay claimable by someone else."""
    patient_token = await _register(client, "+92300730015", "patient")
    first_ride = await _create_emergency(client, patient_token)
    second_ride = await _create_emergency(client, patient_token)

    headers = {"Authorization": f"Bearer {verified_driver_token}"}

    r1 = await client.post(f"/api/v1/rides/{first_ride}/accept", headers=headers)
    assert r1.status_code == 200

    r2 = await client.post(f"/api/v1/rides/{second_ride}/accept", headers=headers)
    assert r2.status_code == 409
    assert "already assigned" in r2.json()["detail"]

    # The failed claim must be rolled back, not left half-applied.
    ride = (
        await db.execute(select(Ride).where(Ride.id == uuid.UUID(second_ride)))
    ).scalar_one()
    await db.refresh(ride)
    assert ride.driver_id is None
    assert ride.status == RideStatus.pending
    assert ride.driver_assigned_at is None


@pytest.mark.asyncio
async def test_unverified_driver_cannot_accept(client: AsyncClient, db: AsyncSession):
    token = await _register(
        client,
        "+92300730004",
        "driver",
        license_no="DV-LIC-004",
        vehicle_plate="DV-004",
        vehicle_type="van",
    )
    patient_token = await _register(client, "+92300730013", "patient")
    ride_id = await _create_emergency(client, patient_token)

    r = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 403
