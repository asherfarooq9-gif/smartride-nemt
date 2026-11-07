"""Credential guessing and session-lifetime abuse."""

import time
import uuid

import jwt

from app.core.config import settings
from app.core.redis_client import get_redis
from tests.test_review_fixes import _auth, _register

PASSWORD = "pass1234"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _login(client, phone: str, password: str):
    return await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": password}
    )


async def test_repeated_wrong_passwords_lock_the_account_for_a_while(client):
    phone = _phone()
    await _register(client, phone, "patient")

    for _ in range(settings.LOGIN_MAX_FAILURES):
        assert (await _login(client, phone, "wrong-password")).status_code == 401

    # Even the correct password is refused while locked, so guessing cannot succeed.
    assert (await _login(client, phone, PASSWORD)).status_code == 429


async def test_lockout_does_not_affect_other_accounts(client):
    victim, bystander = _phone(), _phone()
    await _register(client, victim, "patient")
    await _register(client, bystander, "patient")
    for _ in range(settings.LOGIN_MAX_FAILURES):
        await _login(client, victim, "wrong-password")

    assert (await _login(client, bystander, PASSWORD)).status_code == 200


async def test_successful_login_resets_the_failure_count(client):
    phone = _phone()
    await _register(client, phone, "patient")
    for _ in range(settings.LOGIN_MAX_FAILURES - 1):
        await _login(client, phone, "wrong-password")
    assert (await _login(client, phone, PASSWORD)).status_code == 200

    assert (await _login(client, phone, "wrong-password")).status_code == 401
    assert (await _login(client, phone, PASSWORD)).status_code == 200


async def test_unknown_phones_are_throttled_the_same_way(client):
    phone = _phone()
    for _ in range(settings.LOGIN_MAX_FAILURES):
        assert (await _login(client, phone, "guess")).status_code == 401
    assert (await _login(client, phone, "guess")).status_code == 429


async def test_lock_expires_with_its_redis_key(client):
    phone = _phone()
    await _register(client, phone, "patient")
    for _ in range(settings.LOGIN_MAX_FAILURES):
        await _login(client, phone, "wrong-password")
    redis = await get_redis()
    keys = [k async for k in redis.scan_iter(f"login_fail:*{phone}*")]
    assert len(keys) == 2  # the (phone, ip) streak and the per-phone ceiling
    for key in keys:
        assert 0 < await redis.ttl(key) <= settings.LOGIN_LOCK_SECONDS


async def test_a_session_cannot_be_refreshed_forever(client):
    token = await _register(client, _phone(), "patient")
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    too_old = {
        **payload,
        "jti": str(uuid.uuid4()),
        "exp": int(time.time()) + 600,
        "auth_time": int(time.time()) - (settings.SESSION_MAX_DAYS + 1) * 86400,
    }
    stale = jwt.encode(too_old, settings.SECRET_KEY, algorithm="HS256")

    r = await client.post("/api/v1/auth/refresh", headers=_auth(stale))

    assert r.status_code == 401


async def test_refresh_keeps_the_original_login_time(client):
    token = await _register(client, _phone(), "patient")
    first = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    refreshed = (await client.post("/api/v1/auth/refresh", headers=_auth(token))).json()
    second = jwt.decode(
        refreshed["access_token"], settings.SECRET_KEY, algorithms=["HS256"]
    )
    assert second["auth_time"] == first["auth_time"]


async def test_old_token_stops_working_after_switching_role(client):
    token = await _register(client, _phone(), "patient")
    added = await client.post(
        "/api/v1/auth/add-role",
        json={
            "role": "driver",
            "license_no": f"L-{uuid.uuid4().hex[:8]}",
            "vehicle_plate": f"P-{uuid.uuid4().hex[:6]}",
            "vehicle_type": "sedan",
        },
        headers=_auth(token),
    )
    assert added.status_code == 200, added.text
    assert (
        await client.get("/api/v1/auth/me", headers=_auth(token))
    ).status_code == 401


async def _fail_from_other_addresses(phone: str, count: int) -> None:
    from app.core.redis_client import count_login_failure

    for i in range(count):
        await count_login_failure(phone, f"198.51.100.{i % 250}", 900)


async def test_owner_on_a_known_address_can_log_in_while_others_guess(client):
    """Guessing from many addresses must not lock the real owner out of their account."""
    phone = _phone()
    await _register(client, phone, "patient")
    assert (await _login(client, phone, PASSWORD)).status_code == 200  # address learned

    await _fail_from_other_addresses(phone, settings.LOGIN_PHONE_MAX_FAILURES)

    assert (await _login(client, phone, PASSWORD)).status_code == 200


async def test_an_unknown_address_is_still_locked_by_the_phone_ceiling(db):
    from app.core.redis_client import is_login_locked

    phone = _phone()
    await _fail_from_other_addresses(phone, settings.LOGIN_PHONE_MAX_FAILURES)

    assert await is_login_locked(phone, "203.0.113.77") is True


async def test_a_known_address_that_keeps_guessing_is_still_locked(db):
    from app.core.redis_client import (
        count_login_failure,
        is_login_locked,
        remember_login_ip,
    )

    phone, ip = _phone(), "203.0.113.50"
    await remember_login_ip(phone, ip)
    await _fail_from_other_addresses(phone, settings.LOGIN_PHONE_MAX_FAILURES)
    assert await is_login_locked(phone, ip) is False

    for _ in range(settings.LOGIN_MAX_FAILURES):
        await count_login_failure(phone, ip, 900)

    assert await is_login_locked(phone, ip) is True


async def test_learned_addresses_expire(db):
    from app.core.redis_client import remember_login_ip

    phone = _phone()
    await remember_login_ip(phone, "203.0.113.60")

    redis = await get_redis()
    ttl = await redis.ttl(f"login_known:{phone}")
    assert 0 < ttl <= settings.LOGIN_KNOWN_ADDRESS_SECONDS
