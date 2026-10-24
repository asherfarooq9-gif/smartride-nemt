"""Findings from the 2026-10-24 security assessment: scheduled-ride idempotency,
idempotency body check, service-area bound and ride-leg minimum duration."""

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException
from sqlalchemy import func, select, update

from app.core.config import settings
from app.models.models import Ride
from app.services import idempotency, ride_service
from tests.test_dispatch_endpoints import _register
from tests.test_ride_lifecycle import (
    _assigned_ride,
    _auth,
    _phone,
    _set_ride_status,
)

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}
SYMPTOMS = "crushing chest pain"


def _scheduled_body() -> dict:
    when = datetime.now(timezone.utc) + timedelta(days=1)
    return {**PICKUP, "scheduled_for": when.isoformat()}


async def _post_scheduled(client, token, body, key=None):
    headers = _auth(token)
    if key is not None:
        headers["Idempotency-Key"] = key
    return await client.post("/api/v1/rides/scheduled", json=body, headers=headers)


async def _ride_count(db, patient_id) -> int:
    db.expire_all()
    return (
        await db.execute(
            select(func.count()).select_from(Ride).where(Ride.patient_id == patient_id)
        )
    ).scalar_one()


# ── scheduled-ride idempotency ───────────────────────────────────────────────


async def test_scheduled_ride_replay_with_same_key_creates_one_ride(client, db):
    token = await _register(client, _phone(), "patient")
    body = _scheduled_body()
    key = f"key-{uuid.uuid4()}"

    first = await _post_scheduled(client, token, body, key)
    replay = await _post_scheduled(client, token, body, key)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json()["id"] == first.json()["id"]
    assert await _ride_count(db, first.json()["patient_id"]) == 1


async def test_scheduled_ride_without_a_key_still_creates_each_time(client, db):
    token = await _register(client, _phone(), "patient")
    body = _scheduled_body()

    first = await _post_scheduled(client, token, body)
    second = await _post_scheduled(client, token, body)

    assert first.status_code == second.status_code == 201
    assert first.json()["id"] != second.json()["id"]


async def test_scheduled_ride_key_reused_with_another_body_is_409(client, db):
    token = await _register(client, _phone(), "patient")
    key = f"key-{uuid.uuid4()}"
    first = await _post_scheduled(client, token, _scheduled_body(), key)
    other = {**_scheduled_body(), "pickup_lat": 33.0}

    clash = await _post_scheduled(client, token, other, key)

    assert first.status_code == 201
    assert clash.status_code == 409
    assert await _ride_count(db, first.json()["patient_id"]) == 1


async def test_emergency_key_reused_with_another_body_is_409(client, db):
    token = await _register(client, _phone(), "patient")
    key = f"key-{uuid.uuid4()}"
    headers = {**_auth(token), "Idempotency-Key": key}
    body = {**PICKUP, "symptom_text": SYMPTOMS}

    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        first = await client.post("/api/v1/rides/emergency", json=body, headers=headers)
        clash = await client.post(
            "/api/v1/rides/emergency",
            json={**body, "symptom_text": "now unconscious"},
            headers=headers,
        )

    assert first.status_code == 201
    assert clash.status_code == 409


def test_fingerprint_ignores_key_order_but_not_values():
    from app.schemas.rides import EmergencyRideRequest

    a = EmergencyRideRequest(pickup_lat=1, pickup_lng=2, symptom_text="x")
    same = EmergencyRideRequest(symptom_text="x", pickup_lng=2, pickup_lat=1)
    other = EmergencyRideRequest(pickup_lat=1, pickup_lng=2, symptom_text="y")

    assert idempotency.fingerprint(a) == idempotency.fingerprint(same)
    assert idempotency.fingerprint(a) != idempotency.fingerprint(other)


# ── service area ─────────────────────────────────────────────────────────────


def test_pickup_outside_the_service_area_is_rejected(monkeypatch):
    monkeypatch.setattr(settings, "SERVICE_AREA_BBOX", "23,60.5,37.5,78")

    ride_service.ensure_in_service_area(33.7, 73.0)
    with pytest.raises(HTTPException) as err:
        ride_service.ensure_in_service_area(37.42, -122.08)

    assert err.value.status_code == 422


def test_service_area_check_is_off_when_unset(monkeypatch):
    monkeypatch.setattr(settings, "SERVICE_AREA_BBOX", "")

    ride_service.ensure_in_service_area(37.42, -122.08)


async def test_emergency_ride_outside_the_service_area_is_422(client, monkeypatch):
    monkeypatch.setattr(settings, "SERVICE_AREA_BBOX", "23,60.5,37.5,78")
    token = await _register(client, _phone(), "patient")

    r = await client.post(
        "/api/v1/rides/emergency",
        json={"pickup_lat": 37.42, "pickup_lng": -122.08, "symptom_text": SYMPTOMS},
        headers=_auth(token),
    )

    assert r.status_code == 422


# ── minimum leg duration ─────────────────────────────────────────────────────


async def test_ride_cannot_complete_before_the_minimum_leg_time(
    client, db, verified_driver_token, monkeypatch
):
    monkeypatch.setattr(settings, "RIDE_MIN_TRANSITION_SECONDS", 60)
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    for status in ("driver_en_route", "patient_picked_up"):
        step = await _set_ride_status(client, verified_driver_token, ride_id, status)
        assert step.status_code == 200, step.text

    too_soon = await _set_ride_status(
        client, verified_driver_token, ride_id, "arrived_at_hospital"
    )
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(pickup_at=datetime.now(timezone.utc) - timedelta(seconds=61))
    )
    await db.commit()
    later = await _set_ride_status(
        client, verified_driver_token, ride_id, "arrived_at_hospital"
    )

    assert too_soon.status_code == 400
    assert "Too soon" in too_soon.json()["detail"]
    assert later.status_code == 200


async def test_minimum_leg_time_is_off_by_default(client, verified_driver_token):
    assert settings.RIDE_MIN_TRANSITION_SECONDS == 0
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_ride_status(client, verified_driver_token, ride_id, status)
        assert r.status_code == 200, r.text
