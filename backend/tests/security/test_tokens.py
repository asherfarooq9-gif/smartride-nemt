"""Forged, stale and revoked tokens must never authenticate."""

import time
import uuid

import jwt
import pytest
from sqlalchemy import update

from app.core.config import settings
from app.core.security import create_access_token
from app.models.models import User
from tests.test_review_fixes import _auth, _register

ME = "/api/v1/auth/me"


def _payload(user_id: str, **overrides) -> dict:
    return {
        "sub": user_id,
        "jti": str(uuid.uuid4()),
        "role": "patient",
        "roles": ["patient"],
        "exp": int(time.time()) + 600,
        **overrides,
    }


def _sign(payload: dict, key: str = settings.SECRET_KEY, alg: str = "HS256") -> str:
    return jwt.encode(payload, key, algorithm=alg)


async def _patient(client):
    token = await _register(client, f"+92300{str(uuid.uuid4().int)[:7]}", "patient")
    return token, (await client.get(ME, headers=_auth(token))).json()["user_id"]


async def test_unsigned_alg_none_token_is_rejected(client):
    _, user_id = await _patient(client)
    forged = jwt.encode(_payload(user_id), key=None, algorithm="none")
    assert (await client.get(ME, headers=_auth(forged))).status_code == 401


async def test_token_signed_with_another_key_is_rejected(client):
    _, user_id = await _patient(client)
    token = _sign(_payload(user_id), key="x" * 40)
    assert (await client.get(ME, headers=_auth(token))).status_code == 401


async def test_token_signed_with_a_different_hmac_algorithm_is_rejected(client):
    _, user_id = await _patient(client)
    token = _sign(_payload(user_id), alg="HS512")
    assert (await client.get(ME, headers=_auth(token))).status_code == 401


async def test_expired_token_is_rejected(client):
    _, user_id = await _patient(client)
    token = _sign(_payload(user_id, exp=int(time.time()) - 5))
    assert (await client.get(ME, headers=_auth(token))).status_code == 401


@pytest.mark.parametrize("missing", ["sub", "jti", "exp"])
async def test_token_missing_a_required_claim_is_rejected(client, missing):
    _, user_id = await _patient(client)
    payload = _payload(user_id)
    del payload[missing]
    assert (await client.get(ME, headers=_auth(_sign(payload)))).status_code == 401


async def test_token_for_a_user_that_does_not_exist_is_rejected(client):
    token = _sign(_payload(str(uuid.uuid4())))
    assert (await client.get(ME, headers=_auth(token))).status_code == 401


@pytest.mark.parametrize("garbage", ["", "abc", "a.b.c", "Bearer", "null", "{}"])
async def test_garbage_bearer_values_are_rejected(client, garbage):
    assert (await client.get(ME, headers=_auth(garbage))).status_code == 401


async def test_a_disabled_account_loses_access_immediately(client, db):
    token, user_id = await _patient(client)
    await db.execute(update(User).where(User.id == user_id).values(is_active=False))
    await db.commit()
    assert (await client.get(ME, headers=_auth(token))).status_code in (401, 403)


async def test_logout_revokes_the_token(client):
    token, _ = await _patient(client)
    out = await client.post("/api/v1/auth/logout", headers=_auth(token))
    assert out.status_code == 204
    assert (await client.get(ME, headers=_auth(token))).status_code == 401


async def test_refresh_revokes_the_old_token(client):
    token, _ = await _patient(client)
    refreshed = await client.post("/api/v1/auth/refresh", headers=_auth(token))
    assert refreshed.status_code == 200
    assert (await client.get(ME, headers=_auth(token))).status_code == 401
    new_token = refreshed.json()["access_token"]
    assert (await client.get(ME, headers=_auth(new_token))).status_code == 200


async def test_role_claims_inside_the_token_grant_nothing(client):
    """Roles come from the database; a patient who edits the claim is still a patient."""
    _, user_id = await _patient(client)
    forged = create_access_token(
        {"sub": user_id, "role": "admin", "roles": ["admin"], "active_role": "admin"}
    )
    r = await client.get("/api/v1/patients", headers=_auth(forged))
    assert r.status_code == 403
