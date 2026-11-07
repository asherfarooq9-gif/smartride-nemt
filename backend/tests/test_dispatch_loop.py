"""Dispatch must not give up: stale rides are retried, expired ones are closed."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest_asyncio
from sqlalchemy import select, update

from app.core.config import settings
from app.core.database import engine
from app.models.models import (
    Driver,
    DriverStatus,
    Ride,
    RideStatus,
    TriageEvent,
    User,
)
from app.services.dispatch_loop import retry_pending_dispatches
from app.services.dispatch_loop import DRIVER_ACK_TIMEOUT_SECONDS
from app.services.emergency_dispatch import DRIVER_FRESH_SECONDS, dispatch_emergency
from tests.test_dispatch import TRIAGE_RESPONSE, _seed
from tests.test_ride_lifecycle import _assigned_ride, _auth, _phone, _set_ride_status

TRIAGE = patch(
    "app.services.emergency_dispatch.call_triage_service",
    new=AsyncMock(return_value=TRIAGE_RESPONSE),
)


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_engine():
    """The app's pooled engine binds to the loop that first used it; each test has its own."""
    await engine.dispose()  # drop connections left over from tests on other loops
    yield
    await engine.dispose()


def _ago(seconds: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(seconds=seconds)


async def _isolate(db, driver_id, ride_id, *, available: bool) -> None:
    """Keep only the pair under test in play.

    The loop is global by nature, so other pending rides are cancelled. Drivers are
    scoped: only ones recent enough to be dispatch candidates are touched, and the
    driver under test is made fresh (or offline) explicitly.
    """
    await db.execute(
        update(Ride)
        .where(
            Ride.id != ride_id,
            (Ride.status == RideStatus.pending)
            | (
                (Ride.status == RideStatus.driver_assigned)
                & (Ride.driver_assigned_at < _ago(DRIVER_ACK_TIMEOUT_SECONDS))
            ),
        )
        .values(status=RideStatus.cancelled)
    )
    await db.execute(
        update(Driver)
        .where(Driver.last_seen_at >= _ago(DRIVER_FRESH_SECONDS))
        .values(status=DriverStatus.offline)
    )
    await db.execute(
        update(Driver)
        .where(Driver.id == driver_id)
        .values(
            status=DriverStatus.available if available else DriverStatus.offline,
            last_seen_at=_ago(0),
        )
    )
    await db.commit()


async def _ride(db, ride_id) -> Ride:
    db.expire_all()
    return (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()


async def test_stale_ride_is_assigned_once_a_driver_appears(db):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(requested_at=_ago(60))
    )
    await _isolate(db, driver_id, ride_id, available=False)

    with TRIAGE:
        await retry_pending_dispatches()
    assert (await _ride(db, ride_id)).status == RideStatus.pending

    await _isolate(db, driver_id, ride_id, available=True)
    with TRIAGE:
        await retry_pending_dispatches()

    stored = await _ride(db, ride_id)
    assert stored.status == RideStatus.driver_assigned
    assert stored.driver_id == driver_id


async def test_fresh_ride_is_left_to_the_first_dispatch(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await _isolate(db, driver.id, ride_id, available=True)

    with TRIAGE:
        await retry_pending_dispatches()

    assert (await _ride(db, ride_id)).status == RideStatus.pending


async def test_ride_nobody_accepted_is_cancelled_after_the_max_age(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(requested_at=_ago(3600), queued_at=_ago(3600))
    )
    await _isolate(db, driver.id, ride_id, available=False)

    with TRIAGE:
        await retry_pending_dispatches()

    stored = await _ride(db, ride_id)
    assert stored.status == RideStatus.cancelled
    assert "no driver" in stored.cancel_reason.lower()


async def test_scheduled_ride_is_dispatched_when_it_falls_due(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    soon = datetime.now(timezone.utc) + timedelta(minutes=10)
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(ride_type="scheduled", scheduled_for=soon, requested_at=_ago(3600))
    )
    await _isolate(db, driver.id, ride_id, available=True)

    with TRIAGE:
        await retry_pending_dispatches()

    assert (await _ride(db, ride_id)).status == RideStatus.driver_assigned


async def test_scheduled_ride_far_in_the_future_is_left_alone(db):
    ride, driver, _ = await _seed(db)
    ride_id = ride.id
    later = datetime.now(timezone.utc) + timedelta(days=2)
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(ride_type="scheduled", scheduled_for=later, requested_at=_ago(3600))
    )
    await _isolate(db, driver.id, ride_id, available=True)

    with TRIAGE:
        await retry_pending_dispatches()

    assert (await _ride(db, ride_id)).status == RideStatus.pending


async def test_driver_cancelling_puts_the_ride_back_in_the_queue(
    client, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "pending"
    assert r.json()["driver_id"] is None
    me = await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    # offline, so the same driver is not immediately handed the ride again
    assert me.json()["status"] == "offline"


async def test_dispatch_records_triage_and_pushes_to_the_driver(db):
    ride, driver, _ = await _seed(db)
    ride_id, driver_id = ride.id, driver.id
    await _isolate(db, driver_id, ride_id, available=True)
    driver_user = (
        await db.execute(
            select(User)
            .join(Driver, Driver.user_id == User.id)
            .where(Driver.id == driver_id)
        )
    ).scalar_one()
    driver_user.fcm_token = "driver-device-token"
    await db.commit()

    push = AsyncMock()
    with TRIAGE, patch("app.services.notifications.send_push", push):
        await dispatch_emergency(ride, "chest pain and sweating", db)
        # the push is fire-and-forget; let it run
        import asyncio

        await asyncio.sleep(0)

    events = (
        (await db.execute(select(TriageEvent).where(TriageEvent.ride_id == ride_id)))
        .scalars()
        .all()
    )
    assert [e.symptom_text for e in events] == ["chest pain and sweating"]
    assert any(
        c.kwargs["fcm_token"] == "driver-device-token" for c in push.call_args_list
    )


async def test_expired_ride_also_texts_the_patient_to_call_1122(client, db):
    from app.services import dispatch_loop
    from tests.test_dispatch_endpoints import _create_emergency, _register

    patient_token = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient_token)
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(queued_at=_ago(settings.DISPATCH_MAX_AGE_SECONDS + 60))
    )
    await db.commit()
    patient_id = (
        await db.execute(select(Ride.patient_id).where(Ride.id == ride_id))
    ).scalar_one()

    with (
        patch(
            "app.services.dispatch_loop.notify_user", new=AsyncMock(return_value=True)
        ),
        patch(
            "app.services.dispatch_loop.send_sms_to_patient",
            new=AsyncMock(return_value=True),
        ) as sms,
    ):
        await dispatch_loop._expire(db, datetime.now(timezone.utc))

    assert (await _ride(db, ride_id)).status == RideStatus.cancelled
    texted = {c.kwargs["patient_id"]: c.kwargs["body"] for c in sms.await_args_list}
    assert "1122" in texted[patient_id]


async def test_a_severity_level_runs_together_and_the_next_waits_for_it(monkeypatch):
    """A surge must not make rides of one severity queue behind each other, but a
    less severe ride must never start before the more severe ones have finished."""
    import asyncio

    from app.models.models import SeverityLevel
    from app.services import dispatch_loop

    pending = [(f"s5-{i}", SeverityLevel.five) for i in range(4)] + [
        (f"s4-{i}", SeverityLevel.four) for i in range(2)
    ]
    started, finished, running, peak = [], [], 0, 0

    async def slow_dispatch(ride_id):
        nonlocal running, peak
        started.append(ride_id)
        running += 1
        peak = max(peak, running)
        await asyncio.sleep(0.05)
        running -= 1
        finished.append(ride_id)

    async def no_op(*_args, **_kwargs):
        return None

    async def fixed(*_args, **_kwargs):
        return pending

    monkeypatch.setattr(dispatch_loop, "_expire", no_op)
    monkeypatch.setattr(dispatch_loop, "_requeue_unacknowledged", no_op)
    monkeypatch.setattr(dispatch_loop, "_pending_rides", fixed)
    monkeypatch.setattr(dispatch_loop, "_dispatch_one", slow_dispatch)
    monkeypatch.setattr(settings, "DISPATCH_CONCURRENCY", 3)

    await dispatch_loop.retry_pending_dispatches()

    assert 1 < peak <= 3
    first_sev4 = started.index("s4-0")
    assert {r for r in started[:first_sev4]} == {f"s5-{i}" for i in range(4)}
    assert {f"s5-{i}" for i in range(4)} <= set(
        finished[:4]
    )  # all done before sev4 began
