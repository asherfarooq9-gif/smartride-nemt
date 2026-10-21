"""Bad input must be a 4xx, never a database error surfacing as a 500."""

import uuid

import pytest

from tests.test_dispatch_endpoints import _create_emergency, _register
from tests.test_review_fixes import _auth, _driver_extra


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


def _driver_payload(**overrides) -> dict:
    return {
        "phone": _phone(),
        "password": "pass1234",
        "role": "driver",
        "full_name": "T",
        **_driver_extra(),
        **overrides,
    }


@pytest.mark.parametrize(
    "field,value",
    [
        ("full_name", "x" * 101),
        ("license_no", "x" * 51),
        ("vehicle_plate", "x" * 21),
        ("vehicle_type", "x" * 51),
    ],
)
async def test_register_rejects_values_longer_than_the_column(client, field, value):
    r = await client.post(
        "/api/v1/auth/register", json=_driver_payload(**{field: value})
    )
    assert r.status_code == 422, r.text


async def test_register_duplicate_license_is_a_conflict_not_a_crash(client):
    first = _driver_payload()
    assert (await client.post("/api/v1/auth/register", json=first)).status_code == 201

    second = _driver_payload(license_no=first["license_no"])
    r = await client.post("/api/v1/auth/register", json=second)

    assert r.status_code == 409, r.text


async def test_register_failure_does_not_leave_a_half_created_user(client):
    first = _driver_payload()
    await client.post("/api/v1/auth/register", json=first)
    second = _driver_payload(vehicle_plate=first["vehicle_plate"])
    await client.post("/api/v1/auth/register", json=second)

    # The second phone must still be free to register with valid details.
    retry = _driver_payload(phone=second["phone"])
    assert (await client.post("/api/v1/auth/register", json=retry)).status_code == 201


@pytest.mark.parametrize("path", ["patients/me", "drivers/me"])
async def test_profile_patch_rejects_null_name(client, path):
    role = "patient" if path.startswith("patients") else "driver"
    extra = _driver_extra() if role == "driver" else {}
    token = await _register(client, _phone(), role, **extra)
    r = await client.patch(
        f"/api/v1/{path}", json={"full_name": None}, headers=_auth(token)
    )
    assert r.status_code == 422, r.text


@pytest.mark.parametrize(
    "body",
    [
        {"lat": 91, "lng": 73},
        {"lat": 33, "lng": 181},
        {"lat": 1e308 * 10, "lng": 73},
    ],
)
async def test_driver_location_rejects_out_of_range_coordinates(
    client, verified_driver_token, body
):
    import json

    r = await client.post(
        "/api/v1/drivers/location",
        content=json.dumps(body),
        headers={**_auth(verified_driver_token), "Content-Type": "application/json"},
    )
    assert r.status_code == 422, r.text


async def test_ride_lookup_with_malformed_id_is_422(client):
    token = await _register(client, _phone(), "patient")
    for path in ("rides/not-a-uuid", "rides/not-a-uuid/detail"):
        r = await client.get(f"/api/v1/{path}", headers=_auth(token))
        assert r.status_code == 422, (path, r.text)


async def test_hospital_lookup_with_malformed_id_is_422(client):
    r = await client.get("/api/v1/hospitals/not-a-uuid")
    assert r.status_code == 422


async def test_hospital_create_rejects_impossible_values(client, admin_token):
    base = {"name": "H", "address": "A", "city": "C", "lat": 33.7, "lng": 73.0}
    for bad in ({"lat": 200}, {"lng": -999}, {"ed_capacity": -5}, {"name": "x" * 201}):
        r = await client.post(
            "/api/v1/hospitals", json={**base, **bad}, headers=_auth(admin_token)
        )
        assert r.status_code == 422, (bad, r.text)


async def test_valid_ride_flow_still_works_with_uuid_path_params(
    client, verified_driver_token
):
    patient = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient)
    assert (
        await client.get(f"/api/v1/rides/{ride_id}", headers=_auth(patient))
    ).status_code == 200
    assert (
        await client.post(
            f"/api/v1/rides/{ride_id}/accept", headers=_auth(verified_driver_token)
        )
    ).status_code == 200


async def test_ride_requests_require_coordinates(client):
    """Contract the mobile client depends on: no coordinates, no ride (422)."""
    token = await _register(client, _phone(), "patient")
    r = await client.post(
        "/api/v1/rides/emergency",
        json={"symptom_text": "chest pain", "pickup_address": "Current location"},
        headers=_auth(token),
    )
    assert r.status_code == 422
    assert r.json()["detail"] == "Field required"
