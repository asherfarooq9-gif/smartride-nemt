"""Throw hostile input at every endpoint: the API may refuse it, but must never crash (5xx)."""

import json
import uuid
from urllib.parse import quote

import pytest

from tests.security.test_authz_matrix import POLICY
from tests.test_review_fixes import _auth

BIG = "A" * 20_000
# One representative per failure class: empty, SQL, markup, NUL byte, unicode, template.
NASTY_STRINGS = [
    "",
    "'; DROP TABLE users; --",
    "<script>alert(1)</script>",
    "\x00null\x00byte",
    "\U0001f600" * 100,
    "{{7*7}}",
]
# Wrong types and extremes for every numeric, boolean and structured field.
NASTY_VALUES = [
    None,
    True,
    -1,
    2**63,
    1e308,
    [],
    {"a": {"a": {"a": None}}},
    *NASTY_STRINGS,
]
FIELDS = [
    "phone",
    "password",
    "full_name",
    "role",
    "roles",
    "active_role",
    "license_no",
    "vehicle_plate",
    "vehicle_type",
    "lat",
    "lng",
    "pickup_lat",
    "pickup_lng",
    "pickup_address",
    "symptom_text",
    "status",
    "cancel_reason",
    "rating",
    "comment",
    "amount_pkr",
    "payment_method",
    "plan_id",
    "scheduled_for",
    "name",
    "address",
    "city",
    "specialties",
    "ed_capacity",
    "fhir_endpoint",
    "coordinator_phone",
    "is_verified",
    "is_active",
    "fcm_token",
    "date_of_birth",
    "mobility_needs",
]

# Not worth fuzzing: /metrics, /health, /ready take no input, and logout/refresh
# would revoke the admin token the rest of the test needs.
SKIP = {"/metrics", "/health", "/ready", "/api/v1/auth/logout", "/api/v1/auth/refresh"}
ROUTES = sorted(route for route in POLICY if route[1] not in SKIP)


def _url(template: str, value: str) -> str:
    safe = quote(value[:500], safe="")  # a URL cannot carry raw control characters
    return (
        template.replace("{ride_id}", safe)
        .replace("{driver_id}", safe)
        .replace("{hospital_id}", safe)
    )


@pytest.fixture
async def admin(isolated_client, admin_token):
    return _auth(admin_token)


@pytest.mark.parametrize("method,path", ROUTES)
async def test_no_endpoint_crashes_on_hostile_bodies(
    isolated_client, admin, method, path
):
    url = _url(path, str(uuid.uuid4()))
    failures = []
    for value in NASTY_VALUES:
        # The hostile value as the whole body, and in every field a body might have.
        for body in (value, dict.fromkeys(FIELDS, value)):
            try:
                raw = json.dumps(body, allow_nan=False)
            except ValueError:
                continue
            r = await isolated_client.request(
                method,
                url,
                content=raw,
                headers={**admin, "Content-Type": "application/json"},
            )
            if r.status_code >= 500:
                failures.append((str(body)[:60], r.status_code, r.text[:120]))
    assert not failures, failures[:3]


@pytest.mark.parametrize("method,path", ROUTES)
async def test_no_endpoint_crashes_on_hostile_paths_and_queries(
    isolated_client, admin, method, path
):
    failures = []
    for value in NASTY_STRINGS:
        query = dict.fromkeys(("page", "page_size", "search", "status", "city"), value)
        r = await isolated_client.request(
            method, _url(path, value), params=query, headers=admin, json={}
        )
        if r.status_code >= 500:
            failures.append((value[:30], r.status_code, r.text[:120]))
    assert not failures, failures[:3]


@pytest.mark.parametrize(
    "raw",
    [b"", b"{", b"[1,2", b"\xff\xfe\x00", b"null", b"{" * 5000, b"9" * 5000],
)
async def test_malformed_json_is_a_client_error(isolated_client, admin, raw):
    for path in (
        "/api/v1/auth/login",
        "/api/v1/auth/register",
        "/api/v1/rides/emergency",
    ):
        r = await isolated_client.post(
            path, content=raw, headers={**admin, "Content-Type": "application/json"}
        )
        assert 400 <= r.status_code < 500, (path, r.status_code)


async def test_oversized_text_fields_are_rejected_not_stored(isolated_client, admin):
    r = await isolated_client.post(
        "/api/v1/rides/emergency",
        json={"pickup_lat": 1, "pickup_lng": 1, "symptom_text": BIG},
        headers=admin,
    )
    assert r.status_code in (403, 413, 422)
