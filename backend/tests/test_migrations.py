"""Migration/model parity.

The rest of the suite builds its schema with Base.metadata.create_all, so a model
column that no Alembic migration creates is invisible to it (this is how
users.fcm_token shipped without a migration). This test runs the real migrations
on an empty scratch database and requires every model column to exist.
"""

import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy import inspect
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from app.core.database import Base
import app.models.models  # noqa: F401  (register all models on Base.metadata)
from tests.conftest import TEST_DATABASE_URL

BACKEND_DIR = Path(__file__).resolve().parent.parent
# Derived from the test database name so concurrent runs never share a scratch DB.
SCRATCH_DB = make_url(TEST_DATABASE_URL).database + "_parity"


def _url_for(database: str) -> str:
    return make_url(TEST_DATABASE_URL).set(database=database).render_as_string(False)


async def _admin(sql: str) -> None:
    engine = create_async_engine(
        _url_for("postgres"), poolclass=NullPool, isolation_level="AUTOCOMMIT"
    )
    async with engine.connect() as conn:
        await conn.exec_driver_sql(sql)
    await engine.dispose()


async def _migrated_columns() -> dict[str, set[str]]:
    engine = create_async_engine(_url_for(SCRATCH_DB), poolclass=NullPool)
    async with engine.connect() as conn:

        def read(sync_conn):
            insp = inspect(sync_conn)
            return {
                t: {c["name"] for c in insp.get_columns(t)}
                for t in insp.get_table_names()
            }

        columns = await conn.run_sync(read)
    await engine.dispose()
    return columns


async def test_every_model_column_is_created_by_migrations():
    await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}"')
    await _admin(f'CREATE DATABASE "{SCRATCH_DB}"')
    try:
        # The `alembic` console script is used because the local ./alembic
        # directory shadows the package for `python -m alembic`.
        alembic_bin = Path(sys.executable).parent / (
            "alembic.exe" if os.name == "nt" else "alembic"
        )
        result = subprocess.run(
            [str(alembic_bin), "upgrade", "head"],
            cwd=BACKEND_DIR,
            env={**os.environ, "DATABASE_URL": _url_for(SCRATCH_DB)},
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, result.stderr[-2000:]

        migrated = await _migrated_columns()
        missing = [
            f"{table.name}.{column.name}"
            for table in Base.metadata.sorted_tables
            for column in table.columns
            if column.name not in migrated.get(table.name, set())
        ]
        assert not missing, f"model columns with no migration: {missing}"
    finally:
        await _admin(f'DROP DATABASE IF EXISTS "{SCRATCH_DB}" WITH (FORCE)')
