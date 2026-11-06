"""Repeat bookings: one request books a run of scheduled rides, all or nothing."""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.core.config import settings
from app.models.models import Patient, Ride
from tests.test_review_fixes import _auth, _register

URL = "/api/v1/rides/scheduled/series"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


def _body(**over) -> dict:
    start = datetime.now(timezone.utc) + timedelta(days=2)
    return {
        "pickup_lat": 33.7215,
        "pickup_lng": 73.0433,
        "pickup_address": "G-9, Islamabad",
        "scheduled_for": start.replace(microsecond=0).isoformat(),
        "repeat": "weekly",
        "occurrences": 4,
        **over,
    }


def _headers(token: str, key: str | None = None) -> dict:
    return {**_auth(token), **({"Idempotency-Key": key} if key else {})}


async def _patient(client):
    token = await _register(client, _phone(), "patient")
    user_id = (await client.get("/api/v1/auth/me", headers=_auth(token))).json()[
        "user_id"
    ]
    return token, user_id


async def _count(db, user_id) -> int:
    patient_id = (
        await db.execute(select(Patient.id).where(Patient.user_id == user_id))
    ).scalar_one()
    return (
        await db.execute(
            select(func.count()).select_from(Ride).where(Ride.patient_id == patient_id)
        )
    ).scalar_one()


def _times(response) -> list[datetime]:
    return [
        datetime.fromisoformat(r["scheduled_for"]) for r in response.json()["items"]
    ]


async def test_weekly_repeat_books_one_ride_a_week(client, db):
    token, user_id = await _patient(client)

    out = await client.post(URL, json=_body(), headers=_headers(token))

    assert out.status_code == 201, out.text
    assert out.json()["total"] == 4
    times = _times(out)
    assert [b - a for a, b in zip(times, times[1:])] == [timedelta(days=7)] * 3
    assert await _count(db, user_id) == 4


async def test_daily_repeat_books_one_ride_a_day(client, db):
    token, _ = await _patient(client)

    out = await client.post(
        URL, json=_body(repeat="daily", occurrences=3), headers=_headers(token)
    )

    assert out.status_code == 201, out.text
    times = _times(out)
    assert [b - a for a, b in zip(times, times[1:])] == [timedelta(days=1)] * 2


async def test_every_ride_in_the_run_belongs_to_one_series(client, db):
    token, user_id = await _patient(client)

    await client.post(URL, json=_body(), headers=_headers(token))

    series = set(
        (
            await db.execute(
                select(Ride.series_id)
                .join(Patient, Patient.id == Ride.patient_id)
                .where(Patient.user_id == user_id)
            )
        ).scalars()
    )
    assert len(series) == 1 and None not in series


async def test_a_retry_with_the_same_key_returns_the_same_run(client, db):
    token, user_id = await _patient(client)
    key, body = uuid.uuid4().hex, _body()
    first = await client.post(URL, json=body, headers=_headers(token, key))

    again = await client.post(URL, json=body, headers=_headers(token, key))

    assert first.status_code == 201 and again.status_code == 200
    assert [r["id"] for r in again.json()["items"]] == [
        r["id"] for r in first.json()["items"]
    ]
    assert await _count(db, user_id) == 4


async def test_two_simultaneous_requests_book_one_run(isolated_client, db):
    token, user_id = await _patient(isolated_client)
    body, key = _body(), uuid.uuid4().hex

    a, b = await asyncio.gather(
        isolated_client.post(URL, json=body, headers=_headers(token, key)),
        isolated_client.post(URL, json=body, headers=_headers(token, key)),
    )

    assert sorted([a.status_code, b.status_code]) == [200, 201]
    assert await _count(db, user_id) == 4


async def test_the_same_key_with_a_different_run_is_a_conflict(client, db):
    token, user_id = await _patient(client)
    key, body = uuid.uuid4().hex, _body()
    await client.post(URL, json=body, headers=_headers(token, key))

    other = await client.post(
        URL, json={**body, "occurrences": 6}, headers=_headers(token, key)
    )

    assert other.status_code == 409
    assert await _count(db, user_id) == 4


async def test_the_run_must_have_two_to_twelve_rides(client):
    token, _ = await _patient(client)

    for count in (1, 13):
        out = await client.post(
            URL, json=_body(occurrences=count), headers=_headers(token)
        )
        assert out.status_code == 422, count


async def test_only_daily_or_weekly_repeats_are_accepted(client):
    token, _ = await _patient(client)

    out = await client.post(URL, json=_body(repeat="monthly"), headers=_headers(token))

    assert out.status_code == 422


async def test_a_run_cannot_start_in_the_past(client):
    token, _ = await _patient(client)
    past = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()

    out = await client.post(
        URL, json=_body(scheduled_for=past), headers=_headers(token)
    )

    assert out.status_code == 422


async def test_a_pickup_outside_the_service_area_books_nothing(client, db, monkeypatch):
    monkeypatch.setattr(settings, "SERVICE_AREA_BBOX", "33.0,72.5,34.0,73.5")
    token, user_id = await _patient(client)

    out = await client.post(
        URL, json=_body(pickup_lat=51.5, pickup_lng=-0.12), headers=_headers(token)
    )

    assert out.status_code in (400, 422)
    assert await _count(db, user_id) == 0
