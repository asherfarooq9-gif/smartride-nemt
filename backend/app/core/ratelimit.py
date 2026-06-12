"""Rate-limit keying.

Default slowapi keys on client IP. On mobile networks many users sit behind one
carrier-grade NAT IP, so an IP bucket throttles unrelated people. Instead, key on
the authenticated user when a valid bearer token is present, and fall back to IP
for unauthenticated traffic (login/register) — where per-IP is actually what you
want for credential-stuffing protection.
"""

from jose import JWTError, jwt
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings


def rate_limit_key(request: Request) -> str:
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        token = auth[7:]
        try:
            payload = jwt.decode(
                token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
            )
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except JWTError:
            # Bad/expired token — fall through to IP keying.
            pass
    return f"ip:{get_remote_address(request)}"
