from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


class Base(DeclarativeBase):
    pass


# Under PgBouncer transaction pooling, disable asyncpg's prepared-statement
# cache (statements are session-scoped and pooling reuses sessions across
# transactions). No-op for a direct Postgres connection.
_connect_args = (
    {"statement_cache_size": 0, "prepared_statement_cache_size": 0}
    if settings.DB_DISABLE_PREPARED_CACHE
    else {}
)

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    connect_args=_connect_args,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
