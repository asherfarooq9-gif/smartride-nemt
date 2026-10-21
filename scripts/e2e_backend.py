"""Start the API for end-to-end tests: fresh database -> migrations -> seed -> uvicorn.

Run by Playwright's `webServer` (admin-dashboard/playwright.config.ts), which stops
it when the run ends. It needs Postgres and Redis (e.g. `docker compose up -d
postgres redis`) and the backend's dependencies in the interpreter running this
script. It only ever touches the throwaway `smartride_e2e` database and Redis db 2.
"""

import asyncio
import os
import subprocess
import sys
from pathlib import Path

import asyncpg
import redis

BACKEND_DIR = Path(__file__).resolve().parent.parent / "backend"
PG_HOST = os.getenv("E2E_PG_HOST", "localhost:5432")
PG_AUTH = os.getenv("E2E_PG_AUTH", "smartride:password")
DB_NAME = "smartride_e2e"
REDIS_URL = os.getenv("E2E_REDIS_URL", "redis://localhost:6379/2")
API_PORT = os.getenv("E2E_API_PORT", "18010")
ADMIN_ORIGIN = os.getenv("E2E_ADMIN_ORIGIN", "http://localhost:13100")

ENV = {
    **os.environ,
    "DATABASE_URL": f"postgresql+asyncpg://{PG_AUTH}@{PG_HOST}/{DB_NAME}",
    "REDIS_URL": REDIS_URL,
    "SECRET_KEY": "e2e-secret-key-not-for-production-0123456789",
    "ALLOWED_ORIGINS": f'["{ADMIN_ORIGIN}"]',
    "TRIAGE_SERVICE_URL": "http://localhost:9",  # unreachable: exercises the fallback
    "DEBUG": "false",
    # Many sign-ups and logins from one IP in a test run:
    "LOGIN_RATE_LIMIT": "1000/minute",
    "REGISTER_RATE_LIMIT": "1000/minute",
    "ADMIN_PASSWORD": "admin123",  # throwaway database only
}


async def recreate_database() -> None:
    conn = await asyncpg.connect(f"postgresql://{PG_AUTH}@{PG_HOST}/postgres")
    try:
        await conn.execute(f'DROP DATABASE IF EXISTS "{DB_NAME}" WITH (FORCE)')
        await conn.execute(f'CREATE DATABASE "{DB_NAME}"')
    finally:
        await conn.close()


def run(*args: str) -> None:
    subprocess.run(args, cwd=BACKEND_DIR, env=ENV, check=True)


def main() -> int:
    asyncio.run(recreate_database())
    redis.Redis.from_url(REDIS_URL).flushdb()
    # The local ./alembic directory shadows the package for `python -m alembic`.
    scripts = Path(sys.executable).parent
    alembic = scripts / ("alembic.exe" if os.name == "nt" else "alembic")
    run(str(alembic), "upgrade", "head")
    run(sys.executable, "seed.py")
    return subprocess.call(
        [sys.executable, "-m", "uvicorn", "main:app", "--port", API_PORT],
        cwd=BACKEND_DIR,
        env=ENV,
    )


if __name__ == "__main__":
    raise SystemExit(main())
