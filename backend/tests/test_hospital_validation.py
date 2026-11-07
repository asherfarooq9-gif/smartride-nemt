"""A hospital at (0, 0) or with no emergency capacity must not be savable by accident."""

import pytest
from httpx import AsyncClient

from tests.test_review_fixes import _auth

VALID = {
    "name": "Validation Hospital",
    "address": "1 Test Road",
    "city": "Islamabad",
    "lat": 33.6844,
    "lng": 73.0479,
    "specialties": ["cardiology"],
    "ed_capacity": 50,
}


async def _create(client, admin_token, **overrides):
    return await client.post(
        "/api/v1/hospitals", json={**VALID, **overrides}, headers=_auth(admin_token)
    )


async def test_a_hospital_at_null_island_is_rejected(client: AsyncClient, admin_token):
    """(0, 0) is what a cleared coordinate field turns into, and it is in the sea."""
    r = await _create(client, admin_token, lat=0, lng=0)

    assert r.status_code == 422, r.text
    assert "coordinates" in r.text.lower()


@pytest.mark.parametrize("lat,lng", [(0, 73.0479), (33.6844, 0)])
async def test_a_real_place_on_one_axis_line_is_still_allowed(
    client: AsyncClient, admin_token, lat, lng
):
    r = await _create(client, admin_token, lat=lat, lng=lng)

    assert r.status_code == 201, r.text


async def test_a_hospital_with_no_emergency_capacity_is_rejected(
    client: AsyncClient, admin_token
):
    r = await _create(client, admin_token, ed_capacity=0)

    assert r.status_code == 422, r.text


@pytest.mark.parametrize("blank", ["name", "address", "city"])
async def test_blank_required_text_is_rejected(client: AsyncClient, admin_token, blank):
    r = await _create(client, admin_token, **{blank: "   "})

    assert r.status_code == 422, r.text


async def test_updating_to_null_island_or_zero_capacity_is_rejected(
    client: AsyncClient, admin_token
):
    created = (await _create(client, admin_token)).json()
    url = f"/api/v1/hospitals/{created['id']}"

    both_zero = await client.patch(
        url, json={"lat": 0, "lng": 0}, headers=_auth(admin_token)
    )
    no_capacity = await client.patch(
        url, json={"ed_capacity": 0}, headers=_auth(admin_token)
    )
    blank_name = await client.patch(url, json={"name": ""}, headers=_auth(admin_token))

    assert both_zero.status_code == 422, both_zero.text
    assert no_capacity.status_code == 422, no_capacity.text
    assert blank_name.status_code == 422, blank_name.text


async def test_a_normal_update_still_works(client: AsyncClient, admin_token):
    created = (await _create(client, admin_token)).json()

    r = await client.patch(
        f"/api/v1/hospitals/{created['id']}",
        json={"ed_capacity": 80, "ed_current_load": 10, "name": "Renamed"},
        headers=_auth(admin_token),
    )

    assert r.status_code == 200, r.text
    assert r.json()["ed_capacity"] == 80
