"""A driver who owes more than the limit gets no new work, but never loses a ride in progress.

Fares are paid in cash, so commission comes out of a prepaid wallet. Without a
limit a driver could run the balance down for ever.
"""

import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import select, update

from app.core.config import settings
from app.models.models import Driver, Patient, Ride, RideStatus, RideType
from app.services.emergency_dispatch import find_available_drivers_by_distance
from tests.test_review_fixes import _auth, _register

STATUS = "/api/v1/drivers/status"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _driver(client, db, balance: str):
    uid = uuid.uuid4().hex[:8]
    token = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"DL-{uid}",
        vehicle_plate=f"DL-{uid[:6]}",
        vehicle_type="sedan",
    )
    user_id = (await client.get("/api/v1/auth/me", headers=_auth(token))).json()[
        "user_id"
    ]
    await db.execute(
        update(Driver)
        .where(Driver.user_id == user_id)
        .values(
            is_verified=True,
            wallet_balance_pkr=Decimal(balance),
            current_lat=33.7215,
            current_lng=73.0433,
            last_seen_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == user_id))
    ).scalar_one()
    return token, driver.id


async def _pending_ride(client, db, ride_type=RideType.scheduled) -> str:
    token = await _register(client, _phone(), "patient")
    user_id = (await client.get("/api/v1/auth/me", headers=_auth(token))).json()[
        "user_id"
    ]
    patient = (
        await db.execute(select(Patient).where(Patient.user_id == user_id))
    ).scalar_one()
    ride = Ride(
        patient_id=patient.id,
        ride_type=ride_type,
        status=RideStatus.pending,
        pickup_lat=33.7215,
        pickup_lng=73.0433,
        scheduled_for=(
            datetime.now(timezone.utc) + timedelta(days=2)
            if ride_type == RideType.scheduled
            else None
        ),
    )
    db.add(ride)
    await db.commit()
    return str(ride.id)


async def test_a_driver_over_the_limit_cannot_go_online(client, db):
    token, _ = await _driver(client, db, "-300.00")

    out = await client.patch(STATUS, json={"status": "available"}, headers=_auth(token))

    assert out.status_code == 402
    assert "Top up" in out.json()["detail"]


async def test_a_driver_exactly_at_the_limit_can_still_go_online(client, db):
    token, _ = await _driver(client, db, f"-{settings.DRIVER_DEBT_LIMIT_PKR}.00")

    out = await client.patch(STATUS, json={"status": "available"}, headers=_auth(token))

    assert out.status_code == 200, out.text


async def test_a_new_driver_with_nothing_in_the_wallet_can_work(client, db):
    token, _ = await _driver(client, db, "0.00")

    out = await client.patch(STATUS, json={"status": "available"}, headers=_auth(token))

    assert out.status_code == 200, out.text


async def test_topping_up_lets_a_blocked_driver_back_in(client, db):
    token, driver_id = await _driver(client, db, "-300.00")
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(wallet_balance_pkr=0)
    )
    await db.commit()

    out = await client.patch(STATUS, json={"status": "available"}, headers=_auth(token))

    assert out.status_code == 200, out.text


async def test_a_driver_over_the_limit_cannot_claim_a_booked_ride(client, db):
    token, _ = await _driver(client, db, "-300.00")
    ride_id = await _pending_ride(client, db)

    out = await client.post(f"/api/v1/rides/{ride_id}/claim", headers=_auth(token))

    assert out.status_code == 402


async def test_a_driver_over_the_limit_cannot_accept_a_ride(client, db):
    token, driver_id = await _driver(client, db, "-300.00")
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status="available")
    )
    await db.commit()
    ride_id = await _pending_ride(client, db, RideType.emergency)

    out = await client.post(f"/api/v1/rides/{ride_id}/accept", headers=_auth(token))

    assert out.status_code == 402, out.text


async def test_dispatch_skips_a_driver_over_the_limit(client, db):
    _, owing = await _driver(client, db, "-300.00")
    _, fine = await _driver(client, db, "0.00")
    await db.execute(
        update(Driver).where(Driver.id.in_([owing, fine])).values(status="available")
    )
    await db.commit()

    found = {
        d.id for d in await find_available_drivers_by_distance(db, 33.7215, 73.0433)
    }

    assert fine in found
    assert owing not in found
