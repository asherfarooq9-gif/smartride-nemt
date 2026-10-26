import asyncio
import os
import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.engine import make_url
from sqlalchemy.pool import NullPool

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test",
)


def _require_test_database(url: str) -> None:
    """The suite runs drop_all(); refuse to touch any database not named *_test."""
    database = make_url(url).database or ""
    if not database.endswith("_test"):
        raise RuntimeError(
            f"Refusing to run tests: TEST_DATABASE_URL database {database!r} must end "
            "with '_test' because the suite drops and recreates every table in it."
        )


_require_test_database(TEST_DATABASE_URL)

os.environ.setdefault("DATABASE_URL", TEST_DATABASE_URL)
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only-0123456789")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("TRIAGE_SERVICE_URL", "http://localhost:8001")
os.environ.setdefault("ALLOWED_ORIGINS", '["http://localhost:3000"]')

from app.core.database import Base, get_db  # noqa: E402
from main import app, limiter as _main_limiter  # noqa: E402
from app.routers.auth import limiter as _auth_limiter  # noqa: E402
from app.routers.drivers import limiter as _drivers_limiter  # noqa: E402
from app.routers.rides import limiter as _rides_limiter  # noqa: E402

# Rate limits would otherwise reject the many register/login calls the suite
# makes from a single client IP. Disable them under test.
_main_limiter.enabled = False
_auth_limiter.enabled = False
_rides_limiter.enabled = False
_drivers_limiter.enabled = False


async def _run_ddl() -> None:
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    asyncio.run(_run_ddl())


@pytest.fixture(autouse=True)
def _summary_cache_off(monkeypatch):
    """The dashboard summary is cached in production. Tests that read it right after
    changing data need the live numbers, so the cache is off unless a test asks."""
    from app.core.config import settings

    monkeypatch.setattr(settings, "SUMMARY_CACHE_SECONDS", 0, raising=False)


@pytest.fixture(autouse=True)
def _clear_login_lockouts():
    """Lockout counters live in Redis and outlive a test run; tests reuse phone numbers."""
    import redis

    client = redis.Redis.from_url(os.environ["REDIS_URL"])
    for key in client.scan_iter("login_fail:*"):
        client.delete(key)
    client.close()
    yield


@pytest.fixture(autouse=True)
def _loop_safe_session_factory(monkeypatch):
    """Code that opens its own session via `database.AsyncSessionLocal` (the streamed
    CSV export) would otherwise reuse pooled connections bound to an earlier test's
    event loop. Point it at a NullPool engine for the test database."""
    import app.core.database as database

    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    monkeypatch.setattr(
        database,
        "AsyncSessionLocal",
        async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False),
    )


@pytest_asyncio.fixture(autouse=True)
async def _reset_redis_singleton():
    """The redis client is a module-level singleton bound to the event loop that
    first created it. Each pytest-asyncio test runs in its own loop, so reset the
    singleton per test (close on the same loop) to avoid 'Event loop is closed'."""
    import app.core.redis_client as rc

    rc._redis = None
    yield
    if rc._redis is not None:
        try:
            await rc._redis.aclose()
        except Exception:
            pass
        rc._redis = None


@pytest_asyncio.fixture
async def db():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
        try:
            await session.rollback()
        except Exception:
            pass
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db: AsyncSession):
    async def _override():
        yield db

    app.dependency_overrides[get_db] = _override
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def isolated_client():
    """Like production: every request gets its own session and transaction.

    `client` shares one session across calls, which is convenient for asserting on
    rows but hides (and, after a database error, inherits) transaction state.
    """
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async def _per_request():
        async with factory() as session:
            yield session

    app.dependency_overrides[get_db] = _per_request
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac
    app.dependency_overrides.clear()
    await engine.dispose()


@pytest_asyncio.fixture
async def admin_token(db: AsyncSession) -> str:
    """Create an admin user directly in the DB (self-register is blocked via API)."""
    from app.models.models import User, UserRole, UserRoleLink
    from app.core.security import hash_password, create_access_token

    user = User(
        id=uuid.uuid4(),
        phone=f"+92300{uuid.uuid4().hex[:7]}",
        password_hash=hash_password("adminpass"),
        role=UserRole.admin,
    )
    db.add(user)
    link = UserRoleLink(id=uuid.uuid4(), user_id=user.id, role=UserRole.admin)
    db.add(link)
    await db.commit()
    await db.refresh(user)

    return create_access_token(
        {
            "sub": str(user.id),
            "role": "admin",
            "roles": ["admin"],
            "active_role": "admin",
        }
    )


@pytest_asyncio.fixture
async def verified_driver_token(client: AsyncClient, db: AsyncSession) -> str:
    """Register a driver through the API and mark it verified."""
    from sqlalchemy import select
    from app.models.models import Driver, DriverStatus

    uid = uuid.uuid4().hex[:8]
    # Phone must be digits-only to pass the registration validator.
    digits = str(uuid.uuid4().int)[:7]
    resp = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": f"+92300{digits}",
            "password": "pass1234",
            "role": "driver",
            "full_name": "T",
            "license_no": f"DV-{uid}",
            "vehicle_plate": f"DV-{uid[:6]}",
            "vehicle_type": "sedan",
        },
    )
    assert resp.status_code == 201, resp.text
    driver = (
        await db.execute(select(Driver).order_by(Driver.created_at.desc()).limit(1))
    ).scalar_one()
    driver.is_verified = True
    driver.status = DriverStatus.available  # only online drivers may take rides
    # Near the test pickup (33.7215, 73.0433): accepting needs a known, nearby position.
    driver.current_lat, driver.current_lng = 33.7315, 73.0433
    await db.commit()
    return resp.json()["access_token"]
