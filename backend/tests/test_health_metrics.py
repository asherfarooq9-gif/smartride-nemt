"""The gauges the alert rules watch, and the rules themselves."""

import re
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import pytest_asyncio
from prometheus_client import REGISTRY
from sqlalchemy import update

from app.core.database import engine
from app.models.models import Driver, Ride, RideStatus
from app.services import health_metrics
from tests.test_dispatch_endpoints import _create_emergency, _register
from tests.test_ride_lifecycle import _phone

ALERTS = (
    Path(__file__).resolve().parents[2] / "monitoring" / "prometheus" / "alerts.yml"
)


@pytest_asyncio.fixture(autouse=True)
async def _fresh_app_engine():
    await engine.dispose()
    yield
    await engine.dispose()


def _gauge(name: str, **labels) -> float:
    return REGISTRY.get_sample_value(name, labels)


def test_every_metric_an_alert_uses_is_defined():
    """A rule on a metric nobody exports never fires, and nobody notices."""
    if not ALERTS.exists():
        pytest.skip("monitoring/ not present (running outside the repo)")
    defined = {family.name for family in REGISTRY.collect()}
    used = set(re.findall(r"\bsmartride_[a-z_]+", ALERTS.read_text()))
    unknown = {
        name
        for name in used
        if re.sub(r"_(total|bucket|count|sum)$", "", name) not in defined
    }
    assert not unknown, (
        f"alerts.yml uses metrics that are not defined: {sorted(unknown)}"
    )


async def test_database_and_redis_report_up(db):
    await health_metrics.record_health_metrics()

    assert _gauge("smartride_dependency_up", dependency="database") == 1
    assert _gauge("smartride_dependency_up", dependency="redis") == 1


async def test_a_broken_database_reports_down_and_never_raises(monkeypatch):
    def broken():
        raise OSError("db down")

    monkeypatch.setattr(health_metrics, "AsyncSessionLocal", broken)

    await health_metrics.record_health_metrics()

    assert _gauge("smartride_dependency_up", dependency="database") == 0


async def test_oldest_pending_ride_age_tracks_the_longest_wait(client, db):
    token = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, token)
    await db.execute(
        update(Ride).values(status=RideStatus.cancelled).where(Ride.id != ride_id)
    )
    await db.execute(
        update(Ride)
        .where(Ride.id == ride_id)
        .values(queued_at=datetime.now(timezone.utc) - timedelta(seconds=300))
    )
    await db.commit()

    await health_metrics.record_health_metrics()

    assert 290 <= _gauge("smartride_oldest_pending_ride_age_seconds") < 400


async def test_no_pending_rides_reads_zero(client, db):
    await db.execute(
        update(Ride)
        .where(Ride.status == RideStatus.pending)
        .values(status=RideStatus.cancelled)
    )
    await db.commit()

    await health_metrics.record_health_metrics()

    assert _gauge("smartride_oldest_pending_ride_age_seconds") == 0


async def test_a_balance_that_differs_from_the_ledger_is_counted(
    client, db, verified_driver_token
):
    await health_metrics.record_health_metrics()
    clean = _gauge("smartride_wallet_ledger_mismatch_drivers")

    me = await client.get(
        "/api/v1/drivers/me",
        headers={"Authorization": f"Bearer {verified_driver_token}"},
    )
    # A balance changed without a ledger row is exactly what the alert is for.
    await db.execute(
        update(Driver)
        .where(Driver.id == me.json()["id"])
        .values(wallet_balance_pkr=Driver.wallet_balance_pkr + 123)
    )
    await db.commit()

    await health_metrics.record_health_metrics()

    assert _gauge("smartride_wallet_ledger_mismatch_drivers") == clean + 1


async def test_a_dispatch_pass_records_when_it_last_succeeded(monkeypatch):
    from app.services import dispatch_loop

    async def quiet_pass():
        return None

    monkeypatch.setattr(dispatch_loop, "retry_pending_dispatches", quiet_pass)
    before = time.time()

    await dispatch_loop.run_pass()

    stamp = _gauge("smartride_dispatch_loop_last_success_timestamp_seconds")
    assert before - 1 <= stamp <= time.time() + 1


async def test_a_failed_pass_does_not_move_the_success_stamp(monkeypatch):
    from app.services import dispatch_loop

    async def quiet_pass():
        return None

    monkeypatch.setattr(dispatch_loop, "retry_pending_dispatches", quiet_pass)
    await dispatch_loop.run_pass()
    stamp = _gauge("smartride_dispatch_loop_last_success_timestamp_seconds")

    async def failing_pass():
        raise RuntimeError("boom")

    monkeypatch.setattr(dispatch_loop, "retry_pending_dispatches", failing_pass)
    await dispatch_loop.run_pass()

    assert _gauge("smartride_dispatch_loop_last_success_timestamp_seconds") == stamp
