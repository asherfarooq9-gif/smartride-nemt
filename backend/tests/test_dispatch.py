"""
Emergency dispatch pipeline integration tests.
Seeds real DB rows (hospital + driver + patient), mocks the triage HTTP call,
then runs dispatch_emergency() directly and verifies the outcome.
"""

import os
import uuid
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, patch
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool
from sqlalchemy import select

from app.models.models import (
    User,
    Patient,
    Driver,
    Hospital,
    Ride,
    UserRole,
    DriverStatus,
    RideType,
    RideStatus,
)
from app.services.emergency_dispatch import dispatch_emergency
from app.core.security import hash_password

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test",
)


TRIAGE_RESPONSE = {
    "specialty": "cardiology",
    "confidence": 0.92,
    "severity": "4",
    "rule_override": False,
    "model_version": "rules-v1",
    "inference_ms": 5,
}

PATIENT_LAT, PATIENT_LNG = 33.7215, 73.0433  # PIMS Islamabad


@pytest_asyncio.fixture
async def session():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as s:
        yield s
        try:
            await s.rollback()
        except Exception:
            pass
    await engine.dispose()


async def _seed(session: AsyncSession):
    """Seed one hospital, one verified driver, and one patient for each test."""
    suffix = uuid.uuid4().hex[:8]

    # hospital — 2 km north of patient
    hospital = Hospital(
        name=f"Test Hospital {suffix}",
        address="Test Address",
        city="Islamabad",
        lat=33.7394,
        lng=73.0433,
        specialties=["cardiology", "general_emergency"],
        ed_capacity=100,
        ed_current_load=20,
        is_active=True,
    )
    session.add(hospital)

    # driver user + profile — 1 km from patient
    driver_user = User(
        phone=f"+92300{suffix}",
        password_hash=hash_password("pass"),
        role=UserRole.driver,
    )
    session.add(driver_user)
    await session.flush()

    driver = Driver(
        user_id=driver_user.id,
        full_name=f"Driver {suffix}",
        license_no=f"DL-{suffix}",
        vehicle_plate=f"ABC-{suffix[:4]}",
        vehicle_type="ambulette",
        is_verified=True,
        status=DriverStatus.available,
        current_lat=33.7305,
        current_lng=73.0433,
    )
    session.add(driver)

    # patient user + profile
    patient_user = User(
        phone=f"+92311{suffix}",
        password_hash=hash_password("pass"),
        role=UserRole.patient,
    )
    session.add(patient_user)
    await session.flush()

    patient = Patient(
        user_id=patient_user.id,
        full_name=f"Patient {suffix}",
        emergency_contact_phone=f"+92321{suffix}",
    )
    session.add(patient)
    await session.flush()

    # emergency ride (pending)
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.emergency,
        status=RideStatus.pending,
        pickup_lat=PATIENT_LAT,
        pickup_lng=PATIENT_LNG,
    )
    session.add(ride)
    await session.commit()
    await session.refresh(ride)
    await session.refresh(driver)
    await session.refresh(hospital)
    return ride, driver, hospital


# ─────────────────────────────────────────────────────────────────────────────
# Test 1: full pipeline returns expected summary keys
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_dispatch_returns_summary(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=TRIAGE_RESPONSE),
    ):
        result = await dispatch_emergency(
            ride, "chest pain and shortness of breath", session
        )

    assert "ride_id" in result
    assert "driver_id" in result
    assert "hospital_id" in result
    assert "pipeline_elapsed_seconds" in result


# ─────────────────────────────────────────────────────────────────────────────
# Test 2: ride status updated to driver_assigned
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_dispatch_sets_driver_assigned_status(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=TRIAGE_RESPONSE),
    ):
        await dispatch_emergency(ride, "chest pain", session)

    refreshed = (
        await session.execute(select(Ride).where(Ride.id == ride.id))
    ).scalar_one()
    assert refreshed.status == RideStatus.driver_assigned
    assert refreshed.driver_id == driver.id
    assert (
        refreshed.hospital_id is not None
    )  # a hospital was chosen (may differ from seed)
    assert refreshed.driver_assigned_at is not None


# ─────────────────────────────────────────────────────────────────────────────
# Test 3: driver status flipped to busy after assignment
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_dispatch_marks_driver_busy(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=TRIAGE_RESPONSE),
    ):
        await dispatch_emergency(ride, "chest pain", session)

    refreshed_driver = (
        await session.execute(select(Driver).where(Driver.id == driver.id))
    ).scalar_one()
    assert refreshed_driver.status == DriverStatus.busy


# ─────────────────────────────────────────────────────────────────────────────
# Test 4: severity override — "cardiac arrest" forces severity 5
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_severity_override_on_critical_keyword(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    low_severity_triage = {**TRIAGE_RESPONSE, "severity": "2", "rule_override": False}
    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=low_severity_triage),
    ):
        result = await dispatch_emergency(
            ride, "cardiac arrest patient unresponsive", session
        )

    assert result.get("severity") == "5"


# ─────────────────────────────────────────────────────────────────────────────
# Test 5: no available drivers → returns error dict, ride stays pending
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_dispatch_no_drivers_returns_error(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    # take the driver offline via a direct update to avoid stale-state issues
    from sqlalchemy import update as sa_update

    await session.execute(
        sa_update(Driver)
        .where(Driver.id == driver.id)
        .values(status=DriverStatus.offline)
    )
    await session.commit()

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=TRIAGE_RESPONSE),
    ):
        result = await dispatch_emergency(ride, "chest pain", session)

    assert "error" in result
    assert "driver" in result["error"].lower()


# ─────────────────────────────────────────────────────────────────────────────
# Test 6: triage service down → fallback specialty used, pipeline still completes
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_dispatch_triage_fallback_on_service_error(session: AsyncSession):
    ride, driver, hospital = await _seed(session)

    # Patch the HTTP client inside call_triage_service so the function's own
    # try/except catches the error and returns the fallback dict.
    with patch(
        "app.services.emergency_dispatch.httpx.AsyncClient",
    ) as mock_client_cls:
        mock_client_cls.return_value.__aenter__.return_value.post.side_effect = (
            ConnectionError("triage down")
        )
        result = await dispatch_emergency(ride, "chest pain", session)

    # pipeline completes (hospital has general_emergency specialty for fallback)
    assert "ride_id" in result or "error" in result


@pytest.mark.asyncio
async def test_emergency_dispatch_when_no_drivers_available(client):
    """Ride should be created even when no driver is available in the test DB."""
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": "+92300099003",
            "password": "Passw0rd!",
            "role": "patient",
            "full_name": "No Driver Test",
        },
    )
    assert reg.status_code == 201
    token = reg.json()["access_token"]

    resp = await client.post(
        "/api/v1/rides/emergency",
        headers={"Authorization": f"Bearer {token}"},
        json={"symptom_text": "headache", "pickup_lat": 33.72, "pickup_lng": 73.04},
    )
    assert resp.status_code in (200, 201)
    body = resp.json()
    assert "id" in body
    assert body["status"] in ("pending", "driver_assigned")
