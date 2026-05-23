import redis.asyncio as aioredis
from app.core.config import settings

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis


async def block_token(jti: str, ttl_seconds: int) -> None:
    r = await get_redis()
    await r.setex(f"blocklist:{jti}", ttl_seconds, "1")


async def is_token_blocked(jti: str) -> bool:
    r = await get_redis()
    return bool(await r.exists(f"blocklist:{jti}"))


async def ping_redis() -> bool:
    try:
        r = await get_redis()
        return await r.ping()
    except Exception:
        return False
