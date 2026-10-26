"""Two instances starting together must not run migrations at the same time."""

import asyncio
import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from app.core.migration_lock import MIGRATION_LOCK_ID
from tests.conftest import TEST_DATABASE_URL

BACKEND_DIR = Path(__file__).resolve().parent.parent
SCRATCH_DB = make_url(TEST_DATABASE_URL).database + "_miglock"


def _url_for(database: str) -> str:
    return make_url(TEST_DATABASE_URL).set(database=database).render_as_string(False)


async def _admin(sql: str) -> None:
    engine = create_async_engine(
        _url_for("postgres"), poolclass=NullPool, isolation_level="AUTOCOMMIT"
    )
    async with engine.connect() as conn:
        await conn.exec_driver_sql(sql)
    await engine.dispose()


async def test_upgrade_waits_for_the_migration_lock_then_finishes():
    await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')
    await _admin(f'CREATE DATABASE "{SCRATCH_DB}"')
    engine = create_async_engine(_url_for(SCRATCH_DB), poolclass=NullPool)
    proc = None
    try:
        # Another instance is mid-migration: it holds the lock.
        holder = await engine.connect()
        await holder.execute(
            text("SELECT pg_advisory_xact_lock(:id)"), {"id": MIGRATION_LOCK_ID}
        )
        binary = Path(sys.executable).parent / (
            "alembic.exe" if os.name == "nt" else "alembic"
        )
        proc = subprocess.Popen(
            [str(binary), "upgrade", "head"],
            cwd=BACKEND_DIR,
            env={**os.environ, "DATABASE_URL": _url_for(SCRATCH_DB)},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        await asyncio.sleep(8)

        assert proc.poll() is None, "upgrade finished while the lock was held"
        async with engine.connect() as probe:
            tables = (
                await probe.execute(text("SELECT to_regclass('public.users')"))
            ).scalar_one()
        assert tables is None, "migrations ran while another instance held the lock"

        await holder.rollback()  # the other instance finishes; the lock is released
        await holder.close()
        _, err = await asyncio.to_thread(proc.communicate, None, 120)
        assert proc.returncode == 0, err[-2000:]
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
        await engine.dispose()
        await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')


def _alembic_run(*args):
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


async def test_a_blocked_migration_gives_up_instead_of_stalling_the_app():
    """Old instances keep serving during a rolling deploy. A migration queued behind
    a long transaction on `rides` would also queue every new query on that table,
    so it must fail fast and let the container restart and retry."""
    await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')
    await _admin(f'CREATE DATABASE "{SCRATCH_DB}"')
    engine = create_async_engine(_url_for(SCRATCH_DB), poolclass=NullPool)
    try:
        assert (
            await asyncio.to_thread(_alembic_run, "upgrade", "0009")
        ).returncode == 0
        holder = await engine.connect()
        await holder.execute(text("LOCK TABLE rides IN ACCESS EXCLUSIVE MODE"))

        blocked = await asyncio.to_thread(_alembic_run, "upgrade", "head")

        assert blocked.returncode != 0
        assert "lock timeout" in blocked.stderr.lower(), blocked.stderr[-1500:]

        await holder.rollback()  # the long transaction ends
        await holder.close()
        retry = await asyncio.to_thread(_alembic_run, "upgrade", "head")
        assert retry.returncode == 0, retry.stderr[-1500:]
    finally:
        await engine.dispose()
        await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')
