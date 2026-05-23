import pytest
import os

os.environ.setdefault("DATABASE_URL", os.getenv("TEST_DATABASE_URL", "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test"))
os.environ.setdefault("SECRET_KEY", "test-secret-key-32-chars-long!!")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")


@pytest.mark.asyncio
async def test_health_returns_ok(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_ready_endpoint_exists(client):
    resp = await client.get("/ready")
    # 200 if DB+Redis available, 503 if not — either is a valid response (endpoint exists)
    assert resp.status_code in (200, 503)
    body = resp.json()
    assert "status" in body
    assert "db" in body
    assert "redis" in body
