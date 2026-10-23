"""Rate-limit keying.

Default slowapi keys on client IP. On mobile networks many users sit behind one
carrier-grade NAT IP, so an IP bucket throttles unrelated people. Instead, key on
the authenticated user when a valid bearer token is present, and fall back to IP
for unauthenticated traffic (login/register) — where per-IP is actually what you
want for credential-stuffing protection.
"""

import jwt
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings
from app.core.security import decode_token


def make_limiter(**kwargs) -> Limiter:
    """Limiter whose counters live in Redis, shared by every worker and instance.

    The in-memory default gives each process its own bucket, so N workers allow
    N times the limit and a restart resets it. If Redis is unreachable slowapi
    falls back to per-process memory instead of failing requests.
    """
    return Limiter(
        key_func=rate_limit_key,
        storage_uri=settings.REDIS_URL,
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
