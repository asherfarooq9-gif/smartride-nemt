"""Analytics endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_summary_returns_expected_keys(client: AsyncClient, admin_token: str):
    r = await client.get(
        "/api/v1/analytics/summary", headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert r.status_code == 200
    data = r.json()
    for key in (
        "total_rides",
        "emergency_rides_24h",
        "active_rides",
        "available_drivers",
        "total_drivers",
        "active_hospitals",
        "snapshot_at",
    ):
        assert key in data


@pytest.mark.asyncio
async def test_non_admin_cannot_access_summary(client: AsyncClient):
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": "+92300740002",
            "password": "pass1234",
            "role": "patient",
            "full_name": "P",
        },
    )
    token = r.json()["access_token"]
    r = await client.get(
        "/api/v1/analytics/summary", headers={"Authorization": f"Bearer {token}"}
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_write_snapshot_creates_record(client: AsyncClient, admin_token: str):
    r = await client.post(
        "/api/v1/analytics/snapshot?city=Islamabad",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 201
    data = r.json()
    assert data["city"] == "Islamabad"
    assert "id" in data
    assert "snapshot_hour" in data


@pytest.mark.asyncio
async def test_forecast_returns_correct_count(client: AsyncClient, admin_token: str):
    r = await client.get(
        "/api/v1/analytics/forecast?city=Islamabad&hours_ahead=6",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["city"] == "Islamabad"
    assert len(data["forecast"]) == 6
    assert data["method"] == "rolling_7day_hourly_avg"


@pytest.mark.asyncio
async def test_history_returns_snapshots(client: AsyncClient, admin_token: str):
    await client.post(
        "/api/v1/analytics/snapshot?city=Rawalpindi",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    r = await client.get(
        "/api/v1/analytics/history?city=Rawalpindi&days=1",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["city"] == "Rawalpindi"
    assert isinstance(data["snapshots"], list)
    assert len(data["snapshots"]) >= 1
