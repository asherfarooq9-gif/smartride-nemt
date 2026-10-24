"""Migration 0007: objects exist after upgrade, ledger downgrade is guarded, round-trip works."""

import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from tests.conftest import TEST_DATABASE_URL

BACKEND_DIR = Path(__file__).resolve().parent.parent
SCRATCH_DB = make_url(TEST_DATABASE_URL).database + "_mig0007"

EXPECTED_INDEXES = {
    "ix_rides_hospital_id",
    "ix_rides_pending_requested_at",
    "ix_rides_driver_status_completed",
    "ix_drivers_available_location",
    "uq_rides_active_emergency_per_patient",
}
DROPPED_INDEXES = {"idx_patients_user", "idx_drivers_user", "ix_drivers_user_id"}
EXPECTED_CONSTRAINTS = {
    "ck_wallet_kind",
    "ck_wallet_amount_sign",
    "ck_rides_patient_rating_range",
    "uq_wallet_idempotency_key",
    "uq_triage_events_ride_id",
}


def _url_for(database: str) -> str:
    return make_url(TEST_DATABASE_URL).set(database=database).render_as_string(False)


def _alembic(*args: str) -> subprocess.CompletedProcess:
    binary = Path(sys.executable).parent / (
        "alembic.exe" if os.name == "nt" else "alembic"
    )
    return subprocess.run(
        [str(binary), *args],
        cwd=BACKEND_DIR,
        env={**os.environ, "DATABASE_URL": _url_for(SCRATCH_DB)},
        capture_output=True,
        text=True,
        timeout=120,
    )


async def _admin(sql: str) -> None:
    engine = create_async_engine(
        _url_for("postgres"), poolclass=NullPool, isolation_level="AUTOCOMMIT"
    )
    async with engine.connect() as conn:
        await conn.exec_driver_sql(sql)
    await engine.dispose()


async def _scalars(sql: str) -> set:
    engine = create_async_engine(_url_for(SCRATCH_DB), poolclass=NullPool)
    async with engine.connect() as conn:
        rows = (await conn.execute(text(sql))).scalars().all()
    await engine.dispose()
    return set(rows)


async def _execute(sql: str) -> None:
    engine = create_async_engine(_url_for(SCRATCH_DB), poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.exec_driver_sql(sql)
    await engine.dispose()


@pytest.fixture
async def scratch_db():
    await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')
    await _admin(f'CREATE DATABASE "{SCRATCH_DB}"')
    yield
    await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')


async def test_upgrade_creates_and_downgrade_removes_the_0007_objects(scratch_db):
    up = _alembic("upgrade", "head")
    assert up.returncode == 0, up.stderr[-2000:]
    indexes = await _scalars(
        "SELECT indexname FROM pg_indexes WHERE schemaname='public'"
    )
    assert EXPECTED_INDEXES <= indexes
    assert not DROPPED_INDEXES & indexes
    # 0008 dropped these never-written tables, and their indexes with them.
    assert not {"hospital_alerts", "family_notifications"} & await _scalars(
        "SELECT tablename FROM pg_tables WHERE schemaname='public'"
    )
    constraints = await _scalars("SELECT conname FROM pg_constraint")
    assert EXPECTED_CONSTRAINTS <= constraints
    assert await _scalars(
        "SELECT tgname FROM pg_trigger WHERE tgname = 'trg_wallet_append_only'"
    )
    columns = await _scalars(
        "SELECT table_name || '.' || column_name FROM information_schema.columns "
        "WHERE table_schema='public'"
    )
    assert {
        "rides.queued_at",
        "rides.symptom_text",
        "wallet_transactions.idempotency_key",
        "wallet_transactions.admin_user_id",
        "wallet_transactions.payment_method",
    } <= columns

    down = _alembic("downgrade", "0006")
    assert down.returncode == 0, down.stderr[-2000:]
    indexes = await _scalars(
        "SELECT indexname FROM pg_indexes WHERE schemaname='public'"
    )
    assert not EXPECTED_INDEXES & indexes
    assert {"idx_patients_user", "idx_drivers_user"} <= indexes
    assert (await _alembic_current()) == "0006"

    again = _alembic("upgrade", "head")
    assert again.returncode == 0, again.stderr[-2000:]


async def _alembic_current() -> str:
    (version,) = await _scalars("SELECT version_num FROM alembic_version")
    return version


async def test_downgrade_refuses_to_drop_ledger_audit_data(scratch_db):
    assert _alembic("upgrade", "head").returncode == 0
    await _execute(
        "INSERT INTO users (id, phone, password_hash, role) VALUES "
        "('00000000-0000-0000-0000-0000000000a1', '+1', 'x', 'driver')"
    )
    await _execute(
        "INSERT INTO drivers (id, user_id, full_name, license_no, vehicle_plate, vehicle_type) "
        "VALUES ('10000000-0000-0000-0000-0000000000a1', "
        "'00000000-0000-0000-0000-0000000000a1', 'd', 'l', 'p', 'v')"
    )
    await _execute(
        "INSERT INTO wallet_transactions (id, driver_id, kind, amount, idempotency_key) "
        "VALUES (gen_random_uuid(), '10000000-0000-0000-0000-0000000000a1', "
        "'topup', 5, 'k')"
    )

    down = _alembic("downgrade", "0006")

    assert down.returncode != 0
    assert "Refusing to downgrade 0007" in down.stderr
    # The whole downgrade is one transaction, so 0008's step is rolled back too.
    assert (await _alembic_current()) == "0008"
    assert await _scalars("SELECT idempotency_key FROM wallet_transactions") == {"k"}
