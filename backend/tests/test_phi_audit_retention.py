"""PHI audit trail on ride detail reads, and symptom-text retention purge."""

import json
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.core.config import settings
from app.models.models import Ride, RideStatus, TriageEvent
from app.services import retention
from tests.test_ride_lifecycle import _auth
from tests.test_rides_hardening import (
    SYMPTOMS,
    _dual_role_driving_someone_elses_ride,
    _set_status,
)

AUDIT_LOGGER = "smartride.phi_audit"


def _audit_events(caplog) -> list[dict]:
    return [
        json.loads(r.getMessage()) for r in caplog.records if r.name == AUDIT_LOGGER
    ]


async def test_detail_read_by_driver_is_audited_without_symptom_text(
    client, db, caplog
):
    dual_token, _, ride_id = await _dual_role_driving_someone_elses_ride(client, db)

    with caplog.at_level(logging.INFO, logger=AUDIT_LOGGER):
        r = await client.get(
            f"/api/v1/rides/{ride_id}/detail", headers=_auth(dual_token)
        )

    assert r.status_code == 200, r.text
    events = _audit_events(caplog)
    assert len(events) == 1
    assert events[0]["actor_role"] == "driver"
    assert events[0]["ride_id"] == ride_id
    assert "symptom_text" not in events[0]["fields"]
    assert SYMPTOMS not in json.dumps(events[0])


async def test_detail_read_by_owner_audits_symptom_text(client, db, caplog):
    _, owner, ride_id = await _dual_role_driving_someone_elses_ride(client, db)

    with caplog.at_level(logging.INFO, logger=AUDIT_LOGGER):
        r = await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(owner))

    assert r.status_code == 200, r.text
    events = _audit_events(caplog)
    assert len(events) == 1
    assert events[0]["actor_role"] == "patient"
    assert "symptom_text" in events[0]["fields"]


async def test_forbidden_read_is_not_audited_as_disclosure(client, db, caplog):
    dual_token, _, _ = await _dual_role_driving_someone_elses_ride(client, db)
    unknown = "00000000-0000-0000-0000-000000000000"

    with caplog.at_level(logging.INFO, logger=AUDIT_LOGGER):
        await client.get(f"/api/v1/rides/{unknown}/detail", headers=_auth(dual_token))

    assert _audit_events(caplog) == []


async def _end_ride(db, ride_id, days_ago: int) -> None:
    await _set_status(
        db,
        ride_id,
        RideStatus.completed,
        completed_at=datetime.now(timezone.utc) - timedelta(days=days_ago),
    )
    await db.commit()


async def _symptoms_of(db, ride_id) -> tuple[str | None, str]:
    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    triage = (
        await db.execute(select(TriageEvent).where(TriageEvent.ride_id == ride_id))
    ).scalar_one()
    return ride.symptom_text, triage.symptom_text


async def test_purge_blanks_symptoms_on_rides_past_the_window(client, db, monkeypatch):
    monkeypatch.setattr(settings, "SYMPTOM_RETENTION_DAYS", 30)
    _, _, ride_id = await _dual_role_driving_someone_elses_ride(client, db)
    await _end_ride(db, ride_id, days_ago=31)

    purged = await retention.purge_old_symptoms(db)

    assert purged == 1
    ride_text, triage_text = await _symptoms_of(db, ride_id)
    assert ride_text is None
    assert triage_text == retention.PURGED_MARKER


async def test_purge_keeps_recent_and_active_rides(client, db, monkeypatch):
    monkeypatch.setattr(settings, "SYMPTOM_RETENTION_DAYS", 30)
    _, _, recent = await _dual_role_driving_someone_elses_ride(client, db)
    await _end_ride(db, recent, days_ago=5)
    _, _, active = await _dual_role_driving_someone_elses_ride(client, db)

    purged = await retention.purge_old_symptoms(db)

    assert purged == 0
    assert (await _symptoms_of(db, recent))[1] == SYMPTOMS
    assert (await _symptoms_of(db, active))[1] == SYMPTOMS


async def test_purge_is_off_when_retention_is_zero(client, db, monkeypatch):
    monkeypatch.setattr(settings, "SYMPTOM_RETENTION_DAYS", 0)
    _, _, ride_id = await _dual_role_driving_someone_elses_ride(client, db)
    await _end_ride(db, ride_id, days_ago=400)

    assert await retention.purge_old_symptoms(db) == 0
    assert (await _symptoms_of(db, ride_id))[1] == SYMPTOMS
