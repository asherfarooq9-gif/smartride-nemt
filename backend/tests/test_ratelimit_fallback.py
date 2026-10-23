"""Losing Redis must not fail requests, but must be loud exactly once per outage."""

import logging

from fastapi import FastAPI, Request
from httpx import ASGITransport, AsyncClient
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.core import ratelimit
from app.core.ratelimit import make_limiter

DEAD_REDIS = "redis://127.0.0.1:1/0"  # nothing listens on port 1


def _app_with_dead_storage() -> FastAPI:
    limiter = make_limiter(storage_uri=DEAD_REDIS)
    probe = FastAPI()
    probe.state.limiter = limiter
    probe.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    probe.add_middleware(SlowAPIMiddleware)

    @probe.get("/ping")
    @limiter.limit("2/minute")
    async def ping(request: Request):
        return {"ok": True}

    return probe


async def test_fallback_keeps_serving_counts_once_and_still_limits(caplog):
    before = ratelimit.rate_limit_fallback_total._value.get()
    probe = _app_with_dead_storage()
    async with AsyncClient(
        transport=ASGITransport(app=probe), base_url="http://test"
    ) as c:
        with caplog.at_level(logging.ERROR, logger="smartride.ratelimit"):
            codes = [(await c.get("/ping")).status_code for _ in range(3)]

    assert codes == [200, 200, 429]  # in-memory counters still enforce the limit
    assert ratelimit.rate_limit_fallback_total._value.get() == before + 1
    errors = [r for r in caplog.records if r.levelno == logging.ERROR]
    assert len(errors) == 1
