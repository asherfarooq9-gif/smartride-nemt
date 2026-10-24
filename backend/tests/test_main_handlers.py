"""Error envelope, headers on every error response, and graceful shutdown."""

import asyncio
import logging

from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient
from sqlalchemy.exc import OperationalError

import main
from main import _stop_task, app
from app.core.config import settings

# Throwaway app wearing main.py's handlers, so the real app's route table (which
# the authz-matrix test audits) stays untouched.
probe = FastAPI()
for _exc, _handler in app.exception_handlers.items():
    probe.add_exception_handler(_exc, _handler)


@probe.get("/__test/boom")
async def _boom_route():
    raise RuntimeError("secret internal detail")


@probe.get("/__test/retry")
async def _retry_route():
    raise HTTPException(
        status_code=429, detail="slow down", headers={"Retry-After": "7"}
    )


def _client_not_raising(target=app, **headers) -> AsyncClient:
    return AsyncClient(
        transport=ASGITransport(app=target, raise_app_exceptions=False),
        base_url="http://test",
        headers=headers,
    )


async def test_unknown_route_uses_the_error_envelope():
    async with _client_not_raising() as c:
        r = await c.get("/api/v1/nope")
    assert r.status_code == 404
    body = r.json()
    assert body["detail"] == "Not Found"
    assert body["code"] == "error"


async def test_wrong_method_keeps_the_envelope_and_allow_header():
    async with _client_not_raising() as c:
        r = await c.delete("/health")
    assert r.status_code == 405
    assert r.json()["code"] == "error"
    assert "GET" in r.headers["allow"]


async def test_http_exception_headers_are_preserved(client):
    r = await client.get("/api/v1/auth/me")
    assert r.status_code == 401
    assert r.headers["www-authenticate"] == "Bearer"

    async with _client_not_raising(probe) as c:
        r = await c.get("/__test/retry")
    assert r.status_code == 429
    assert r.headers["retry-after"] == "7"
    assert r.json()["detail"] == "slow down"


async def test_validation_error_lists_every_field_and_keeps_old_keys(client):
    r = await client.post("/api/v1/auth/login", json={"phone": 5})
    assert r.status_code == 422
    body = r.json()
    assert body["code"] == "validation_error"
    assert isinstance(body["detail"], str) and body["detail"]
    locs = {tuple(err["loc"]) for err in body["errors"]}
    assert ("body", "phone") in locs
    assert ("body", "password") in locs
    assert all({"loc", "msg", "type"} <= set(err) for err in body["errors"])


async def test_server_error_carries_security_and_cors_headers():
    origin = settings.ALLOWED_ORIGINS[0]
    async with _client_not_raising(probe, Origin=origin) as c:
        r = await c.get("/__test/boom")
    assert r.status_code == 500
    assert r.json()["code"] == "internal_error"
    assert "secret internal detail" not in r.text
    assert r.headers["x-content-type-options"] == "nosniff"
    assert r.headers["x-frame-options"] == "DENY"
    assert "strict-transport-security" in r.headers
    assert r.headers["access-control-allow-origin"] == origin


async def test_server_error_does_not_grant_cors_to_unknown_origins():
    async with _client_not_raising(probe, Origin="https://evil.example") as c:
        r = await c.get("/__test/boom")
    assert r.status_code == 500
    assert "access-control-allow-origin" not in r.headers


# ── shutdown ─────────────────────────────────────────────────────────────────
async def test_stop_task_waits_for_cleanup_of_the_cancelled_task():
    cleaned = asyncio.Event()

    async def loop_forever():
        try:
            await asyncio.sleep(3600)
        finally:
            await asyncio.sleep(0.01)  # cleanup that takes a moment
            cleaned.set()

    task = asyncio.create_task(loop_forever())
    await asyncio.sleep(0)
    await _stop_task(task, "test task")
    assert cleaned.is_set()
    assert task.done()


async def test_stop_task_logs_a_task_that_crashed(caplog):
    async def crashes():
        raise ValueError("kaput")

    task = asyncio.create_task(crashes())
    await asyncio.sleep(0)
    with caplog.at_level(logging.ERROR, logger="smartride"):
        await _stop_task(task, "test task")
    assert any("crashed" in r.getMessage() for r in caplog.records)


# ── readiness ────────────────────────────────────────────────────────────────
async def test_ready_logs_why_it_is_degraded(monkeypatch, caplog):
    class BrokenEngine:
        def connect(self):
            raise OperationalError("SELECT 1", {}, Exception("db down"))

    async def redis_down():
        return False

    monkeypatch.setattr(main, "engine", BrokenEngine())
    monkeypatch.setattr(main, "ping_redis", redis_down)
    with caplog.at_level(logging.WARNING, logger="smartride"):
        async with _client_not_raising() as c:
            r = await c.get("/ready")
    assert r.status_code == 503
    assert r.json()["db"] is False
    assert any(
        "database check failed" in rec.getMessage() and rec.exc_info
        for rec in caplog.records
    )
