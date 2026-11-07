"""Scheduled-ride creation is idempotent in the database, not only in Redis."""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from sqlalchemy import func, select, update

from app.models.models import Patient, Ride, RideIdempotencyKey, RideType
from app.services.retention import purge_old_idempotency_keys
from tests.test_review_fixes import _auth, _register

URL = "/api/v1/rides/scheduled"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


def _body(**over) -> dict:
    when = datetime.now(timezone.utc) + timedelta(days=2)
    return {
        "pickup_lat": 33.7215,
        "pickup_lng": 73.0433,
        "pickup_address": "G-9, Islamabad",
        "scheduled_for": when.replace(microsecond=0).isoformat(),
        **over,
    }


def _headers(token: str, key: str | None) -> dict:
    return {**_auth(token), **({"Idempotency-Key": key} if key else {})}


async def _ride_count(db, token_phone_user_id) -> int:
    patient_id = (
        await db.execute(
            select(Patient.id).where(Patient.user_id == token_phone_user_id)
        )
    ).scalar_one()
    return (
        await db.execute(
            select(func.count())
            .select_from(Ride)
            .where(Ride.patient_id == patient_id, Ride.ride_type == RideType.scheduled)
        )
    ).scalar_one()


async def _patient(client):
    token = await _register(client, _phone(), "patient")
    me = await client.get("/api/v1/auth/me", headers=_auth(token))
    return token, me.json()["user_id"]


async def test_two_concurrent_posts_with_one_key_make_one_ride(isolated_client, db):
    token, user_id = await _patient(isolated_client)
    body = _body()
    key = uuid.uuid4().hex

    first, second = await asyncio.gather(
        isolated_client.post(URL, json=body, headers=_headers(token, key)),
        isolated_client.post(URL, json=body, headers=_headers(token, key)),
    )

    assert sorted([first.status_code, second.status_code]) == [200, 201]
    assert first.json()["id"] == second.json()["id"]
    assert await _ride_count(db, user_id) == 1


async def test_a_retry_with_redis_down_still_returns_the_same_ride(isolated_client, db):
    token, user_id = await _patient(isolated_client)
    body = _body()
    key = uuid.uuid4().hex

    with (
        patch("app.routers.rides.idempotency.recall", new=AsyncMock(return_value=None)),
        patch("app.routers.rides.idempotency.remember", new=AsyncMock()),
    ):
        made = await isolated_client.post(URL, json=body, headers=_headers(token, key))
        retried = await isolated_client.post(
            URL, json=body, headers=_headers(token, key)
        )

    assert made.status_code == 201
    assert retried.status_code == 200
    assert retried.json()["id"] == made.json()["id"]
    assert await _ride_count(db, user_id) == 1


async def test_the_same_key_with_a_different_body_is_a_conflict(isolated_client, db):
    token, user_id = await _patient(isolated_client)
    key = uuid.uuid4().hex
    await isolated_client.post(URL, json=_body(), headers=_headers(token, key))

    other = await isolated_client.post(
        URL, json=_body(pickup_address="F-8, Islamabad"), headers=_headers(token, key)
    )

    assert other.status_code == 409
    assert await _ride_count(db, user_id) == 1


async def test_the_same_key_from_two_patients_makes_two_rides(isolated_client, db):
    key = uuid.uuid4().hex
    one, one_id = await _patient(isolated_client)
    two, two_id = await _patient(isolated_client)

    a = await isolated_client.post(URL, json=_body(), headers=_headers(one, key))
    b = await isolated_client.post(URL, json=_body(), headers=_headers(two, key))

    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]


async def test_without_a_key_two_bookings_are_two_rides(isolated_client, db):
    token, user_id = await _patient(isolated_client)

    await isolated_client.post(URL, json=_body(), headers=_headers(token, None))
    await isolated_client.post(URL, json=_body(), headers=_headers(token, None))

    assert await _ride_count(db, user_id) == 2


async def test_the_key_row_survives_a_lost_response(isolated_client, db):
    """The ride and its key commit together, so a retry finds the ride."""
    token, user_id = await _patient(isolated_client)
    key = uuid.uuid4().hex
    body = _body()

    await isolated_client.post(URL, json=body, headers=_headers(token, key))
    rows = (
        await db.execute(
            select(func.count())
            .select_from(RideIdempotencyKey)
            .where(RideIdempotencyKey.key == key)
        )
    ).scalar_one()

    assert rows == 1


async def test_old_key_rows_are_purged_and_recent_ones_stay(isolated_client, db):
    token, user_id = await _patient(isolated_client)
    old_key, new_key = uuid.uuid4().hex, uuid.uuid4().hex
    await isolated_client.post(URL, json=_body(), headers=_headers(token, old_key))
    await isolated_client.post(
        URL, json=_body(pickup_address="F-8"), headers=_headers(token, new_key)
    )
    await db.execute(
        update(RideIdempotencyKey)
        .where(RideIdempotencyKey.key == old_key)
        .values(created_at=datetime.now(timezone.utc) - timedelta(hours=30))
    )
    await db.commit()

    removed = await purge_old_idempotency_keys(db)

    remaining = set(
        (
            await db.execute(
                select(RideIdempotencyKey.key).where(
                    RideIdempotencyKey.key.in_([old_key, new_key])
                )
            )
        ).scalars()
    )
    assert removed >= 1
    assert remaining == {new_key}
