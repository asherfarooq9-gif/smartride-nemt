"""Rides router hardening: rating race, emergency idempotency, dual-role access,
CSV export, bounded free text and the typed detail payload."""

import asyncio
import csv
import io
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest
from sqlalchemy import event, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.models import (
    Driver,
    Patient,
    Ride,
    RideStatus,
    RideType,
    Specialty,
    SeverityLevel,
    TriageEvent,
)
from app.services import idempotency, ride_export
from tests.conftest import TEST_DATABASE_URL
from tests.test_dispatch_endpoints import _create_emergency, _register
from tests.test_ride_lifecycle import _auth, _phone

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}
SYMPTOMS = "crushing chest pain"


async def _post_emergency(client, token, key=None, **extra):
    headers = _auth(token)
    if key is not None:
        headers["Idempotency-Key"] = key
    return await client.post(
        "/api/v1/rides/emergency",
        json={**PICKUP, "symptom_text": SYMPTOMS, **extra},
        headers=headers,
    )


async def _ride_count(db, response) -> int:
    """Rides belonging to the patient who owns the ride in `response`."""
    db.expire_all()
    patient_id = response.json()["patient_id"]
    return (
        await db.execute(
            select(func.count()).select_from(Ride).where(Ride.patient_id == patient_id)
        )
    ).scalar_one()


async def _set_status(db, ride_id, status: RideStatus, **values):
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(status=status, **values)
    )
    await db.commit()


# ── 1. rating: one guarded UPDATE ────────────────────────────────────────────


async def _completed_ride(client, db):
    token = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, token)
    await _set_status(db, ride_id, RideStatus.completed)
    return token, ride_id


async def test_rating_is_stored_once_and_second_attempt_is_409(client, db):
    token, ride_id = await _completed_ride(client, db)
    url = f"/api/v1/rides/{ride_id}/rate"

    first = await client.post(
        url, json={"rating": 4, "comment": "ok"}, headers=_auth(token)
    )
    second = await client.post(url, json={"rating": 1}, headers=_auth(token))

    assert first.status_code == 200
    assert first.json()["patient_rating"] == 4
    assert second.status_code == 409


async def test_rating_requires_completed_ride_and_the_owner(client, db):
    owner = await _register(client, _phone(), "patient")
    stranger = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, owner)
    url = f"/api/v1/rides/{ride_id}/rate"

    not_done = await client.post(url, json={"rating": 5}, headers=_auth(owner))
    await _set_status(db, ride_id, RideStatus.completed)
    wrong_patient = await client.post(url, json={"rating": 5}, headers=_auth(stranger))

    assert not_done.status_code == 400
    assert wrong_patient.status_code == 403


async def test_two_simultaneous_ratings_only_one_wins(isolated_client, db):
    token, ride_id = await _completed_ride(isolated_client, db)
    url = f"/api/v1/rides/{ride_id}/rate"

    results = await asyncio.gather(
        isolated_client.post(url, json={"rating": 5}, headers=_auth(token)),
        isolated_client.post(url, json={"rating": 1}, headers=_auth(token)),
    )

    assert sorted(r.status_code for r in results) == [200, 409]


# ── 2. emergency creation is idempotent ──────────────────────────────────────


async def test_double_submit_returns_the_same_ride_and_dispatches_once(client, db):
    token = await _register(client, _phone(), "patient")
    dispatch = AsyncMock()

    with patch("app.routers.rides._run_dispatch", new=dispatch):
        first = await _post_emergency(client, token)
        second = await _post_emergency(client, token)

    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    assert dispatch.await_count == 1
    assert await _ride_count(db, first) == 1


async def test_same_idempotency_key_returns_the_same_ride_even_after_it_ended(
    client, db
):
    token = await _register(client, _phone(), "patient")
    key = f"key-{uuid.uuid4()}"
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        first = await _post_emergency(client, token, key=key)
        await _set_status(db, first.json()["id"], RideStatus.cancelled)
        replay = await _post_emergency(client, token, key=key)
        fresh = await _post_emergency(client, token, key=f"key-{uuid.uuid4()}")

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json()["id"] == first.json()["id"]
    assert fresh.status_code == 201
    assert fresh.json()["id"] != first.json()["id"]


async def test_idempotency_key_is_per_patient(client, db):
    key = f"shared-{uuid.uuid4()}"
    one = await _register(client, _phone(), "patient")
    two = await _register(client, _phone(), "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        a = await _post_emergency(client, one, key=key)
        b = await _post_emergency(client, two, key=key)

    assert a.status_code == b.status_code == 201
    assert a.json()["id"] != b.json()["id"]


@pytest.mark.parametrize("bad_key", ["has space", "x" * 129, "semi;colon"])
async def test_malformed_idempotency_key_is_rejected(client, bad_key):
    token = await _register(client, _phone(), "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await _post_emergency(client, token, key=bad_key)

    assert r.status_code == 400


async def test_idempotency_fails_open_when_redis_is_down(client, db):
    token = await _register(client, _phone(), "patient")
    key = f"key-{uuid.uuid4()}"
    with (
        patch("app.routers.rides._run_dispatch", new=AsyncMock()),
        patch.object(idempotency, "get_redis", side_effect=ConnectionError("down")),
    ):
        first = await _post_emergency(client, token, key=key)
        second = await _post_emergency(client, token, key=key)

    assert first.status_code == 201
    # The key could not be remembered, but the active-ride rule still dedupes.
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    assert await _ride_count(db, first) == 1


async def test_losing_the_unique_index_race_returns_the_existing_ride(client, db):
    token = await _register(client, _phone(), "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()) as dispatch:
        first = await _post_emergency(client, token)
        # Simulate the pre-check missing the other request's commit.
        with patch(
            "app.routers.rides._find_replayed_ride", new=AsyncMock(return_value=None)
        ):
            loser = await _post_emergency(client, token)

    assert loser.status_code == 200
    assert loser.json()["id"] == first.json()["id"]
    assert dispatch.await_count == 1
    assert await _ride_count(db, first) == 1


async def test_concurrent_emergency_requests_create_one_ride(isolated_client, db):
    token = await _register(isolated_client, _phone(), "patient")
    dispatch = AsyncMock()

    with patch("app.routers.rides._run_dispatch", new=dispatch):
        results = await asyncio.gather(
            _post_emergency(isolated_client, token),
            _post_emergency(isolated_client, token),
        )

    assert sorted(r.status_code for r in results) == [200, 201]
    assert results[0].json()["id"] == results[1].json()["id"]
    assert dispatch.await_count == 1
    assert await _ride_count(db, results[0]) == 1


# ── 3. one authorization rule for GET /{id} and GET /{id}/detail ─────────────


async def _dual_role_driving_someone_elses_ride(client, db):
    suffix = uuid.uuid4().hex[:6].upper()
    reg = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": _phone(),
            "password": "pass1234",
            "full_name": "Dual",
            "roles": ["patient", "driver"],
            "license_no": f"DL-{suffix}",
            "vehicle_plate": f"DP-{suffix}",
            "vehicle_type": "ambulette",
        },
    )
    assert reg.status_code == 201, reg.text
    dual_token = reg.json()["access_token"]
    driver = (
        await db.execute(select(Driver).order_by(Driver.created_at.desc()).limit(1))
    ).scalar_one()

    owner = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, owner)
    await _set_status(db, ride_id, RideStatus.driver_assigned, driver_id=driver.id)
    db.add(
        TriageEvent(
            ride_id=ride_id,
            symptom_text=SYMPTOMS,
            predicted_specialty=Specialty.cardiology,
            confidence_score=0.9,
            severity_level=SeverityLevel.four,
            model_version="test",
        )
    )
    await db.commit()
    return dual_token, owner, ride_id


async def test_dual_role_account_driving_a_ride_can_read_it(client, db):
    dual_token, _, ride_id = await _dual_role_driving_someone_elses_ride(client, db)

    plain = await client.get(f"/api/v1/rides/{ride_id}", headers=_auth(dual_token))
    detail = await client.get(
        f"/api/v1/rides/{ride_id}/detail", headers=_auth(dual_token)
    )

    assert plain.status_code == 200, plain.text
    assert detail.status_code == 200, detail.text
    assert detail.json()["id"] == plain.json()["id"] == ride_id


async def test_driver_view_never_includes_raw_symptoms_but_owner_does(client, db):
    dual_token, owner, ride_id = await _dual_role_driving_someone_elses_ride(client, db)

    as_driver = (
        await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(dual_token))
    ).json()
    as_owner = (
        await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(owner))
    ).json()

    assert "symptom_text" not in as_driver["triage"]
    assert as_driver["triage"]["predicted_specialty"] == "cardiology"
    assert as_driver["triage"]["severity_level"] == "4"
    assert SYMPTOMS not in str(as_driver)
    assert as_owner["triage"]["symptom_text"] == SYMPTOMS


async def test_dual_role_account_cannot_read_an_unrelated_ride(client, db):
    dual_token, _, _ = await _dual_role_driving_someone_elses_ride(client, db)
    other_patient = await _register(client, _phone(), "patient")
    other_ride = await _create_emergency(client, other_patient)

    for suffix in ("", "/detail"):
        r = await client.get(
            f"/api/v1/rides/{other_ride}{suffix}", headers=_auth(dual_token)
        )
        assert r.status_code == 403, suffix


async def test_detail_payload_keeps_its_field_names(client, db):
    dual_token, owner, ride_id = await _dual_role_driving_someone_elses_ride(client, db)

    body = (
        await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(owner))
    ).json()

    assert set(body["patient"]) == {"full_name", "phone", "mobility_needs"}
    assert set(body["driver"]) == {
        "full_name",
        "phone",
        "vehicle_plate",
        "vehicle_type",
    }
    assert set(body["triage"]) == {
        "predicted_specialty",
        "confidence_score",
        "severity_level",
        "symptom_text",
    }
    assert body["hospital"] is None


# ── 4. CSV export ────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("=1+1", "'=1+1"),
        ("+1", "'+1"),
        ("-2", "'-2"),
        ("@SUM(A1)", "'@SUM(A1)"),
        ("\t=1", "'\t=1"),
        ("\r=1", "'\r=1"),
        ("G-8 Islamabad", "G-8 Islamabad"),
        ("", ""),
    ],
)
def test_csv_safe_prefixes_formula_starters(raw, expected):
    assert ride_export.csv_safe(raw) == expected


@pytest.fixture
async def export_factory(monkeypatch):
    """Point the export at the test database and record every SQL statement."""
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    statements: list[str] = []

    @event.listens_for(engine.sync_engine, "before_cursor_execute")
    def _record(conn, cursor, statement, *args):
        statements.append(statement.lower())

    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    monkeypatch.setattr(ride_export.database, "AsyncSessionLocal", factory)
    yield statements
    await engine.dispose()


async def test_export_pages_escapes_cells_and_never_counts(
    client, db, monkeypatch, export_factory
):
    token = await _register(client, _phone(), "patient")
    me = (
        await db.execute(select(Patient).order_by(Patient.created_at.desc()).limit(1))
    ).scalar_one()
    addresses = ['=HYPERLINK("http://x","y")', 'a,"quoted"\nsecond line', "-1", "plain"]
    for index, address in enumerate(addresses + ["five"]):
        db.add(
            Ride(
                patient_id=me.id,
                ride_type=RideType.scheduled,
                status=RideStatus.pending,
                pickup_lat=33.7,
                pickup_lng=73.0,
                pickup_address=address,
                scheduled_for=datetime.now(timezone.utc) + timedelta(days=1),
                requested_at=datetime.now(timezone.utc) + timedelta(seconds=index),
            )
        )
    await db.commit()
    monkeypatch.setattr(ride_export, "EXPORT_PAGE_SIZE", 2)

    chunks = [
        c
        async for c in ride_export.rides_csv_chunks(
            ride_type=RideType.scheduled, search=None
        )
    ]

    rows = list(csv.reader(io.StringIO("".join(chunks))))
    assert rows[0] == ride_export.CSV_HEADER
    exported = {row[3] for row in rows[1:] if row[9] == str(me.id)}
    assert exported == {
        '\'=HYPERLINK("http://x","y")',
        'a,"quoted"\nsecond line',
        "'-1",
        "plain",
        "five",
    }
    assert len({row[0] for row in rows[1:]}) == len(rows) - 1  # no duplicates
    assert len(chunks) >= 4  # header + three pages of at most two rows
    assert not [s for s in export_factory if "count(" in s]
    assert token  # the patient registered through the API


async def test_export_endpoint_streams_with_its_own_session(
    client, admin_token, export_factory
):
    r = await client.get("/api/v1/rides/export.csv", headers=_auth(admin_token))

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/csv")
    assert r.text.splitlines()[0] == ",".join(ride_export.CSV_HEADER)


# ── 5. schemas ───────────────────────────────────────────────────────────────


async def test_overlong_free_text_is_rejected(client):
    token = await _register(client, _phone(), "patient")
    too_long = "a" * 501

    emergency = await _post_emergency(client, token, pickup_address=too_long)
    cancel = await client.patch(
        f"/api/v1/rides/{uuid.uuid4()}/status",
        json={"status": "cancelled", "cancel_reason": too_long},
        headers=_auth(token),
    )

    assert emergency.status_code == 422
    assert cancel.status_code == 422


async def test_free_text_at_the_limit_is_accepted(client):
    token = await _register(client, _phone(), "patient")
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await _post_emergency(client, token, pickup_address="a" * 500)

    assert r.status_code == 201


def test_openapi_describes_the_detail_sections_with_typed_models():
    from main import app

    schemas = app.openapi()["components"]["schemas"]
    detail = schemas["RideDetailResponse"]["properties"]

    for section, model in (
        ("patient", "RidePatientInfo"),
        ("driver", "RideDriverInfo"),
        ("hospital", "RideHospitalInfo"),
        ("triage", "RideTriageInfo"),
    ):
        assert model in str(detail[section]), section
    assert (
        "200" in app.openapi()["paths"]["/api/v1/rides/emergency"]["post"]["responses"]
    )
