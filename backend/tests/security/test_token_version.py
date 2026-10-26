"""Per-user token invalidation: log out everywhere, and refresh that fails closed."""

import uuid
from unittest.mock import AsyncMock, patch

from sqlalchemy import select, update

from app.models.models import User
from tests.security.test_tokens import ME, _payload, _sign
from tests.test_review_fixes import _auth, _register

PASSWORD = "pass1234"


async def _login(client, phone: str) -> str:
    r = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": PASSWORD}
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


async def _two_sessions(client):
    phone = f"+92300{str(uuid.uuid4().int)[:7]}"
    first = await _register(client, phone, "patient")
    second = await _login(client, phone)
    return phone, first, second


async def test_logout_everywhere_kills_every_session(client):
    phone, first, second = await _two_sessions(client)
    assert (await client.get(ME, headers=_auth(first))).status_code == 200
    assert (await client.get(ME, headers=_auth(second))).status_code == 200

    out = await client.post("/api/v1/auth/logout-all", headers=_auth(first))

    assert out.status_code == 204, out.text
    assert (await client.get(ME, headers=_auth(first))).status_code == 401
    assert (await client.get(ME, headers=_auth(second))).status_code == 401
    fresh = await _login(client, phone)
    assert (await client.get(ME, headers=_auth(fresh))).status_code == 200


async def test_logout_everywhere_needs_a_valid_token(client):
    out = await client.post("/api/v1/auth/logout-all")

    assert out.status_code == 401


async def test_a_token_from_before_the_version_changed_is_rejected(client, db):
    _, token, _ = await _two_sessions(client)
    user_id = (await client.get(ME, headers=_auth(token))).json()["user_id"]

    await db.execute(
        update(User)
        .where(User.id == user_id)
        .values(token_version=User.token_version + 1)
    )
    await db.commit()

    assert (await client.get(ME, headers=_auth(token))).status_code == 401


async def test_tokens_issued_before_the_column_existed_still_work(client):
    """Tokens in flight at deploy time carry no version; they match version 0."""
    phone = f"+92300{str(uuid.uuid4().int)[:7]}"
    token = await _register(client, phone, "patient")
    user_id = (await client.get(ME, headers=_auth(token))).json()["user_id"]

    legacy = _sign(_payload(user_id))  # no "tv" claim

    assert (await client.get(ME, headers=_auth(legacy))).status_code == 200


async def test_refresh_fails_when_the_old_token_cannot_be_revoked(client):
    token = await _register(client, f"+92300{str(uuid.uuid4().int)[:7]}", "patient")

    with patch("app.routers.auth.block_token", new=AsyncMock(return_value=False)):
        r = await client.post("/api/v1/auth/refresh", headers=_auth(token))

    assert r.status_code == 503, r.text
    # Nothing was handed out, so the original token is still the only one.
    assert (await client.get(ME, headers=_auth(token))).status_code == 200


async def test_a_refreshed_token_carries_the_current_version(client, db):
    phone, token, _ = await _two_sessions(client)
    await client.post("/api/v1/auth/logout-all", headers=_auth(token))
    fresh = await _login(client, phone)

    r = await client.post("/api/v1/auth/refresh", headers=_auth(fresh))

    assert r.status_code == 200, r.text
    renewed = r.json()["access_token"]
    assert (await client.get(ME, headers=_auth(renewed))).status_code == 200
    version = (
        await db.execute(select(User.token_version).where(User.phone == phone))
    ).scalar_one()
    assert version >= 1
