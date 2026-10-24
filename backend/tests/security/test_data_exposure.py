"""What anonymous and ordinary users can read, and what an attacker can smuggle in."""

import csv
import io
import uuid

import pytest

from tests.test_dispatch_endpoints import _create_emergency
from tests.test_review_fixes import _auth, _register

HOSPITAL = {
    "name": "Exposure Test Hospital",
    "address": "1 Road",
    "city": "Islamabad",
    "lat": 33.7,
    "lng": 73.0,
    "coordinator_phone": "+923009990000",
    "fhir_endpoint": "https://fhir.example.org/Bundle",
}


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _create_hospital(client, admin_token, **overrides) -> dict:
    r = await client.post(
        "/api/v1/hospitals",
        json={**HOSPITAL, "name": f"H {uuid.uuid4().hex[:8]}", **overrides},
        headers=_auth(admin_token),
    )
    assert r.status_code == 201, r.text
    return r.json()


async def test_anonymous_hospital_listing_hides_internal_contacts(client, admin_token):
    hospital = await _create_hospital(client, admin_token)

    listing = await client.get("/api/v1/hospitals?page_size=200")
    single = await client.get(f"/api/v1/hospitals/{hospital['id']}")

    assert single.status_code == 200
    for body in (
        single.json(),
        next(i for i in listing.json()["items"] if i["id"] == hospital["id"]),
    ):
        assert body["coordinator_phone"] is None
        assert body["fhir_endpoint"] is None


async def test_admin_still_sees_hospital_contacts(client, admin_token):
    hospital = await _create_hospital(client, admin_token)
    r = await client.get(
        f"/api/v1/hospitals/{hospital['id']}", headers=_auth(admin_token)
    )
    assert r.json()["coordinator_phone"] == HOSPITAL["coordinator_phone"]
    assert r.json()["fhir_endpoint"] == HOSPITAL["fhir_endpoint"]


async def test_inactive_hospitals_are_hidden_from_non_admins(client, admin_token):
    hospital = await _create_hospital(client, admin_token)
    await client.patch(
        f"/api/v1/hospitals/{hospital['id']}",
        json={"is_active": False},
        headers=_auth(admin_token),
    )

    anon = await client.get("/api/v1/hospitals?active_only=false&page_size=200")
    admin = await client.get(
        "/api/v1/hospitals?active_only=false&page_size=200", headers=_auth(admin_token)
    )

    assert hospital["id"] not in {i["id"] for i in anon.json()["items"]}
    assert hospital["id"] in {i["id"] for i in admin.json()["items"]}
    assert (await client.get(f"/api/v1/hospitals/{hospital['id']}")).status_code == 404


@pytest.mark.parametrize(
    "endpoint",
    [
        "http://169.254.169.254/latest/meta-data",
        "http://localhost:8000/internal",
        "http://127.0.0.1/x",
        "http://10.0.0.5/fhir",
        "http://[::1]/fhir",
        "https://192.168.1.10/fhir",
        "http://fhir.example.org/Bundle",
        "file:///etc/passwd",
        "ftp://fhir.example.org/x",
        "javascript:alert(1)",
    ],
)
async def test_fhir_endpoint_cannot_point_at_internal_or_non_https_targets(
    client, admin_token, endpoint
):
    r = await client.post(
        "/api/v1/hospitals",
        json={
            **HOSPITAL,
            "name": f"H {uuid.uuid4().hex[:8]}",
            "fhir_endpoint": endpoint,
        },
        headers=_auth(admin_token),
    )
    assert r.status_code == 422, (endpoint, r.text)


async def test_search_treats_percent_and_underscore_literally(client, admin_token):
    await _register(client, _phone(), "patient")
    for term in ("%", "_", "%%%"):
        r = await client.get(
            "/api/v1/patients", params={"search": term}, headers=_auth(admin_token)
        )
        assert r.status_code == 200
        assert r.json()["total"] == 0, term


@pytest.mark.parametrize(
    "payload", ['=HYPERLINK("http://evil","x")', "+1+1", "-2+3", "@SUM(1)", "\t=1+1"]
)
async def test_csv_export_neutralises_spreadsheet_formulas(
    client, admin_token, payload
):
    token = await _register(client, _phone(), "patient")
    r = await client.post(
        "/api/v1/rides/emergency",
        json={
            "symptom_text": "pain",
            "pickup_lat": 33.7,
            "pickup_lng": 73.0,
            "pickup_address": payload,
        },
        headers=_auth(token),
    )
    assert r.status_code == 201, r.text

    export = await client.get("/api/v1/rides/export.csv", headers=_auth(admin_token))
    rows = list(csv.reader(io.StringIO(export.text)))
    cells = [cell for row in rows for cell in row]
    assert payload not in cells
    assert any(cell == "'" + payload for cell in cells), cells[:20]


async def test_api_errors_do_not_leak_internals(client):
    token = await _register(client, _phone(), "patient")
    for path in (
        "/api/v1/rides/not-a-uuid",
        "/api/v1/nope",
        f"/api/v1/rides/{uuid.uuid4()}",
    ):
        r = await client.get(path, headers=_auth(token))
        body = r.text.lower()
        for leak in ("traceback", "sqlalchemy", "asyncpg", 'file "', "psycopg"):
            assert leak not in body, (path, leak)


async def test_security_headers_are_set(client):
    r = await client.get("/health")
    assert r.headers.get("x-content-type-options") == "nosniff"
    assert r.headers.get("x-frame-options")


async def test_patient_list_excludes_password_hashes(client, admin_token):
    await _register(client, _phone(), "patient")
    r = await client.get("/api/v1/patients", headers=_auth(admin_token))
    assert "password" not in r.text.lower()


async def test_ride_detail_for_the_owner_never_includes_password_hashes(client):
    token = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, token)
    r = await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(token))
    assert r.status_code == 200
    assert "password" not in r.text.lower()
