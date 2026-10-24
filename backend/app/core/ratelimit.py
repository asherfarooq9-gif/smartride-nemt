"""Rate-limit keying.

Default slowapi keys on client IP. On mobile networks many users sit behind one
carrier-grade NAT IP, so an IP bucket throttles unrelated people. Instead, key on
the authenticated user when a valid bearer token is present, and fall back to IP
for unauthenticated traffic (login/register) — where per-IP is actually what you
want for credential-stuffing protection.
"""

import logging

import jwt
from prometheus_client import Counter
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings
from app.core.security import decode_token

log = logging.getLogger("smartride.ratelimit")

RATE_LIMIT_STORAGE_TIMEOUT_SECONDS = 2.0

rate_limit_fallback_total = Counter(
    "smartride_rate_limit_fallback_total",
    "Times the rate limiter lost Redis and fell back to per-process memory.",
)


class _ObservedLimiter(Limiter):
    """Limiter that reports, once per outage, when it drops to in-memory counters.

    While degraded each worker counts separately (N workers allow N times the
    limit); that is the accepted trade for keeping requests flowing.
    """

    def _check_request_limit(self, request, endpoint_func, in_middleware=True):
        was_degraded = bool(getattr(self, "_storage_dead", False))
        try:
            super()._check_request_limit(request, endpoint_func, in_middleware)
        finally:
            is_degraded = bool(getattr(self, "_storage_dead", False))
            if is_degraded and not was_degraded:
                rate_limit_fallback_total.inc()
                log.error(
                    "Rate-limit Redis unreachable: using per-process in-memory counters"
                )
            elif was_degraded and not is_degraded:
                log.info("Rate-limit Redis recovered: back to shared counters")


def make_limiter(storage_uri: str | None = None, **kwargs) -> Limiter:
    """Limiter whose counters live in Redis, shared by every worker and instance.

    The in-memory default gives each process its own bucket, so N workers allow
    N times the limit and a restart resets it. If Redis is unreachable slowapi
    falls back to per-process memory instead of failing requests (logged and
    counted by _ObservedLimiter).
    """
    return _ObservedLimiter(
        key_func=rate_limit_key,
        storage_uri=storage_uri or settings.REDIS_URL,
        storage_options={
            "socket_timeout": RATE_LIMIT_STORAGE_TIMEOUT_SECONDS,
            "socket_connect_timeout": RATE_LIMIT_STORAGE_TIMEOUT_SECONDS,
        },
        in_memory_fallback_enabled=True,
        enabled=settings.RATE_LIMITS_ENABLED,
        **kwargs,
    )


def rate_limit_key(request: Request) -> str:
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
        try:
            payload = decode_token(token)
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except jwt.PyJWTError:
            # Bad/expired token — fall through to IP keying.
            pass
    return f"ip:{get_remote_address(request)}"
