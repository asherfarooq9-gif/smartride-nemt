import asyncio
import os
import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import NullPool

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test",
)

os.environ.setdefault("DATABASE_URL", TEST_DATABASE_URL)
os.environ.setdefault("SECRET_KEY", "test-secret-key-32-chars-long!!")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("TRIAGE_SERVICE_URL", "http://localhost:8001")

from app.core.database import Base, get_db  # noqa: E402
from main import app, limiter as _main_limiter  # noqa: E402
from app.routers.auth import limiter as _auth_limiter  # noqa: E402

# Rate limits would otherwise reject the many register/login calls the suite
# makes from a single client IP. Disable them under test.
_main_limiter.enabled = False
_auth_limiter.enabled = False


async def _run_ddl() -> None:
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    asyncio.run(_run_ddl())


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
async def admin_token(db: AsyncSession) -> str:
    """Create an admin user directly in the DB (self-register is blocked via API)."""
    from app.models.models import User, UserRole, UserRoleLink
    from app.core.security import hash_password, create_access_token

    user = User(
        id=uuid.uuid4(),
        phone=f"+92-999-{uuid.uuid4().hex[:7]}",
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
