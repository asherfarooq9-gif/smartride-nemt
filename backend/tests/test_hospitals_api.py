"""Hospital route exposure rules.

`fhir_endpoint` and `coordinator_phone` are internal: the first is integration
infrastructure worth probing, the second is a staff contact number. Neither may
reach an unauthenticated caller, but the admin dashboard still needs both.
"""

import uuid
import pytest
from httpx import AsyncClient

INTERNAL_FIELDS = ("fhir_endpoint", "coordinator_phone")


async def _create_hospital(client: AsyncClient, admin_token: str) -> dict:
    body = {
        "name": f"Test General {uuid.uuid4().hex[:6]}",
        "address": "1 Test Rd",
        "city": "Islamabad",
        "lat": 33.6844,
        "lng": 73.0479,
        "phone": "+920000000001",
        "specialties": ["cardiology"],
        "ed_capacity": 20,
        "fhir_endpoint": "https://fhir.example-hospital.test/r4",
        "coordinator_phone": "+920000000000",
    }
    r = await client.post(
        "/api/v1/hospitals",
        json=body,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 201, r.text
    return r.json()


@pytest.mark.asyncio
@pytest.mark.parametrize("active_only", ["true", "false"])
async def test_public_list_omits_internal_fields(
    client: AsyncClient, admin_token: str, active_only: str
):
    await _create_hospital(client, admin_token)

    r = await client.get(f"/api/v1/hospitals?active_only={active_only}")
    assert r.status_code == 200
    items = r.json()["items"]
    assert items, "expected at least the hospital just created"
    for item in items:
        for field in INTERNAL_FIELDS:
            assert field not in item, f"{field} leaked on the public listing"
        # The public fields must still be there.
        assert item["name"]
        assert "ed_capacity" in item


@pytest.mark.asyncio
async def test_public_detail_omits_internal_fields(
    client: AsyncClient, admin_token: str
):
    created = await _create_hospital(client, admin_token)

    r = await client.get(f"/api/v1/hospitals/{created['id']}")
    assert r.status_code == 200
    body = r.json()
    for field in INTERNAL_FIELDS:
        assert field not in body, f"{field} leaked on the public detail route"
    assert body["id"] == created["id"]


@pytest.mark.asyncio
async def test_admin_list_includes_internal_fields(
    client: AsyncClient, admin_token: str
):
    created = await _create_hospital(client, admin_token)

    r = await client.get(
        "/api/v1/hospitals/admin?active_only=false",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r.status_code == 200
    match = next(h for h in r.json()["items"] if h["id"] == created["id"])
    assert match["fhir_endpoint"] == "https://fhir.example-hospital.test/r4"
    assert match["coordinator_phone"] == "+920000000000"


@pytest.mark.asyncio
async def test_admin_list_requires_authentication(client: AsyncClient):
    r = await client.get("/api/v1/hospitals/admin")
    assert r.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_list_rejects_non_admin(client: AsyncClient):
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": f"+92300{str(uuid.uuid4().int)[:7]}",
            "password": "pass1234",
            "role": "patient",
            "full_name": "T",
        },
    )
    assert reg.status_code == 201, reg.text
    token = reg.json()["access_token"]

    r = await client.get(
        "/api/v1/hospitals/admin",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 403
