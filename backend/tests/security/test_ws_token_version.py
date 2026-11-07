"""Log out everywhere must also end WebSocket sessions (audit S1)."""

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.routers import ws
from tests.conftest import TEST_DATABASE_URL
from tests.test_review_fixes import _auth, _register


@pytest.fixture
async def ws_sessions(monkeypatch):
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    monkeypatch.setattr(ws, "AsyncSessionLocal", factory)
    yield
    await engine.dispose()


async def test_logout_everywhere_rejects_the_token_at_the_socket_handshake(
    client, ws_sessions
):
    token = await _register(client, f"+92300{str(uuid.uuid4().int)[:7]}", "patient")
    assert await ws._auth_user(token) is not None

    out = await client.post("/api/v1/auth/logout-all", headers=_auth(token))

    assert out.status_code == 204, out.text
    assert await ws._auth_user(token) is None


async def test_logout_everywhere_ends_a_socket_that_is_already_open(
    client, ws_sessions
):
    token = await _register(client, f"+92300{str(uuid.uuid4().int)[:7]}", "patient")
    assert await ws._revoked(token) is False

    await client.post("/api/v1/auth/logout-all", headers=_auth(token))

    assert await ws._revoked(token) is True


async def test_a_token_that_cannot_be_decoded_counts_as_revoked(ws_sessions):
    assert await ws._revoked("not-a-jwt") is True
