"""Every route x every kind of caller. A new route without an entry here fails the suite."""

import uuid

import pytest
from fastapi.routing import APIRoute

from app.core.config import settings
from app.core.security import create_access_token
from main import app
from tests.test_review_fixes import _register

N, P, D, A = "anonymous", "patient", "driver", "admin"
ANY = {P, D, A}
EVERYONE = {N, P, D, A}

# (method, route template) -> who may call it. Everyone else must get 401 (not
# signed in) or 403 (signed in, wrong role).
POLICY = {
    ("GET", "/health"): EVERYONE,
    ("GET", "/ready"): EVERYONE,
    # Only the scraper token (see test_metrics_needs_the_scraper_token), no user role.
    ("GET", "/metrics"): set(),
    ("POST", "/api/v1/auth/register"): EVERYONE,
    ("POST", "/api/v1/auth/login"): EVERYONE,
    ("GET", "/api/v1/hospitals"): EVERYONE,
    ("GET", "/api/v1/hospitals/{hospital_id}"): EVERYONE,
    ("POST", "/api/v1/hospitals"): {A},
    ("PATCH", "/api/v1/hospitals/{hospital_id}"): {A},
    ("POST", "/api/v1/auth/add-role"): ANY,
    ("POST", "/api/v1/auth/switch-role"): ANY,
    ("GET", "/api/v1/auth/me"): ANY,
    ("POST", "/api/v1/auth/fcm-token"): ANY,
    ("POST", "/api/v1/auth/logout"): ANY,
    ("POST", "/api/v1/auth/refresh"): ANY,
    ("GET", "/api/v1/rides/mine"): {P, D},
    ("GET", "/api/v1/rides/{ride_id}"): ANY,
    ("GET", "/api/v1/rides/{ride_id}/detail"): ANY,
    ("PATCH", "/api/v1/rides/{ride_id}/status"): ANY,
    ("GET", "/api/v1/patients/me"): {P},
    ("PATCH", "/api/v1/patients/me"): {P},
    ("POST", "/api/v1/rides/emergency"): {P},
    ("POST", "/api/v1/rides/scheduled"): {P},
    ("POST", "/api/v1/rides/{ride_id}/rate"): {P},
    ("GET", "/api/v1/drivers/me"): {D},
    ("PATCH", "/api/v1/drivers/me"): {D},
    ("PATCH", "/api/v1/drivers/status"): {D},
    ("POST", "/api/v1/drivers/location"): {D},
    ("GET", "/api/v1/drivers/earnings"): {D},
    ("GET", "/api/v1/drivers/wallet"): {D},
    ("GET", "/api/v1/rides/pending"): {D},
    ("POST", "/api/v1/rides/{ride_id}/accept"): {D},
    ("GET", "/api/v1/patients"): {A},
    ("GET", "/api/v1/drivers"): {A},
    ("PATCH", "/api/v1/drivers/{driver_id}/verify"): {A},
    ("POST", "/api/v1/drivers/{driver_id}/wallet/topup"): {A},
    ("GET", "/api/v1/rides"): {A},
    ("GET", "/api/v1/rides/export.csv"): {A},
    ("GET", "/api/v1/analytics/summary"): {A},
    ("GET", "/api/v1/analytics/forecast"): {A},
    ("GET", "/api/v1/analytics/history"): {A},
    ("POST", "/api/v1/analytics/snapshot"): {A},
}

ROUTES = sorted(
    (m, r.path)
    for r in app.routes
    if isinstance(r, APIRoute) and r.path not in {"/docs", "/redoc", "/openapi.json"}
    for m in r.methods - {"HEAD", "OPTIONS"}
)


@pytest.fixture(autouse=True)
def _production_mode(monkeypatch):
    monkeypatch.setattr(settings, "DEBUG", False)


@pytest.fixture
async def callers(client, admin_token, verified_driver_token):
    """One account per role; a fresh token per request so /logout cannot poison later calls."""
    patient_token = await _register(
        client, f"+92300{str(uuid.uuid4().int)[:7]}", "patient"
    )

    async def user_id_of(token: str) -> str:
        r = await client.get(
            "/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}
        )
        return r.json()["user_id"]

    ids = {
        P: await user_id_of(patient_token),
        D: await user_id_of(verified_driver_token),
        A: await user_id_of(admin_token),
    }

    def headers(kind: str) -> dict:
        if kind == N:
            return {}
        token = create_access_token(
            {"sub": ids[kind], "role": kind, "roles": [kind], "active_role": kind}
        )
        return {"Authorization": f"Bearer {token}"}

    return headers


def test_every_route_has_a_policy_entry():
    missing = [route for route in ROUTES if route not in POLICY]
    assert not missing, f"add these routes to POLICY: {missing}"
    stale = [route for route in POLICY if route not in ROUTES]
    assert not stale, f"POLICY lists routes that no longer exist: {stale}"


@pytest.mark.parametrize("method,path", ROUTES)
async def test_route_enforces_its_policy(client, callers, method, path):
    allowed = POLICY[(method, path)]
    url = (
        path.replace("{ride_id}", str(uuid.uuid4()))
        .replace("{driver_id}", str(uuid.uuid4()))
        .replace("{hospital_id}", str(uuid.uuid4()))
    )

    for kind in (N, P, D, A):
        # /auth/logout and friends need a body-less call; an empty JSON body is fine
        # because auth is checked before the body is validated.
        resp = await client.request(method, url, headers=callers(kind), json={})
        if kind in allowed:
            assert resp.status_code not in (401, 403), (
                kind,
                resp.status_code,
                resp.text,
            )
        else:
            expected = 401 if kind == N else 403
            assert resp.status_code == expected, (kind, resp.status_code, resp.text)


async def test_metrics_needs_the_scraper_token(client, monkeypatch):
    monkeypatch.setattr(settings, "METRICS_TOKEN", "scraper-secret")
    ok = await client.get(
        "/metrics", headers={"Authorization": "Bearer scraper-secret"}
    )
    wrong = await client.get("/metrics", headers={"Authorization": "Bearer nope"})
    assert ok.status_code == 200
    assert wrong.status_code == 403


async def test_metrics_is_closed_when_no_token_is_configured(client, monkeypatch):
    monkeypatch.setattr(settings, "METRICS_TOKEN", "")
    r = await client.get("/metrics", headers={"Authorization": "Bearer "})
    assert r.status_code in (401, 403)
