"""Driver demand forecast: busy hours ahead, from past ride requests.

Hours are Pakistan time (UTC+5, no daylight saving), because that is when
drivers and patients think about the day.
"""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import delete, select

from app.models.models import Patient, Ride, RideStatus, RideType
from app.services import demand_forecast
from tests.test_dispatch_endpoints import _register
from tests.test_ride_lifecycle import _auth, _phone

# The test database keeps what earlier tests committed, so these tests live in
# the year 2030, where no other test creates rides, and clear it around each run.
FAR_FUTURE = datetime(2030, 1, 1, tzinfo=timezone.utc)

# 15:00 in Pakistan. The next hours are 16:00 (11:00 UTC), 17:00, 18:00 ...
NOW = datetime(2030, 10, 30, 10, 0, tzinfo=timezone.utc)


def _utc(day: int, hour: int, minute: int = 0) -> datetime:
    return datetime(2030, 10, day, hour, minute, tzinfo=timezone.utc)


@pytest.fixture(autouse=True)
async def _clean_far_future_rides(db):
    await db.execute(delete(Ride).where(Ride.requested_at >= FAR_FUTURE))
    await db.commit()
    yield
    await db.rollback()
    await db.execute(delete(Ride).where(Ride.requested_at >= FAR_FUTURE))
    await db.commit()


async def _patient_id(client, db):
    await _register(client, _phone(), "patient")
    patient = (
        await db.execute(select(Patient).order_by(Patient.created_at.desc()).limit(1))
    ).scalar_one()
    return patient.id


async def _add_rides(db, patient_id, *requested_at, status=RideStatus.completed):
    for when in requested_at:
        db.add(
            Ride(
                patient_id=patient_id,
                ride_type=RideType.emergency,
                status=status,
                pickup_lat=33.7,
                pickup_lng=73.0,
                requested_at=when,
            )
        )
    await db.commit()


async def test_averages_rides_per_pakistan_hour_over_the_days_observed(client, db):
    patient_id = await _patient_id(client, db)
    # 16:xx Pakistan time on three days, and two rides at 17:xx on the last one.
    await _add_rides(
        db,
        patient_id,
        _utc(27, 11, 30),
        _utc(28, 11, 10),
        _utc(29, 11, 40),
        _utc(29, 12, 5),
        _utc(29, 12, 45),
    )

    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=3)

    first, second, third = result["forecast"]
    assert first["hour"] == _utc(30, 11).isoformat()
    assert first["predicted_rides"] == 1.0  # 3 rides over 3 days
    assert second["predicted_rides"] == 0.7  # 2 rides over 3 days
    assert third["predicted_rides"] == 0.0
    assert [first["level"], second["level"], third["level"]] == [
        "high",
        "medium",
        "low",
    ]
    assert result["has_data"] is True


async def test_no_history_says_so_and_predicts_nothing(client, db):
    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=4)

    assert result["has_data"] is False
    assert len(result["forecast"]) == 4
    assert all(p["predicted_rides"] == 0.0 for p in result["forecast"])
    assert all(p["level"] == "low" for p in result["forecast"])


async def test_rides_older_than_the_look_back_window_are_ignored(client, db):
    patient_id = await _patient_id(client, db)
    await _add_rides(db, patient_id, NOW - timedelta(days=40) + timedelta(hours=1))

    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=2)

    assert result["has_data"] is False


async def test_a_young_history_is_not_diluted_by_the_full_window(client, db):
    """One ride yesterday is one ride per day, not one per 28 days."""
    patient_id = await _patient_id(client, db)
    await _add_rides(db, patient_id, _utc(29, 11, 30))

    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=1)

    assert result["forecast"][0]["predicted_rides"] == 1.0


async def test_cancelled_requests_still_count_as_demand(client, db):
    patient_id = await _patient_id(client, db)
    await _add_rides(db, patient_id, _utc(29, 11, 30), status=RideStatus.cancelled)

    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=1)

    assert result["forecast"][0]["predicted_rides"] == 1.0


async def test_hours_run_forward_one_hour_at_a_time(client, db):
    result = await demand_forecast.hourly_demand(db, NOW, hours_ahead=6)

    hours = [datetime.fromisoformat(p["hour"]) for p in result["forecast"]]
    assert hours[0] == _utc(30, 11)
    assert [b - a for a, b in zip(hours, hours[1:])] == [timedelta(hours=1)] * 5


# ── The endpoint ─────────────────────────────────────────────────────────────


async def test_driver_can_read_the_forecast(client, verified_driver_token):
    response = await client.get(
        "/api/v1/drivers/demand-forecast", headers=_auth(verified_driver_token)
    )

    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["forecast"]) == 6  # the default
    assert set(body) == {"generated_at", "method", "has_data", "forecast"}
    assert set(body["forecast"][0]) == {"hour", "predicted_rides", "level"}


async def test_hours_ahead_is_limited(client, verified_driver_token):
    headers = _auth(verified_driver_token)

    too_few = await client.get(
        "/api/v1/drivers/demand-forecast?hours_ahead=0", headers=headers
    )
    too_many = await client.get(
        "/api/v1/drivers/demand-forecast?hours_ahead=25", headers=headers
    )

    assert too_few.status_code == 422
    assert too_many.status_code == 422


async def test_a_patient_cannot_read_it(client):
    token = await _register(client, _phone(), "patient")

    response = await client.get("/api/v1/drivers/demand-forecast", headers=_auth(token))

    assert response.status_code == 403


async def test_it_needs_a_login(client):
    response = await client.get("/api/v1/drivers/demand-forecast")

    assert response.status_code in (401, 403)


@pytest.mark.parametrize("hours_ahead", [1, 12, 24])
async def test_any_allowed_window_length_works(
    client, verified_driver_token, hours_ahead
):
    response = await client.get(
        f"/api/v1/drivers/demand-forecast?hours_ahead={hours_ahead}",
        headers=_auth(verified_driver_token),
    )

    assert response.status_code == 200
    assert len(response.json()["forecast"]) == hours_ahead
