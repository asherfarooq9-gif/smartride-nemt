"""Drivers claim booked (scheduled) rides ahead of time, then get them at pickup.

A claim keeps the ride pending and records the driver. Nobody else is offered it.
When its pickup window opens the dispatch loop hands it to the claiming driver; a
driver who cannot take it close to pickup loses the claim and the ride goes back
to normal dispatch.
"""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from sqlalchemy import select, update

from app.core.config import settings
from app.models.models import Driver, DriverStatus, Ride, RideStatus
from app.services import dispatch_loop
from tests.test_review_fixes import _auth, _register

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _driver(client, db, *, lat=33.7315, lng=73.0433, verified=True):
    uid = uuid.uuid4().hex[:8]
    token = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"CL-{uid}",
        vehicle_plate=f"CL-{uid[:6]}",
        vehicle_type="sedan",
    )
    user_id = (await client.get("/api/v1/auth/me", headers=_auth(token))).json()[
        "user_id"
    ]
    drv = (
        await db.execute(select(Driver).where(Driver.user_id == user_id))
    ).scalar_one()
    drv.is_verified = verified
    drv.status = DriverStatus.available
    drv.current_lat, drv.current_lng = lat, lng
    await db.commit()
    return token, drv.id


async def _book(client, *, minutes_ahead: float) -> str:
    patient = await _register(client, _phone(), "patient")
    when = datetime.now(timezone.utc) + timedelta(minutes=minutes_ahead)
    r = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": when.isoformat()},
        headers=_auth(patient),
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _ids(response) -> list[str]:
    return [ride["id"] for ride in response.json()["items"]]


async def _ride(db, ride_id) -> Ride:
    await db.rollback()
    return (
        await db.execute(
            select(Ride)
            .where(Ride.id == ride_id)
            .execution_options(populate_existing=True)
        )
    ).scalar_one()


async def test_open_list_shows_nearby_future_rides_only(client, db):
    token, _ = await _driver(client, db)
    near = await _book(client, minutes_ahead=60 * 48)
    far_driver, _ = await _driver(client, db, lat=34.5, lng=74.0)

    mine = await client.get("/api/v1/rides/scheduled/open", headers=_auth(token))
    theirs = await client.get("/api/v1/rides/scheduled/open", headers=_auth(far_driver))

    assert near in _ids(mine)
    assert near not in _ids(theirs)


async def test_a_claim_keeps_the_ride_pending_and_hides_it_from_others(client, db):
    me, _ = await _driver(client, db)
    other, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)

    out = await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    assert out.status_code == 200, out.text
    ride = await _ride(db, ride_id)
    assert ride.status == RideStatus.pending
    assert ride.claimed_driver_id is not None
    assert ride_id in _ids(
        await client.get("/api/v1/rides/scheduled/claimed", headers=_auth(me))
    )
    assert ride_id not in _ids(
        await client.get("/api/v1/rides/scheduled/open", headers=_auth(other))
    )
    assert ride_id not in _ids(
        await client.get("/api/v1/rides/scheduled/open", headers=_auth(me))
    )


async def test_two_concurrent_claims_have_exactly_one_winner(isolated_client, db):
    one, _ = await _driver(isolated_client, db)
    two, _ = await _driver(isolated_client, db)
    ride_id = await _book(isolated_client, minutes_ahead=60 * 48)

    a, b = await asyncio.gather(
        isolated_client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(one)),
        isolated_client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(two)),
    )

    assert sorted([a.status_code, b.status_code]) == [200, 409]


async def test_a_driver_cannot_hold_more_than_the_claim_limit(client, db, monkeypatch):
    monkeypatch.setattr(settings, "MAX_SCHEDULED_CLAIMS", 2)
    me, _ = await _driver(client, db)
    rides = [await _book(client, minutes_ahead=60 * 48) for _ in range(3)]

    codes = [
        (await client.post(f"/api/v1/rides/{rid}/claim", headers=_auth(me))).status_code
        for rid in rides
    ]

    assert codes == [200, 200, 409]


async def test_a_driver_who_is_not_verified_cannot_claim(client, db):
    me, _ = await _driver(client, db, verified=False)
    ride_id = await _book(client, minutes_ahead=60 * 48)

    out = await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    assert out.status_code == 403


async def test_a_driver_too_far_away_cannot_claim(client, db):
    me, _ = await _driver(client, db, lat=34.5, lng=74.0)
    ride_id = await _book(client, minutes_ahead=60 * 48)

    out = await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    assert out.status_code == 403


async def test_a_ride_already_in_its_pickup_window_is_accepted_not_claimed(client, db):
    me, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=10)

    out = await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    assert out.status_code == 409


async def test_release_gives_the_ride_back_to_everyone(client, db):
    me, _ = await _driver(client, db)
    other, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    out = await client.post(f"/api/v1/rides/{ride_id}/release", headers=_auth(me))

    assert out.status_code == 200, out.text
    assert (await _ride(db, ride_id)).claimed_driver_id is None
    assert ride_id in _ids(
        await client.get("/api/v1/rides/scheduled/open", headers=_auth(other))
    )


async def test_only_the_claiming_driver_can_release(client, db):
    me, _ = await _driver(client, db)
    other, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))

    out = await client.post(f"/api/v1/rides/{ride_id}/release", headers=_auth(other))

    assert out.status_code == 403
    assert (await _ride(db, ride_id)).claimed_driver_id is not None


async def test_release_is_refused_close_to_pickup(client, db):
    me, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=40))
    )
    await db.commit()

    out = await client.post(f"/api/v1/rides/{ride_id}/release", headers=_auth(me))

    assert out.status_code == 409
    assert (await _ride(db, ride_id)).claimed_driver_id is not None


async def test_a_claimed_ride_goes_to_its_driver_when_the_window_opens(client, db):
    me, driver_id = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=20))
    )
    await db.commit()

    await dispatch_loop.assign_due_claims(db, datetime.now(timezone.utc))

    ride = await _ride(db, ride_id)
    assert ride.status == RideStatus.driver_assigned
    assert ride.driver_id == driver_id


async def test_the_driver_is_pushed_when_their_claimed_ride_starts(client, db):
    me, driver_id = await _driver(client, db)
    user_id = (
        await db.execute(select(Driver.user_id).where(Driver.id == driver_id))
    ).scalar_one()
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=20))
    )
    await db.commit()

    with patch.object(
        dispatch_loop, "notify_user", AsyncMock(return_value=True)
    ) as push:
        await dispatch_loop.assign_due_claims(db, datetime.now(timezone.utc))

    assert any(call.kwargs.get("user_id") == user_id for call in push.await_args_list)


async def test_a_claim_the_driver_cannot_keep_returns_to_the_pool(client, db):
    me, driver_id = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status=DriverStatus.busy)
    )
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=5))
    )
    await db.commit()

    await dispatch_loop.assign_due_claims(db, datetime.now(timezone.utc))

    ride = await _ride(db, ride_id)
    assert ride.status == RideStatus.pending
    assert ride.driver_id is None
    assert ride.claimed_driver_id is None


async def test_a_busy_driver_keeps_the_claim_until_close_to_pickup(client, db):
    me, driver_id = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status=DriverStatus.busy)
    )
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=25))
    )
    await db.commit()

    await dispatch_loop.assign_due_claims(db, datetime.now(timezone.utc))

    assert (await _ride(db, ride_id)).claimed_driver_id == driver_id


async def test_another_driver_cannot_accept_a_claimed_ride(client, db):
    me, _ = await _driver(client, db)
    other, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=20))
    )
    await db.commit()

    out = await client.post(f"/api/v1/rides/{ride_id}/accept", headers=_auth(other))

    assert out.status_code == 409
    assert ride_id not in _ids(
        await client.get("/api/v1/rides/pending", headers=_auth(other))
    )


async def test_dispatch_skips_a_claimed_ride(client, db):
    me, _ = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=20))
    )
    await db.commit()

    pending = await dispatch_loop._pending_rides(db, datetime.now(timezone.utc))

    assert ride_id not in [str(row[0]) for row in pending]


async def test_a_driver_who_cancels_an_assigned_claim_loses_it(client, db):
    me, driver_id = await _driver(client, db)
    ride_id = await _book(client, minutes_ahead=60 * 48)
    await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(me))
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(scheduled_for=datetime.now(timezone.utc) + timedelta(minutes=20))
    )
    await db.commit()
    await dispatch_loop.assign_due_claims(db, datetime.now(timezone.utc))

    out = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled", "cancel_reason": "car broke down"},
        headers=_auth(me),
    )

    assert out.status_code == 200, out.text
    ride = await _ride(db, ride_id)
    assert ride.status == RideStatus.pending
    assert ride.claimed_driver_id is None
