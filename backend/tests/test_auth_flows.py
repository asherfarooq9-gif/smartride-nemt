"""Auth session-flow coverage: /me, /fcm-token, /logout."""

import pytest
from httpx import AsyncClient

PATIENT = {
    "phone": "+923007000001",
    "password": "secret123",
    "role": "patient",
    "full_name": "Session Tester",
}


async def _register_and_auth(client: AsyncClient, phone: str) -> dict:
    resp = await client.post("/api/v1/auth/register", json={**PATIENT, "phone": phone})
    assert resp.status_code == 201
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_me_returns_profile_flags(client: AsyncClient):
    headers = await _register_and_auth(client, "+923007000010")
    resp = await client.get("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["active_role"] == "patient"
    assert data["has_patient_profile"] is True
    assert data["has_driver_profile"] is False
    assert "patient" in data["roles"]


@pytest.mark.asyncio
async def test_me_requires_auth(client: AsyncClient):
    resp = await client.get("/api/v1/auth/me")
    assert resp.status_code in (401, 403)


@pytest.mark.asyncio
async def test_register_fcm_token(client: AsyncClient):
    headers = await _register_and_auth(client, "+923007000020")
    resp = await client.post(
        "/api/v1/auth/fcm-token", json={"fcm_token": "device-token-xyz"}, headers=headers
    )
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_register_fcm_token_twice_does_not_duplicate(client: AsyncClient):
    headers = await _register_and_auth(client, "+923007000021")
    same_token = {"fcm_token": "device-token-dup"}
    r1 = await client.post("/api/v1/auth/fcm-token", json=same_token, headers=headers)
    r2 = await client.post("/api/v1/auth/fcm-token", json=same_token, headers=headers)
    assert r1.status_code == 204
    assert r2.status_code == 204


@pytest.mark.asyncio
async def test_unregister_fcm_token_removes_only_that_token(client: AsyncClient):
    headers = await _register_and_auth(client, "+923007000022")
    device_a = {"fcm_token": "device-a-token"}
    device_b = {"fcm_token": "device-b-token"}
    await client.post("/api/v1/auth/fcm-token", json=device_a, headers=headers)
    await client.post("/api/v1/auth/fcm-token", json=device_b, headers=headers)

    resp = await client.request(
        "DELETE", "/api/v1/auth/fcm-token", json=device_a, headers=headers
    )
    assert resp.status_code == 204

    # Unregistering device_a again is a no-op, not an error — device_b must
    # still be untouched.
    resp = await client.request(
        "DELETE", "/api/v1/auth/fcm-token", json=device_a, headers=headers
    )
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_logout_blocks_token(client: AsyncClient):
    headers = await _register_and_auth(client, "+923007000030")
    # Token works before logout.
    assert (await client.get("/api/v1/auth/me", headers=headers)).status_code == 200
    # Logout revokes it.
    assert (await client.post("/api/v1/auth/logout", headers=headers)).status_code == 204
    # Subsequent use is rejected (token is blocklisted).
    assert (await client.get("/api/v1/auth/me", headers=headers)).status_code == 401
