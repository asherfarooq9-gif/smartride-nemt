"""Unit tests for the per-user rate-limit key function."""

from starlette.requests import Request

from app.core.ratelimit import rate_limit_key
from app.core.security import create_access_token


def _make_request(headers: dict) -> Request:
    scope = {
        "type": "http",
        "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()],
        "client": ("1.2.3.4", 1234),
    }
    return Request(scope)


def test_keys_on_user_when_valid_token_present():
    token = create_access_token({"sub": "user-abc", "role": "patient"})
    req = _make_request({"Authorization": f"Bearer {token}"})
    assert rate_limit_key(req) == "user:user-abc"


def test_falls_back_to_ip_without_token():
    req = _make_request({})
    assert rate_limit_key(req) == "ip:1.2.3.4"


def test_falls_back_to_ip_on_garbage_token():
    req = _make_request({"Authorization": "Bearer not-a-real-jwt"})
    assert rate_limit_key(req) == "ip:1.2.3.4"


def test_two_users_get_distinct_keys_from_same_ip():
    # The whole point: two users behind one NAT IP must not share a bucket.
    t1 = create_access_token({"sub": "user-1"})
    t2 = create_access_token({"sub": "user-2"})
    k1 = rate_limit_key(_make_request({"Authorization": f"Bearer {t1}"}))
    k2 = rate_limit_key(_make_request({"Authorization": f"Bearer {t2}"}))
    assert k1 != k2
    assert k1 == "user:user-1"
    assert k2 == "user:user-2"
