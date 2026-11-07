"""Redis helpers and the failure policy for every Redis-backed feature.

Availability matters more than strictness here: an emergency patient must still
be able to sign in and book while Redis is down. So every helper has a bounded
socket timeout and an explicit, logged fallback; none of them hangs a request:

- is_token_blocked: fails OPEN (token treated as not revoked), ERROR log plus the
  smartride_redis_failures_total counter. A revoked token can work until it
  expires (JWT_EXPIRE_MINUTES) during an outage.
- login lockout helpers: fail open (no lockout is enforced or recorded),
  WARNING log plus the counter.
- block_token: returns False and logs when the revocation could not be stored,
  so the caller decides (logout reports failure, token refresh carries on).
- get_cached: falls back to the loader on a Redis read/write error and on
  corrupt cached JSON (the bad entry is overwritten).
- invalidate_cache: never raises; a stale entry is bounded by its TTL.
- Rate limiting (ratelimit.py) falls back to per-process memory and counts it.
"""

import json as _json
import logging
from asyncio import TimeoutError as AsyncTimeoutError
from typing import Any, Awaitable, Callable

import redis.asyncio as aioredis
from prometheus_client import Counter
from redis.exceptions import RedisError

from app.core.config import settings

log = logging.getLogger("smartride.redis")

REDIS_SOCKET_TIMEOUT_SECONDS = 2.0

_REDIS_ERRORS = (RedisError, OSError, AsyncTimeoutError)

redis_failures_total = Counter(
    "smartride_redis_failures_total",
    "Redis operations that failed and used their fallback, labelled by operation.",
    ["operation"],
)

_redis: aioredis.Redis | None = None


def _record_failure(operation: str) -> None:
    redis_failures_total.labels(operation=operation).inc()


async def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_timeout=REDIS_SOCKET_TIMEOUT_SECONDS,
            socket_connect_timeout=REDIS_SOCKET_TIMEOUT_SECONDS,
        )
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None


async def block_token(jti: str, ttl_seconds: int) -> bool:
    """Revoke a token id. Returns False (and logs) if Redis could not store it."""
    try:
        r = await get_redis()
        await r.setex(f"blocklist:{jti}", ttl_seconds, "1")
    except _REDIS_ERRORS:
        _record_failure("block_token")
        log.error("Token revocation not stored (redis error)", exc_info=True)
        return False
    return True


async def is_token_blocked(jti: str) -> bool:
    try:
        r = await get_redis()
        return bool(await r.exists(f"blocklist:{jti}"))
    except _REDIS_ERRORS:
        _record_failure("is_token_blocked")
        log.error("Blocklist lookup failed; treating token as valid", exc_info=True)
        return False


# ── login lockout ────────────────────────────────────────────────────────────
# Two counters per failed login. The (phone, ip) one locks a guesser out without
# letting a stranger lock the real owner, who comes from a different IP. The
# per-phone one is a higher ceiling so guessing from many IPs is still bounded.

# INCR and EXPIRE in one step: a crash between them can never leave a key that
# never expires. The TTL check also repairs a counter that lost its expiry.
_COUNT_FAILURE_LUA = """
for i = 1, #KEYS do
  redis.call('INCR', KEYS[i])
  if redis.call('TTL', KEYS[i]) < 0 then
    redis.call('EXPIRE', KEYS[i], ARGV[1])
  end
end
return 1
"""


def _pair_key(phone: str, client_ip: str) -> str:
    return f"login_fail:pair:{phone}|{client_ip}"


def _phone_key(phone: str) -> str:
    return f"login_fail:phone:{phone}"


def _known_key(phone: str) -> str:
    return f"login_known:{phone}"


async def is_login_locked(phone: str, client_ip: str) -> bool:
    try:
        r = await get_redis()
        pair, total = await r.mget(_pair_key(phone, client_ip), _phone_key(phone))
        known = int(
            total or 0
        ) >= settings.LOGIN_PHONE_MAX_FAILURES and await r.sismember(
            _known_key(phone), client_ip
        )
    except _REDIS_ERRORS:
        _record_failure("login_lock_check")
        log.warning("Login lockout check failed; not enforcing", exc_info=True)
        return False
    if int(pair or 0) >= settings.LOGIN_MAX_FAILURES:
        log.warning("Login locked: too many failures from ip=%s", client_ip)
        return True
    if int(total or 0) >= settings.LOGIN_PHONE_MAX_FAILURES and not known:
        log.warning(
            "Login locked: too many failures for one phone across IPs (latest ip=%s)",
            client_ip,
        )
        return True
    return False


async def remember_login_ip(phone: str, client_ip: str) -> None:
    """Note that this address has logged in to the account.

    The per-phone ceiling stops guessing spread over many addresses, but it must
    not lock the owner out of their own account, so it skips addresses seen here.
    The per-(phone, address) streak still applies to them.
    """
    try:
        r = await get_redis()
        key = _known_key(phone)
        await r.sadd(key, client_ip)
        await r.expire(key, settings.LOGIN_KNOWN_ADDRESS_SECONDS)
    except _REDIS_ERRORS:
        _record_failure("remember_login_ip")
        log.warning("Login address not remembered (redis error)", exc_info=True)


async def count_login_failure(phone: str, client_ip: str, lock_seconds: int) -> None:
    try:
        r = await get_redis()
        script = r.register_script(_COUNT_FAILURE_LUA)
        await script(
            keys=[_pair_key(phone, client_ip), _phone_key(phone)], args=[lock_seconds]
        )
    except _REDIS_ERRORS:
        _record_failure("count_login_failure")
        log.warning("Login failure not recorded (redis error)", exc_info=True)


async def clear_login_failures(phone: str, client_ip: str) -> None:
    """A correct password resets this IP's streak; the per-phone ceiling decays by TTL."""
    try:
        r = await get_redis()
        await r.delete(_pair_key(phone, client_ip))
    except _REDIS_ERRORS:
        _record_failure("clear_login_failures")
        log.warning("Login failures not cleared (redis error)", exc_info=True)


async def ping_redis() -> bool:
    try:
        r = await get_redis()
        return bool(await r.ping())
    except _REDIS_ERRORS:
        log.warning("Redis ping failed", exc_info=True)
        return False


# ── cache ────────────────────────────────────────────────────────────────────
async def get_cached(key: str, ttl: int, loader: Callable[[], Awaitable[Any]]) -> Any:
    """Return cached JSON value, or call loader(), cache, and return.

    Redis being down or the entry being corrupt only costs a cache miss.
    """
    try:
        r = await get_redis()
        raw = await r.get(key)
    except _REDIS_ERRORS:
        _record_failure("cache_read")
        log.warning("Cache read failed for %s; using loader", key, exc_info=True)
        return await loader()
    if raw is not None:
        try:
            return _json.loads(raw)
        except ValueError:
            _record_failure("cache_corrupt")
            log.warning("Corrupt cache entry for %s; reloading", key)
    value = await loader()
    try:
        await r.setex(key, ttl, _json.dumps(value, default=str))
    except (*_REDIS_ERRORS, TypeError, ValueError):
        _record_failure("cache_write")
        log.warning("Cache write failed for %s", key, exc_info=True)
    return value


async def invalidate_cache(key: str) -> None:
    """Never raises: if Redis is down the entry simply expires by its TTL."""
    try:
        r = await get_redis()
        await r.delete(key)
    except _REDIS_ERRORS:
        _record_failure("cache_invalidate")
        log.error(
            "Cache invalidation failed for %s; entry lives until TTL",
            key,
            exc_info=True,
        )
