"""Dispatch must fail loudly, never lose a ride, and never act on unchecked triage."""

import asyncio
import logging
import sys
import types
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select, text, update

import main
from app.core import metrics
from app.core.database import engine
from app.models.models import (
    Driver,
    DriverStatus,
    Patient,
    Ride,
    RideStatus,
    SeverityLevel,
    Specialty,
    TriageEvent,
)
from app.schemas.rides import EmergencyRideRequest
from app.services import dispatch_loop, notifications, ride_service
from app.services.dispatch_loop import (
    DRIVER_ACK_TIMEOUT_SECONDS,
    _symptoms,
    retry_pending_dispatches,
)
from app.services.emergency_dispatch import (
    call_triage_service,
    dispatch_emergency,
    find_available_drivers_by_distance,
    load_stored_triage,
    normalise_triage,
    record_triage,
)
from tests.test_dispatch import PATIENT_LAT, PATIENT_LNG, TRIAGE_RESPONSE, _seed
from tests.test_ride_lifecycle import _assigned_ride, _phone, _set_ride_status

TRIAGE = patch(
    "app.services.emergency_dispatch.call_triage_service",
    new=AsyncMock(return_value=TRIAGE_RESPONSE),
)


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_engine():
    """The app's pooled engine binds to the loop that first used it; each test has its own."""
    await engine.dispose()
    yield
    await engine.dispose()


def _ago(seconds: float) -> datetime:
    return datetime.now(timezone.utc) - timedelta(seconds=seconds)


def _failures(reason: str) -> float:
    return metrics.dispatch_failures_total.labels(reason=reason)._value.get()


def _logged(caplog, *needles: str) -> bool:
    return any(
        all(n in record.getMessage() for n in needles) for record in caplog.records
    )


async def _only_these_drivers(db, driver_ids) -> None:
    """Take every other driver dispatch could still pick (fresh ones) offline."""
    await db.execute(
        update(Driver)
        .where(Driver.id.notin_(driver_ids), Driver.last_seen_at >= _ago(600))
        .values(status=DriverStatus.offline)
    )
    await db.commit()


async def _only_these_pending(db, ride_ids) -> None:
    """The loop is global: cancel every other ride it could pick up or take back.

    That is every pending ride, plus rides other tests left in driver_assigned long
    enough for the acknowledgement pass to requeue them.
    """
    await db.execute(
        update(Ride)
        .where(
            Ride.id.notin_(ride_ids),
            (Ride.status == RideStatus.pending)
            | (
                (Ride.status == RideStatus.driver_assigned)
                & (Ride.driver_assigned_at < _ago(DRIVER_ACK_TIMEOUT_SECONDS))
            ),
        )
        .values(status=RideStatus.cancelled)
    )
    await db.commit()


async def _ride(db, ride_id) -> Ride:
    db.expire_all()
    return (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()


class _FakeResponse:
    def __init__(self, payload=None, *, bad_json: bool = False):
        self._payload, self._bad_json = payload, bad_json

    def raise_for_status(self) -> None:
        return None

    def json(self):
        if self._bad_json:
            raise ValueError("not json")
        return self._payload


def _fake_http_client(response: _FakeResponse):
    class _Client:
        def __init__(self, *args, **kwargs): ...
        async def __aenter__(self):
            return self

        async def __aexit__(self, *exc):
            return False

        async def post(self, *args, **kwargs):
            return response

    return _Client


# ── 1. failures are logged and counted ───────────────────────────────────────


async def test_no_hospital_is_logged_and_counted(db, caplog):
    ride, _, _ = await _seed(db)
    ride_id = ride.id
    before = _failures("no_hospital")

    with (
        TRIAGE,
        patch(
            "app.services.emergency_dispatch.load_active_hospitals",
            new=AsyncMock(return_value=[]),
        ),
        caplog.at_level(logging.WARNING),
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert "hospital" in result["error"].lower()
    assert _failures("no_hospital") == before + 1
    assert _logged(caplog, str(ride_id), "no_hospital")


async def test_no_driver_is_logged_and_counted(db, caplog):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status=DriverStatus.offline)
    )
    await _only_these_drivers(db, [driver_id])
    before = _failures("no_driver")

    with TRIAGE, caplog.at_level(logging.WARNING):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert "driver" in result["error"].lower()
    assert _failures("no_driver") == before + 1
    assert _logged(caplog, str(ride_id), "no_driver")


# ── 2. notification failures after the commit are visible ────────────────────


async def test_undelivered_notifications_are_logged_and_counted(db, caplog):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await _only_these_drivers(db, [driver.id])
    not_alerted = _failures("hospital_not_prealerted")
    not_pushed = _failures("driver_not_notified")

    with (
        TRIAGE,
        patch(
            "app.services.emergency_dispatch.notify_user",
            new=AsyncMock(return_value=False),
        ),
        patch(
            "app.services.emergency_dispatch.send_family_sms",
            new=AsyncMock(side_effect=RuntimeError("sms exploded")),
        ),
        patch(
            "app.services.emergency_dispatch.send_hospital_alert",
            new=AsyncMock(return_value=False),
        ),
        caplog.at_level(logging.ERROR),
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert result["hospital_prealerted"] is False
    assert _failures("hospital_not_prealerted") == not_alerted + 1
    assert _failures("driver_not_notified") == not_pushed + 1
    assert _logged(caplog, "hospital NOT pre-alerted", str(ride_id))
    assert _logged(caplog, "driver NOT notified", str(ride_id))
    assert _logged(caplog, "family SMS crashed", str(ride_id), "RuntimeError")


async def test_a_crashing_hospital_alert_counts_as_not_prealerted(db, caplog):
    ride, driver, _ = await _seed(db)
    await _only_these_drivers(db, [driver.id])

    with (
        TRIAGE,
        patch(
            "app.services.emergency_dispatch.send_hospital_alert",
            new=AsyncMock(side_effect=ConnectionError("fhir down")),
        ),
        caplog.at_level(logging.ERROR),
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert result["hospital_prealerted"] is False
    assert _logged(caplog, "hospital pre-alert crashed", "ConnectionError")


async def test_a_delivered_hospital_alert_is_reported(db):
    ride, driver, _ = await _seed(db)
    await _only_these_drivers(db, [driver.id])

    with (
        TRIAGE,
        patch(
            "app.services.emergency_dispatch.send_hospital_alert",
            new=AsyncMock(return_value=True),
        ),
    ):
        result = await dispatch_emergency(ride, "chest pain", db)

    assert result["hospital_prealerted"] is True


async def test_notify_user_reports_a_failed_lookup_without_raising(caplog):
    broken_db = SimpleNamespace(execute=AsyncMock(side_effect=RuntimeError("db down")))

    with caplog.at_level(logging.WARNING):
        delivered = await notifications.notify_user(
            broken_db, user_id="u1", title="t", body="b", data={"ride_id": "ride-42"}
        )

    assert delivered is False
    assert _logged(caplog, "push lookup failed", "ride-42", "RuntimeError")


async def test_notify_user_reports_a_missing_device_token():
    no_token_db = SimpleNamespace(
        execute=AsyncMock(
            return_value=SimpleNamespace(scalar_one_or_none=lambda: None)
        )
    )

    delivered = await notifications.notify_user(
        no_token_db, user_id="u1", title="t", body="b", data={"ride_id": "r1"}
    )

    assert delivered is False


async def test_a_crashing_push_task_is_logged_not_forgotten(caplog):
    token_db = SimpleNamespace(
        execute=AsyncMock(
            return_value=SimpleNamespace(scalar_one_or_none=lambda: "device-token")
        )
    )

    with (
        patch.object(
            notifications, "send_push", AsyncMock(side_effect=RuntimeError("boom"))
        ),
        caplog.at_level(logging.ERROR),
    ):
        delivered = await notifications.notify_user(
            token_db, user_id="u1", title="t", body="b", data={"ride_id": "ride-77"}
        )
        await asyncio.gather(*notifications._pending_pushes, return_exceptions=True)
        await asyncio.sleep(0)  # let the done-callback run

    assert delivered is True
    assert _logged(caplog, "push task failed", "ride-77", "RuntimeError")
    assert not notifications._pending_pushes


async def test_send_sms_reports_success_so_a_prealert_is_not_called_lost(monkeypatch):
    class FakeClient:
        def __init__(self, *args, **kwargs): ...

        @property
        def messages(self):
            return SimpleNamespace(create=lambda **kw: SimpleNamespace(sid="SM1"))

    for name, attrs in {
        "twilio": {},
        "twilio.http": {},
        "twilio.http.http_client": {"TwilioHttpClient": lambda **kw: None},
        "twilio.rest": {"Client": FakeClient},
    }.items():
        module = types.ModuleType(name)
        module.__dict__.update(attrs)
        monkeypatch.setitem(sys.modules, name, module)
    monkeypatch.setattr(notifications.settings, "TWILIO_ACCOUNT_SID", "AC123")

    assert notifications._send_sms("+923001234567", "body") is True


# ── 3. triage robustness ─────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "response",
    [
        _FakeResponse({"unexpected": "shape"}),
        _FakeResponse(["not", "an", "object"]),
        _FakeResponse({"specialty": 5, "severity": "3"}),
        _FakeResponse({"specialty": "cardiology"}),
        _FakeResponse(bad_json=True),
    ],
    ids=["wrong-keys", "not-an-object", "wrong-types", "missing-severity", "bad-json"],
)
async def test_malformed_triage_json_falls_back_to_local_rules(response, caplog):
    before = _failures("triage_fallback")

    with (
        patch(
            "app.services.emergency_dispatch.httpx.AsyncClient",
            _fake_http_client(response),
        ),
        caplog.at_level(logging.WARNING),
    ):
        result = await call_triage_service("chest pain", ride_id="ride-9")

    assert result["model_version"].startswith("fallback-rules-")
    assert result["severity"] == "5"  # "chest pain" is a life-threat phrase
    assert _failures("triage_fallback") == before + 1
    assert _logged(caplog, "ride-9")
    assert not _logged(caplog, "chest pain")  # symptom text is PHI


async def test_a_valid_triage_response_is_used_as_is():
    good = {**TRIAGE_RESPONSE, "severity": 4}

    with patch(
        "app.services.emergency_dispatch.httpx.AsyncClient",
        _fake_http_client(_FakeResponse(good)),
    ):
        result = await call_triage_service("sore knee")

    assert result["specialty"] == "cardiology"
    assert str(result["severity"]) == "4"
    assert result["model_version"] == "rules-v1"


async def test_fallback_triage_uses_the_vendored_rules_when_the_service_is_down():
    before = _failures("triage_fallback")

    with patch(
        "app.services.emergency_dispatch.httpx.AsyncClient",
        side_effect=httpx.ConnectError("down"),
    ):
        result = await call_triage_service("he can’t breathe")

    assert result["severity"] == "5"
    assert result["rule_override"] is True
    assert _failures("triage_fallback") == before + 1


async def test_a_bug_in_the_triage_call_is_not_swallowed():
    with patch(
        "app.services.emergency_dispatch.httpx.AsyncClient",
        side_effect=TypeError("programming error"),
    ):
        with pytest.raises(TypeError):
            await call_triage_service("chest pain")


@pytest.mark.parametrize("bad_severity", ["9", "", None, "high", 7, "0"])
def test_unusable_severity_is_escalated_never_downgraded(bad_severity):
    triage = normalise_triage(
        {"specialty": "cardiology", "severity": bad_severity}, "sore knee"
    )

    assert triage["severity"] == "5"


@pytest.mark.parametrize("bad_specialty", ["bogus", "", None, 12, ["cardiology"]])
def test_unknown_specialty_becomes_general_emergency(bad_specialty):
    triage = normalise_triage({"specialty": bad_specialty, "severity": "3"}, "sore knee")

    assert triage["specialty"] == "general_emergency"
    assert triage["severity"] == "3"


def test_a_life_threat_phrase_forces_severity_five_whatever_the_service_said():
    triage = normalise_triage(
        {"specialty": "ent", "severity": "2", "rule_override": False},
        "he is unconscious and not breathing",
    )

    assert triage["severity"] == "5"
    assert triage["rule_override"] is True


def test_normalise_triage_does_not_mutate_its_input():
    raw = {"specialty": "bogus", "severity": "9"}

    normalise_triage(raw, "sore knee")

    assert raw == {"specialty": "bogus", "severity": "9"}


async def test_stored_triage_matches_what_dispatch_acted_on(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await _only_these_drivers(db, [driver.id])
    garbage = {**TRIAGE_RESPONSE, "severity": "9", "specialty": "bogus"}

    with patch(
        "app.services.emergency_dispatch.call_triage_service",
        new=AsyncMock(return_value=garbage),
    ):
        result = await dispatch_emergency(ride, "sore knee", db)

    stored = (
        await db.execute(select(TriageEvent).where(TriageEvent.ride_id == ride_id))
    ).scalar_one()
    assert stored.severity_level == SeverityLevel.five
    assert stored.predicted_specialty == Specialty.general_emergency
    assert result["severity"] == "5"
    assert result["triage_specialty"] == "general_emergency"


async def test_a_retry_reuses_the_stored_triage_instead_of_asking_again(db):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status=DriverStatus.offline)
    )
    await _only_these_drivers(db, [driver_id])
    service = AsyncMock(return_value=TRIAGE_RESPONSE)

    with patch("app.services.emergency_dispatch.call_triage_service", new=service):
        first = await dispatch_emergency(ride, "chest pain", db)  # no driver yet
        await db.execute(
            update(Driver)
            .where(Driver.id == driver_id)
            .values(status=DriverStatus.available)
        )
        await db.commit()
        second = await dispatch_emergency(ride, "chest pain", db)

    assert "error" in first and "driver_id" in second
    assert service.await_count == 1
    count = (
        await db.execute(
            select(func.count())
            .select_from(TriageEvent)
            .where(TriageEvent.ride_id == ride_id)
        )
    ).scalar()
    assert count == 1


async def test_recording_triage_twice_keeps_the_first_result(db):
    ride, _, _ = await _seed(db)
    first = normalise_triage({**TRIAGE_RESPONSE, "severity": "4"}, "sore knee")
    second = normalise_triage({**TRIAGE_RESPONSE, "severity": "2"}, "sore knee")

    stored_first = await record_triage(db, ride.id, "sore knee", first)
    stored_second = await record_triage(db, ride.id, "sore knee", second)

    assert stored_first["severity"] == stored_second["severity"] == "4"


# ── 3d. the complaint is saved with the ride ─────────────────────────────────


async def test_emergency_creation_saves_the_symptom_text(db):
    ride, _, _ = await _seed(db)
    patient = (
        await db.execute(select(Patient).where(Patient.id == ride.patient_id))
    ).scalar_one()
    # one active emergency per patient: close the seeded one first
    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.cancelled)
    )
    await db.commit()
    body = EmergencyRideRequest(
        pickup_lat=PATIENT_LAT, pickup_lng=PATIENT_LNG, symptom_text="severe headache"
    )

    created = await ride_service.create_emergency_ride(patient, body, db)

    assert created.symptom_text == "severe headache"


async def test_loop_triages_the_saved_complaint_not_a_placeholder(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(symptom_text="he is unconscious", requested_at=_ago(60))
    )
    await _only_these_pending(db, [ride_id])
    await _only_these_drivers(db, [driver.id])
    service = AsyncMock(return_value=TRIAGE_RESPONSE)

    with patch("app.services.emergency_dispatch.call_triage_service", new=service):
        await retry_pending_dispatches()

    assert "he is unconscious" in {c.args[0] for c in service.await_args_list}


async def test_an_emergency_without_saved_text_is_never_called_scheduled_transport(db):
    ride, _, _ = await _seed(db)

    text = await _symptoms(db, ride)

    assert "scheduled" not in text


# ── 4. driver liveness and acknowledgement ───────────────────────────────────


async def test_drivers_with_stale_or_missing_location_reports_are_not_candidates(db):
    _, fresh, _ = await _seed(db)
    _, stale, _ = await _seed(db)
    _, never, _ = await _seed(db)
    fresh_id, stale_id, never_id = fresh.id, stale.id, never.id
    await db.execute(
        update(Driver).where(Driver.id == stale_id).values(last_seen_at=_ago(600))
    )
    await db.execute(
        update(Driver).where(Driver.id == never_id).values(last_seen_at=None)
    )
    await db.commit()

    found = {d.id for d in await find_available_drivers_by_distance(db, PATIENT_LAT, PATIENT_LNG)}

    assert fresh_id in found
    assert stale_id not in found
    assert never_id not in found


async def test_ride_not_acknowledged_by_its_driver_goes_back_to_the_queue(db):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id, patient_id = ride.id, driver.id, ride.patient_id
    await db.execute(
        update(Driver).where(Driver.id == driver_id).values(status=DriverStatus.busy)
    )
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(
            status=RideStatus.driver_assigned,
            driver_id=driver_id,
            driver_assigned_at=_ago(DRIVER_ACK_TIMEOUT_SECONDS + 30),
        )
    )
    await _only_these_pending(db, [ride_id])
    notify = AsyncMock(return_value=True)

    with (
        patch.object(dispatch_loop, "notify_user", notify),
        patch.object(dispatch_loop, "dispatch_emergency", AsyncMock()),
    ):
        await retry_pending_dispatches()

    stored = await _ride(db, ride_id)
    assert stored.status == RideStatus.pending
    assert stored.driver_id is None
    assert stored.driver_assigned_at is None
    assert stored.queued_at > _ago(30)
    unresponsive = (
        await db.execute(select(Driver.status).where(Driver.id == driver_id))
    ).scalar_one()
    assert unresponsive == DriverStatus.offline
    assert patient_id in {c.kwargs["patient_id"] for c in notify.await_args_list}


@pytest.mark.parametrize(
    "status, assigned_ago",
    [
        (RideStatus.driver_assigned, 10),  # still inside the window
        (RideStatus.driver_en_route, 600),  # the driver did set off
    ],
)
async def test_a_driver_who_responded_in_time_keeps_the_ride(db, status, assigned_ago):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(status=status, driver_id=driver_id, driver_assigned_at=_ago(assigned_ago))
    )
    await db.commit()

    with patch.object(dispatch_loop, "dispatch_emergency", AsyncMock()):
        await retry_pending_dispatches()

    stored = await _ride(db, ride_id)
    assert stored.status == status
    assert stored.driver_id == driver_id


# ── 5. one bad ride cannot poison the batch ──────────────────────────────────


async def _three_stale_rides(db):
    seeded = [await _seed(db) for _ in range(3)]
    ride_ids = [ride.id for ride, _, _ in seeded]
    driver_ids = [driver.id for _, driver, _ in seeded]
    for ride_id, age in zip(ride_ids, (300, 200, 100)):
        await db.execute(
            update(Ride)
            .where(Ride.id == ride_id)
            .values(requested_at=_ago(age), queued_at=_ago(age))
        )
    await db.commit()
    await _only_these_pending(db, ride_ids)
    await _only_these_drivers(db, driver_ids)
    return ride_ids


async def test_one_failing_ride_does_not_stop_the_rest_of_the_batch(db, caplog):
    ride_ids = await _three_stale_rides(db)
    poisoned = ride_ids[0]  # the oldest, so it is dispatched first
    real_dispatch = dispatch_emergency

    async def fail_then_delegate(ride, symptom_text, session):
        if ride.id == poisoned:
            await session.rollback()  # expires everything loaded in this session
            raise RuntimeError("boom")
        return await real_dispatch(ride, symptom_text, session)

    with (
        TRIAGE,
        patch.object(dispatch_loop, "dispatch_emergency", fail_then_delegate),
        caplog.at_level(logging.ERROR),
    ):
        await retry_pending_dispatches()

    assert (await _ride(db, poisoned)).status == RideStatus.pending
    for healthy in ride_ids[1:]:
        assert (await _ride(db, healthy)).status == RideStatus.driver_assigned
    assert _logged(caplog, "retry dispatch failed", str(poisoned), "RuntimeError")


# ── 6. most severe first ─────────────────────────────────────────────────────


async def test_retry_order_is_severity_first_then_longest_waiting(db):
    seeded = [await _seed(db) for _ in range(5)]
    ride_ids = [ride.id for ride, _, _ in seeded]
    untriaged, sev3, sev5_recent, sev5_old, sev4 = ride_ids
    ages = {untriaged: 50, sev3: 400, sev5_recent: 100, sev5_old: 300, sev4: 350}
    severities = {
        sev3: SeverityLevel.three,
        sev5_recent: SeverityLevel.five,
        sev5_old: SeverityLevel.five,
        sev4: SeverityLevel.four,
    }
    for ride_id, age in ages.items():
        await db.execute(
            update(Ride)
            .where(Ride.id == ride_id)
            .values(requested_at=_ago(age), queued_at=_ago(age))
        )
    for ride_id, severity in severities.items():
        db.add(
            TriageEvent(
                ride_id=ride_id,
                symptom_text="x",
                predicted_specialty=Specialty.general_emergency,
                confidence_score=0.5,
                severity_level=severity,
                model_version="test",
            )
        )
    await db.commit()
    await _only_these_pending(db, ride_ids)
    order = []

    async def record(ride, symptom_text, session):
        order.append(ride.id)
        return {}

    with patch.object(dispatch_loop, "dispatch_emergency", record):
        await retry_pending_dispatches()

    # unknown severity is treated as the worst; ties go to whoever waited longest
    assert order == [untriaged, sev5_old, sev5_recent, sev4, sev3]


# ── 7. a requeued ride gets a fresh window ───────────────────────────────────


async def test_a_ride_given_back_by_its_driver_is_not_expired_at_once(
    client, verified_driver_token, db
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    requeued = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")
    assert requeued.json()["status"] == "pending"
    # asked for 20 minutes ago, but only put back in the queue just now
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(requested_at=_ago(1200))
    )
    await db.commit()

    with patch.object(dispatch_loop, "dispatch_emergency", AsyncMock()):
        await retry_pending_dispatches()

    assert (await _ride(db, ride_id)).status == RideStatus.pending


async def test_a_ride_that_has_waited_in_the_queue_too_long_is_expired(db, caplog):
    ride, _, _ = await _seed(db)
    ride_id = ride.id
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(requested_at=_ago(3600), queued_at=_ago(3600))
    )
    await db.commit()

    with (
        patch.object(dispatch_loop, "dispatch_emergency", AsyncMock()),
        patch.object(dispatch_loop, "notify_user", AsyncMock(return_value=False)),
        caplog.at_level(logging.ERROR),
    ):
        await retry_pending_dispatches()

    assert (await _ride(db, ride_id)).status == RideStatus.cancelled
    assert _logged(caplog, "NOT told to call 1122", str(ride_id))


# ── 9. drivers only see rides they could reach ───────────────────────────────


async def test_pending_list_only_contains_rides_within_the_search_radius(db):
    near, _, _ = await _seed(db)
    far, _, _ = await _seed(db)
    near_id, far_id = near.id, far.id
    await db.execute(
        update(Ride)
        .where(Ride.id == far_id)
        .values(pickup_lat=PATIENT_LAT + 5)  # roughly 550 km away
    )
    await db.commit()
    driver = SimpleNamespace(current_lat=PATIENT_LAT, current_lng=PATIENT_LNG)

    ids = {r.id for r in await ride_service.get_pending_rides(driver, db)}

    assert near_id in ids
    assert far_id not in ids


async def test_pending_list_is_empty_for_a_driver_with_no_known_location(db):
    await _seed(db)
    driver = SimpleNamespace(current_lat=None, current_lng=None)

    assert await ride_service.get_pending_rides(driver, db) == []


# ── 10. a lost status push is visible ────────────────────────────────────────


async def test_a_status_push_that_could_not_be_sent_is_logged(
    client, verified_driver_token, caplog
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    with patch.object(
        ride_service, "notify_user", AsyncMock(return_value=False)
    ), caplog.at_level(logging.WARNING):
        r = await _set_ride_status(
            client, verified_driver_token, ride_id, "driver_en_route"
        )

    assert r.status_code == 200
    assert _logged(caplog, "status push not sent", ride_id)


# ── 11. startup warning ──────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "loop_enabled, debug, should_warn",
    [(False, False, True), (False, True, False), (True, False, False)],
)
def test_startup_warns_when_the_only_retry_mechanism_is_off(
    caplog, monkeypatch, loop_enabled, debug, should_warn
):
    monkeypatch.setattr(main.settings, "DISPATCH_LOOP_ENABLED", loop_enabled)
    monkeypatch.setattr(main.settings, "DEBUG", debug)

    with caplog.at_level(logging.WARNING, logger="smartride"):
        main._warn_if_dispatch_loop_disabled()

    assert _logged(caplog, "DISPATCH_LOOP_ENABLED") is should_warn
    if should_warn:
        assert any(r.levelno == logging.WARNING for r in caplog.records)


# ── severity strings "1".."5" must round-trip through the real enum type ─────


def test_severity_enum_stores_the_values_the_migration_created():
    column = TriageEvent.__table__.c.severity_level
    assert column.type.enums == ["1", "2", "3", "4", "5"]


@pytest.mark.parametrize("severity", ["1", "2", "3", "4", "5"])
async def test_every_severity_is_stored_and_acted_on_end_to_end(db, severity):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await _only_these_drivers(db, [driver.id])
    # benign text so the life-threat rules cannot lift the service's own severity
    service = AsyncMock(return_value={**TRIAGE_RESPONSE, "severity": severity})

    with patch("app.services.emergency_dispatch.call_triage_service", new=service):
        result = await dispatch_emergency(ride, "sore knee", db)

    raw = (
        await db.execute(
            text("SELECT severity_level::text FROM triage_events WHERE ride_id = :r"),
            {"r": ride_id},
        )
    ).scalar_one()
    assert raw == severity
    assert result["severity"] == severity
    assert (await load_stored_triage(db, ride_id))["severity"] == severity
