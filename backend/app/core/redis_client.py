import json as _json
from typing import Any, Awaitable, Callable, Optional

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


async def get_cached(key: str, ttl: int, loader: Callable[[], Awaitable[Any]]) -> Any:
    """Return cached JSON value, or call loader(), cache, and return."""
    r = await get_redis()
    raw = await r.get(key)
    if raw is not None:
        return _json.loads(raw)
    value = await loader()
    await r.setex(key, ttl, _json.dumps(value, default=str))
    return value


async def invalidate_cache(key: str) -> None:
    r = await get_redis()
    await r.delete(key)


async def reserve_idempotency_key(key: str, ttl_seconds: int) -> bool:
    """Atomically claim an idempotency key.

    True: this call claimed it — the caller should do the real work.
    False: another request already holds it — the caller should not repeat
    the work (either return the stored result, or reject as a concurrent
    duplicate if no result is stored yet).
    """
    r = await get_redis()
    claimed = await r.set(f"idempotency:{key}", "pending", nx=True, ex=ttl_seconds)
    return bool(claimed)


async def store_idempotent_result(key: str, value: str, ttl_seconds: int) -> None:
    r = await get_redis()
    await r.set(f"idempotency:{key}", value, ex=ttl_seconds)


async def get_idempotent_result(key: str) -> Optional[str]:
    """The stored result, or None if unclaimed or still pending."""
    r = await get_redis()
    value = await r.get(f"idempotency:{key}")
    if value is None or value == "pending":
        return None
    return value
