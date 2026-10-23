"""Ride transitions must serialize: two sessions cannot both win one ride."""

import asyncio

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.models import Driver, DriverStatus, Ride, RideStatus, WalletEntry
from app.schemas.rides import RideStatusUpdate
from app.services import ride_service
from tests.conftest import TEST_DATABASE_URL
from tests.test_dispatch_endpoints import _create_emergency, _register
from tests.test_ride_lifecycle import _assigned_ride, _auth, _phone, _set_ride_status

BLOCK_GRACE_SECONDS = 0.4


@pytest.fixture
async def sessions():
    """Two independent sessions (own connections), like two concurrent requests."""
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as first, factory() as second:
        yield first, second
    await engine.dispose()


async def _arrived_ride(client, driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), driver_token)
    for status in ("driver_en_route", "patient_picked_up", "arrived_at_hospital"):
        r = await _set_ride_status(client, driver_token, ride_id, status)
        assert r.status_code == 200, r.text
    return ride_id


async def _final_state(db, ride_id):
    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    commissions = (
        await db.execute(
            select(func.count()).where(
                WalletEntry.ride_id == ride_id, WalletEntry.kind == "commission"
            )
        )
    ).scalar_one()
    driver = (
        await db.execute(select(Driver).where(Driver.id == ride.driver_id))
    ).scalar_one()
    return ride.status, commissions, driver.status


async def _race(first, second, ride_id, first_move, second_move):
    """`first` holds the ride lock while `second` (which read the ride before the
    lock, like a request that has not reached the service yet) tries to move it.
    """
    stale = await ride_service.get_ride_by_id(ride_id, second)
    held = await ride_service.get_ride_by_id(ride_id, first)
    await ride_service._lock_ride(first, held)

    loser = asyncio.create_task(second_move(second, stale))
    await asyncio.sleep(BLOCK_GRACE_SECONDS)
    assert not loser.done(), "second transition did not wait for the ride lock"

    await first_move(first, held)
    return loser


async def _driver_completes(session, ride):
    driver = (
        await session.execute(select(Driver).where(Driver.id == ride.driver_id))
    ).scalar_one()
    return await ride_service.update_ride_status(
        ride, RideStatusUpdate(status=RideStatus.completed), "driver", session, driver=driver
    )


async def _admin_cancels(session, ride):
    return await ride_service.update_ride_status(
        ride, RideStatusUpdate(status=RideStatus.cancelled), "admin", session
    )


async def test_admin_cancel_cannot_overwrite_a_completed_ride(
    client, db, sessions, verified_driver_token
):
    ride_id = await _arrived_ride(client, verified_driver_token)
    first, second = sessions

    loser = await _race(first, second, ride_id, _driver_completes, _admin_cancels)

    with pytest.raises(HTTPException) as lost:
        await loser
    assert lost.value.status_code == 400
    assert await _final_state(db, ride_id) == (
        RideStatus.completed,
        1,
        DriverStatus.available,
    )


async def test_driver_cannot_complete_a_ride_cancelled_first(
    client, db, sessions, verified_driver_token
):
    ride_id = await _arrived_ride(client, verified_driver_token)
    first, second = sessions

    loser = await _race(first, second, ride_id, _admin_cancels, _driver_completes)

    with pytest.raises(HTTPException) as lost:
        await loser
    assert lost.value.status_code == 400
    assert await _final_state(db, ride_id) == (
        RideStatus.cancelled,
        0,
        DriverStatus.available,
    )


async def test_cancelling_an_old_ride_does_not_free_a_driver_on_another_ride(
    client, db, admin_token, verified_driver_token
):
    _, old_ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    other_patient = await _register(client, _phone(), "patient")
    other_ride_id = await _create_emergency(client, other_patient)
    driver_id = (
        await db.execute(select(Ride.driver_id).where(Ride.id == old_ride_id))
    ).scalar_one()
    await db.execute(
        update(Ride)
        .where(Ride.id == other_ride_id)
        .values(driver_id=driver_id, status=RideStatus.driver_assigned)
    )
    await db.commit()

    r = await client.patch(
        f"/api/v1/rides/{old_ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(admin_token),
    )

    assert r.status_code == 200, r.text
    db.expire_all()
    status = (
        await db.execute(select(Driver.status).where(Driver.id == driver_id))
    ).scalar_one()
    assert status == DriverStatus.busy


async def test_requeued_ride_gets_a_fresh_queued_at(client, db, verified_driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    before = (
        await db.execute(select(Ride.queued_at).where(Ride.id == ride_id))
    ).scalar_one()

    r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    assert ride.status == RideStatus.pending
    assert ride.queued_at > before


async def test_two_simultaneous_ratings_only_one_wins(
    client, db, sessions, verified_driver_token
):
    ride_id = await _arrived_ride(client, verified_driver_token)
    await _set_ride_status(client, verified_driver_token, ride_id, "completed")
    patient_id = (
        await db.execute(select(Ride.patient_id).where(Ride.id == ride_id))
    ).scalar_one()
    first, second = sessions

    results = await asyncio.gather(
        ride_service.rate_completed_ride(first, ride_id, patient_id, 5, "great"),
        ride_service.rate_completed_ride(second, ride_id, patient_id, 1, "bad"),
        return_exceptions=True,
    )

    winners = [r for r in results if isinstance(r, Ride)]
    losers = [r for r in results if isinstance(r, HTTPException)]
    assert len(winners) == 1
    assert [e.status_code for e in losers] == [409]
    db.expire_all()
    stored = (
        await db.execute(select(Ride.patient_rating).where(Ride.id == ride_id))
    ).scalar_one()
    assert stored == winners[0].patient_rating


async def test_rating_outside_one_to_five_is_rejected_by_the_database(
    client, db, verified_driver_token
):
    from sqlalchemy.exc import IntegrityError

    ride_id = await _arrived_ride(client, verified_driver_token)
    await _set_ride_status(client, verified_driver_token, ride_id, "completed")

    with pytest.raises(IntegrityError):
        await db.execute(update(Ride).where(Ride.id == ride_id).values(patient_rating=6))
    await db.rollback()
