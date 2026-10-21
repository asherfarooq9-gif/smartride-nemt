"""Dispatch must stay correct when other requests change state mid-pipeline."""

import asyncio
from unittest.mock import AsyncMock, patch

import pytest
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.models import Driver, DriverStatus, Ride, RideStatus
from app.services.emergency_dispatch import dispatch_emergency
from tests.conftest import TEST_DATABASE_URL
from tests.test_dispatch import TRIAGE_RESPONSE, _seed


def _factory():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    return engine, async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )


async def _only_this_driver_available(db: AsyncSession, driver_id) -> None:
    """Other tests leave available drivers behind; isolate the one under test."""
    await db.execute(
        update(Driver).where(Driver.id != driver_id).values(status=DriverStatus.offline)
    )
    await db.commit()


@pytest.mark.asyncio
async def test_dispatch_does_not_resurrect_a_cancelled_ride(db: AsyncSession):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await _only_this_driver_available(db, driver_id)

    async def triage_then_patient_cancels(_text):
        engine, factory = _factory()
        async with factory() as other:
            await other.execute(
                update(Ride)
                .where(Ride.id == ride_id)
                .values(status=RideStatus.cancelled)
            )
            await other.commit()
        await engine.dispose()
        return TRIAGE_RESPONSE

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=triage_then_patient_cancels,
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert "error" in result
    db.expire_all()
    stored_ride = (
        await db.execute(select(Ride).where(Ride.id == ride_id))
    ).scalar_one()
    stored_driver = (
        await db.execute(select(Driver).where(Driver.id == driver_id))
    ).scalar_one()
    assert stored_ride.status == RideStatus.cancelled
    assert stored_ride.driver_id is None
    assert stored_driver.status == DriverStatus.available


@pytest.mark.asyncio
async def test_two_simultaneous_emergencies_never_share_a_driver(db: AsyncSession):
    ride_a, driver, _ = await _seed(db)
    ride_b, _other_driver, _ = await _seed(db)
    ride_ids, driver_id = [ride_a.id, ride_b.id], driver.id
    await _only_this_driver_available(db, driver_id)

    engines = []
    sessions = []
    for _ in range(2):
        engine, factory = _factory()
        engines.append(engine)
        sessions.append(factory())
    try:
        with patch(
            "app.services.emergency_dispatch.call_triage_service",
            new=AsyncMock(return_value=dict(TRIAGE_RESPONSE)),
        ):
            results = await asyncio.gather(
                dispatch_emergency(ride_a, "chest pain", sessions[0]),
                dispatch_emergency(ride_b, "chest pain", sessions[1]),
            )
    finally:
        for s in sessions:
            await s.close()
        for e in engines:
            await e.dispose()

    assigned = [r for r in results if "driver_id" in r]
    failed = [r for r in results if "error" in r]
    assert len(assigned) == 1 and len(failed) == 1, results

    db.expire_all()
    rows = (
        (
            await db.execute(
                select(Ride).where(Ride.id.in_(ride_ids), Ride.driver_id == driver_id)
            )
        )
        .scalars()
        .all()
    )
    assert len(rows) == 1


@pytest.mark.asyncio
async def test_a_driver_hundreds_of_km_away_is_not_dispatched(db: AsyncSession):
    ride, driver, _ = await _seed(db)
    driver_id = driver.id
    await _only_this_driver_available(db, driver_id)
    await db.execute(
        update(Driver)
        .where(Driver.id == driver_id)
        .values(current_lat=Driver.current_lat + 5)
    )
    await db.commit()

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=TRIAGE_RESPONSE),
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert "driver" in result["error"].lower()
