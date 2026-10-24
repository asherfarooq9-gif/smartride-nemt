"""Redis failure policy (see the app.core.redis_client docstring) and lockout keying."""

import logging

import pytest
from httpx import ASGITransport, AsyncClient
from redis.exceptions import ConnectionError as RedisConnectionError

import app.core.redis_client as rc
from app.core.config import settings
from main import app
from tests.test_review_fixes import _register

PHONE = "+923001112233"


class DownRedis:
    """Every command fails like an unreachable server."""

    def __getattr__(self, name):
        async def fail(*args, **kwargs):
            raise RedisConnectionError("redis is down")

        return fail

    def register_script(self, source):
        return self.eval


class CorruptCacheRedis:
    def __init__(self):
        self.stored = {}

    async def get(self, key):
        return "{not json"

    async def setex(self, key, ttl, value):
        self.stored[key] = value


@pytest.fixture
def redis_down(monkeypatch):
    monkeypatch.setattr(rc, "_redis", DownRedis())


def _failure_count(operation: str) -> float:
    return rc.redis_failures_total.labels(operation=operation)._value.get()


async def test_blocklist_lookup_fails_open_and_is_reported(redis_down, caplog):
    before = _failure_count("is_token_blocked")
    with caplog.at_level(logging.ERROR, logger="smartride.redis"):
        assert await rc.is_token_blocked("jti-1") is False
    assert _failure_count("is_token_blocked") == before + 1
    assert any(r.levelno == logging.ERROR for r in caplog.records)


async def test_login_lockout_helpers_fail_open_with_a_warning(redis_down, caplog):
    with caplog.at_level(logging.WARNING, logger="smartride.redis"):
        assert await rc.is_login_locked(PHONE, "1.2.3.4") is False
        await rc.count_login_failure(PHONE, "1.2.3.4", 60)  # must not raise
        await rc.clear_login_failures(PHONE, "1.2.3.4")  # must not raise
    assert sum(r.levelno == logging.WARNING for r in caplog.records) == 3


async def test_block_token_reports_failure_instead_of_raising(redis_down, caplog):
    with caplog.at_level(logging.ERROR, logger="smartride.redis"):
        assert await rc.block_token("jti-2", 60) is False
    assert any("revocation" in r.getMessage() for r in caplog.records)


async def test_ping_reports_false_and_logs(redis_down, caplog):
    with caplog.at_level(logging.WARNING, logger="smartride.redis"):
        assert await rc.ping_redis() is False
    assert caplog.records and caplog.records[0].exc_info


async def test_get_cached_uses_the_loader_when_redis_is_down(redis_down):
    calls = []

    async def loader():
        calls.append(1)
        return {"ok": True}

    assert await rc.get_cached("k", 60, loader) == {"ok": True}
    assert calls == [1]


async def test_get_cached_reloads_over_corrupt_json(monkeypatch):
    fake = CorruptCacheRedis()
    monkeypatch.setattr(rc, "_redis", fake)

    async def loader():
        return [1, 2]

    assert await rc.get_cached("k", 60, loader) == [1, 2]
    assert fake.stored["k"] == "[1, 2]"


async def test_invalidate_cache_never_raises(redis_down):
    await rc.invalidate_cache("k")


async def test_client_has_socket_timeouts():
    client = await rc.get_redis()
    kwargs = client.connection_pool.connection_kwargs
    assert kwargs["socket_timeout"] == rc.REDIS_SOCKET_TIMEOUT_SECONDS
    assert kwargs["socket_connect_timeout"] == rc.REDIS_SOCKET_TIMEOUT_SECONDS


# ── lockout keying ───────────────────────────────────────────────────────────
def _client_from(ip: str) -> AsyncClient:
    return AsyncClient(
        transport=ASGITransport(app=app, client=(ip, 5000)), base_url="http://test"
    )


async def _login(c: AsyncClient, password: str, phone: str):
    return await c.post(
        "/api/v1/auth/login", json={"phone": phone, "password": password}
    )


async def test_a_stranger_cannot_lock_the_owner_out(client):
    phone = "+92300" + "5550001"
    await _register(client, phone, "patient")
    async with _client_from("203.0.113.9") as attacker:
        for _ in range(settings.LOGIN_MAX_FAILURES):
            await _login(attacker, "guess", phone)
        assert (await _login(attacker, "pass1234", phone)).status_code == 429

    async with _client_from("198.51.100.7") as owner:
        assert (await _login(owner, "pass1234", phone)).status_code == 200


async def test_many_ips_still_hit_the_per_phone_ceiling(client, monkeypatch):
    monkeypatch.setattr(settings, "LOGIN_PHONE_MAX_FAILURES", 3)
    phone = "+92300" + "5550002"
    await _register(client, phone, "patient")
    for last_octet in (1, 2, 3):
        async with _client_from(f"203.0.113.{last_octet}") as c:
            assert (await _login(c, "guess", phone)).status_code == 401

    async with _client_from("203.0.113.99") as fresh_ip:
        assert (await _login(fresh_ip, "pass1234", phone)).status_code == 429


async def test_failure_counters_always_get_an_expiry(client):
    phone = "+92300" + "5550003"
    await rc.count_login_failure(phone, "9.9.9.9", 120)
    redis = await rc.get_redis()
    keys = [k async for k in redis.scan_iter(f"login_fail:*{phone}*")]
    assert len(keys) == 2
    for key in keys:
        assert 0 < await redis.ttl(key) <= 120
    await rc.count_login_failure(phone, "9.9.9.9", 120)
    assert await redis.get(rc._pair_key(phone, "9.9.9.9")) == "2"


async def test_lockout_is_logged(client, caplog):
    phone = "+92300" + "5550004"
    for _ in range(settings.LOGIN_MAX_FAILURES):
        await rc.count_login_failure(phone, "9.9.9.9", 120)
    with caplog.at_level(logging.WARNING, logger="smartride.redis"):
        assert await rc.is_login_locked(phone, "9.9.9.9") is True
    assert any("Login locked" in r.getMessage() for r in caplog.records)
    assert phone not in caplog.text


# ── logout / refresh when revocation cannot be stored ────────────────────────
async def test_logout_says_so_when_the_token_could_not_be_revoked(client, monkeypatch):
    phone = "+92300" + "5550005"
    token = await _register(client, phone, "patient")

    async def failed(jti, ttl):
        return False

    monkeypatch.setattr("app.routers.auth.block_token", failed)
    r = await client.post(
        "/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 503


async def test_refresh_still_works_when_revocation_fails(client, monkeypatch):
    phone = "+92300" + "5550006"
    token = await _register(client, phone, "patient")

    async def failed(jti, ttl):
        return False

    monkeypatch.setattr("app.routers.auth.block_token", failed)
    r = await client.post(
        "/api/v1/auth/refresh", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 200


async def test_login_password_is_length_capped(client):
    phone = "+92300" + "5550007"
    long_pw = await _login(client, "x" * 129, phone)
    assert long_pw.status_code == 422
    plausible = await _login(client, "x" * 100, phone)
    assert plausible.status_code == 401
