"""Rate-limit counters must live in Redis so they hold across workers and restarts."""

import redis.asyncio as aioredis

from app.core.config import settings
from app.routers.auth import limiter as auth_limiter

LOGIN_LIMIT = 10  # @limiter.limit("10/minute") on POST /auth/login


async def _flush_limiter_keys(client) -> None:
    keys = await client.keys("LIMITS:*")
    if keys:
        await client.delete(*keys)


async def test_login_rate_limit_returns_429_and_is_stored_in_redis(client):
    redis_client = aioredis.from_url(settings.REDIS_URL)
    await _flush_limiter_keys(redis_client)
    auth_limiter.enabled = True
    try:
        statuses = []
        for n in range(LOGIN_LIMIT + 1):
            # A different phone each time: the per-IP limiter is under test, not the
            # per-account lockout.
            resp = await client.post(
                "/api/v1/auth/login",
                json={"phone": f"+9230099{n:05d}", "password": "x"},
            )
            statuses.append(resp.status_code)

        assert statuses[:LOGIN_LIMIT] == [401] * LOGIN_LIMIT
        assert statuses[-1] == 429
        assert await redis_client.keys("LIMITS:*"), "counters were not stored in Redis"
    finally:
        auth_limiter.enabled = False
        await _flush_limiter_keys(redis_client)
        await redis_client.aclose()
