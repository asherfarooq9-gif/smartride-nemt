"""What real people do, end to end, against the real database (no mocked dispatch)."""

import uuid
from datetime import datetime, timedelta, timezone

import pytest_asyncio
from sqlalchemy import select, update

from app.core.database import engine
from app.models.models import Driver, DriverStatus, Hospital, WalletEntry
from tests.test_dispatch_endpoints import _register
from tests.test_review_fixes import _auth, _driver_extra

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_engine():
    """Background dispatch uses the app engine; bind it to this test's loop."""
    await engine.dispose()
    yield
    await engine.dispose()


async def _nearby_hospital(db) -> Hospital:
    hospital = Hospital(
        name=f"Journey Hospital {uuid.uuid4().hex[:6]}",
        address="1 Test Road",
        city="Islamabad",
        lat=PICKUP["pickup_lat"] + 0.05,
        lng=PICKUP["pickup_lng"],
        specialties=["general_emergency", "cardiology"],
        ed_capacity=100,
        ed_current_load=10,
    )
    db.add(hospital)
    await db.commit()
    return hospital


async def _online_driver(client, db) -> tuple[str, str]:
    """A verified driver parked 1 km from the pickup; every other driver goes offline."""
    token = await _register(client, _phone(), "driver", **_driver_extra())
    driver_id = (await client.get("/api/v1/drivers/me", headers=_auth(token))).json()[
        "id"
    ]
    await db.execute(update(Driver).values(status=DriverStatus.offline))
    await db.execute(
        update(Driver)
        .where(Driver.id == driver_id)
        .values(
            is_verified=True,
            status=DriverStatus.available,
            current_lat=PICKUP["pickup_lat"] + 0.009,
            current_lng=PICKUP["pickup_lng"],
            last_seen_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()
    return token, driver_id


async def _status(client, token, ride_id) -> dict:
    r = await client.get(f"/api/v1/rides/{ride_id}", headers=_auth(token))
    assert r.status_code == 200, r.text
    return r.json()


async def test_emergency_from_request_to_rating(client, db):
    await _nearby_hospital(db)
    driver_token, driver_id = await _online_driver(client, db)
    patient = await _register(client, _phone(), "patient")

    # 1. The patient asks for help; dispatch runs by itself.
    created = await client.post(
        "/api/v1/rides/emergency",
        json={
            **PICKUP,
            "symptom_text": "chest pain and sweating",
            "pickup_address": "G-8",
        },
        headers=_auth(patient),
    )
    assert created.status_code == 201, created.text
    ride_id = created.json()["id"]

    # 2. A driver and a hospital were chosen without anyone clicking anything.
    ride = await _status(client, patient, ride_id)
    assert ride["status"] == "driver_assigned"
    assert ride["driver_id"] == driver_id
    assert ride["hospital_id"] is not None
    assert float(ride["estimated_fare_pkr"]) > 0

    # 3. The driver works through the trip.
    for state in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await client.patch(
            f"/api/v1/rides/{ride_id}/status",
            json={"status": state},
            headers=_auth(driver_token),
        )
        assert r.status_code == 200, (state, r.text)
        assert (await _status(client, patient, ride_id))["status"] == state

    # 4. Money: a final fare, one commission entry, driver free again.
    done = await _status(client, patient, ride_id)
    assert float(done["final_fare_pkr"]) > 0
    entries = (
        (await db.execute(select(WalletEntry).where(WalletEntry.ride_id == ride_id)))
        .scalars()
        .all()
    )
    assert [e.kind for e in entries] == ["commission"]
    me = await client.get("/api/v1/drivers/me", headers=_auth(driver_token))
    assert me.json()["status"] == "available"

    # 5. The patient rates the driver, once.
    first = await client.post(
        f"/api/v1/rides/{ride_id}/rate",
        json={"rating": 5, "comment": "Fast and kind"},
        headers=_auth(patient),
    )
    assert first.status_code == 200, first.text
    again = await client.post(
        f"/api/v1/rides/{ride_id}/rate", json={"rating": 1}, headers=_auth(patient)
    )
    assert again.status_code in (400, 409)

    # 6. It shows up in the patient's history and the driver's earnings.
    mine = await client.get("/api/v1/rides/mine", headers=_auth(patient))
    assert ride_id in {r["id"] for r in mine.json()["items"]}
    earnings = await client.get("/api/v1/drivers/earnings", headers=_auth(driver_token))
    assert earnings.json()["ride_count"] == 1
    assert earnings.json()["total_earned_pkr"] > 0


async def test_patient_cancels_while_the_driver_is_on_the_way(client, db):
    await _nearby_hospital(db)
    driver_token, _ = await _online_driver(client, db)
    patient = await _register(client, _phone(), "patient")
    created = await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": "fall"},
        headers=_auth(patient),
    )
    ride_id = created.json()["id"]
    await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "driver_en_route"},
        headers=_auth(driver_token),
    )

    r = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled", "cancel_reason": "Family drove me"},
        headers=_auth(patient),
    )

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"
    me = await client.get("/api/v1/drivers/me", headers=_auth(driver_token))
    assert me.json()["status"] == "available"
    # The driver can no longer move a cancelled ride.
    again = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "patient_picked_up"},
        headers=_auth(driver_token),
    )
    assert again.status_code == 400


async def test_a_ride_with_no_driver_stays_pending_and_is_visible_to_drivers(
    client, db
):
    await _nearby_hospital(db)
    await db.execute(update(Driver).values(status=DriverStatus.offline))
    await db.commit()
    patient = await _register(client, _phone(), "patient")

    created = await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": "bleeding"},
        headers=_auth(patient),
    )
    ride_id = created.json()["id"]
    assert (await _status(client, patient, ride_id))["status"] == "pending"

    driver_token, _ = await _online_driver(client, db)
    pending = await client.get("/api/v1/rides/pending", headers=_auth(driver_token))
    assert ride_id in {r["id"] for r in pending.json()["items"]}
    taken = await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(driver_token)
    )
    assert taken.status_code == 200, taken.text


async def test_scheduled_ride_rules(client):
    patient = await _register(client, _phone(), "patient")
    soon = datetime.now(timezone.utc) + timedelta(days=2)
    ok = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": soon.isoformat(), "pickup_address": "Home"},
        headers=_auth(patient),
    )
    assert ok.status_code == 201, ok.text
    assert ok.json()["ride_type"] == "scheduled"

    past = datetime.now(timezone.utc) - timedelta(hours=1)
    bad = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": past.isoformat()},
        headers=_auth(patient),
    )
    assert bad.status_code == 422


async def test_someone_with_both_roles_cannot_drive_their_own_ride(client, db):
    token = await _register(client, _phone(), "patient")
    added = await client.post(
        "/api/v1/auth/add-role",
        json={"role": "driver", **_driver_extra()},
        headers=_auth(token),
    )
    assert added.status_code == 200, added.text
    both = added.json()["access_token"]
    me = await client.get("/api/v1/drivers/me", headers=_auth(both))
    await db.execute(
        update(Driver).where(Driver.id == me.json()["id"]).values(is_verified=True)
    )
    created = await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": "fall"},
        headers=_auth(both),
    )
    ride_id = created.json()["id"]

    r = await client.post(f"/api/v1/rides/{ride_id}/accept", headers=_auth(both))

    assert r.status_code in (403, 409), r.text


async def test_a_driver_who_goes_offline_is_not_given_new_rides(client, db):
    await _nearby_hospital(db)
    driver_token, _ = await _online_driver(client, db)
    off = await client.patch(
        "/api/v1/drivers/status",
        json={"status": "offline"},
        headers=_auth(driver_token),
    )
    assert off.status_code == 200
    patient = await _register(client, _phone(), "patient")

    created = await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": "fall"},
        headers=_auth(patient),
    )

    assert (await _status(client, patient, created.json()["id"]))["status"] == "pending"


async def test_a_driver_cannot_take_a_second_ride_while_on_one(
    client, db, verified_driver_token
):
    first = await _register(client, _phone(), "patient")
    second = await _register(client, _phone(), "patient")
    ids = []
    for patient in (first, second):
        created = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "fall"},
            headers=_auth(patient),
        )
        ids.append(created.json()["id"])
    await db.execute(update(Driver).values(status=DriverStatus.offline))
    me = await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    await db.execute(
        update(Driver)
        .where(Driver.id == me.json()["id"])
        .values(status=DriverStatus.available)
    )
    await db.commit()

    one = await client.post(
        f"/api/v1/rides/{ids[0]}/accept", headers=_auth(verified_driver_token)
    )
    two = await client.post(
        f"/api/v1/rides/{ids[1]}/accept", headers=_auth(verified_driver_token)
    )

    assert one.status_code == 200, one.text
    assert two.status_code == 409, two.text


async def test_an_offline_driver_cannot_take_a_ride(client, verified_driver_token):
    await client.patch(
        "/api/v1/drivers/status",
        json={"status": "offline"},
        headers=_auth(verified_driver_token),
    )
    patient = await _register(client, _phone(), "patient")
    created = await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": "fall"},
        headers=_auth(patient),
    )

    r = await client.post(
        f"/api/v1/rides/{created.json()['id']}/accept",
        headers=_auth(verified_driver_token),
    )

    assert r.status_code == 409
