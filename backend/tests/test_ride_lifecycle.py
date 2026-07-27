"""End-to-end ride lifecycle: status transitions, cancellation, rating, detail
PHI scoping and the admin listing/export routes.

Covers the paths a ride actually takes in production, which the creation-only
tests in test_rides.py and the accept tests in test_dispatch_endpoints.py leave
untouched.
"""

import uuid
from datetime import datetime, timedelta, timezone

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from unittest.mock import AsyncMock, patch

from app.models.models import Driver, DriverStatus, Patient, User, UserFcmToken

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _register(client: AsyncClient, role: str, **extra) -> str:
    payload = {
        "phone": _phone(),
        "password": "pass1234",
        "role": role,
        "full_name": "T",
        **extra,
    }
    r = await client.post("/api/v1/auth/register", json=payload)
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


async def _register_verified_driver(client: AsyncClient, db: AsyncSession) -> str:
    uid = uuid.uuid4().hex[:8]
    token = await _register(
        client,
        "driver",
        license_no=f"LC-{uid}",
        vehicle_plate=f"PL-{uid[:6]}",
        vehicle_type="sedan",
    )
    driver = (
        await db.execute(select(Driver).order_by(Driver.created_at.desc()).limit(1))
    ).scalar_one()
    driver.is_verified = True
    await db.commit()
    return token


async def _create_emergency(client: AsyncClient, token: str) -> str:
    with patch("app.routers.rides._run_dispatch", new=AsyncMock()):
        r = await client.post(
            "/api/v1/rides/emergency",
            json={**PICKUP, "symptom_text": "chest pain"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _set_status(
    client: AsyncClient, ride_id: str, token: str, status: str, **extra
):
    return await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": status, **extra},
        headers=_auth(token),
    )


@pytest_asyncio.fixture
async def accepted_ride(client: AsyncClient, db: AsyncSession):
    """A ride already accepted by a verified driver, plus both tokens."""
    patient_token = await _register(client, "patient")
    driver_token = await _register_verified_driver(client, db)
    ride_id = await _create_emergency(client, patient_token)

    r = await client.post(f"/api/v1/rides/{ride_id}/accept", headers=_auth(driver_token))
    assert r.status_code == 200, r.text
    return {
        "ride_id": ride_id,
        "patient_token": patient_token,
        "driver_token": driver_token,
        "driver_id": r.json()["driver_id"],
    }


# ── Driver status transitions ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_driver_walks_ride_through_to_completion(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    ride_id, token = accepted_ride["ride_id"], accepted_ride["driver_token"]

    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_status(client, ride_id, token, status)
        assert r.status_code == 200, f"{status}: {r.text}"
        assert r.json()["status"] == status

    body = r.json()
    assert body["pickup_at"] is not None
    assert body["arrived_at"] is not None
    assert body["completed_at"] is not None

    # Completing must free the driver for the next emergency.
    driver = (
        await db.execute(
            select(Driver).where(Driver.id == uuid.UUID(accepted_ride["driver_id"]))
        )
    ).scalar_one()
    await db.refresh(driver)
    assert driver.status == DriverStatus.available


@pytest.mark.asyncio
async def test_driver_cannot_skip_a_transition(client: AsyncClient, accepted_ride: dict):
    """driver_assigned -> completed skips three states and must be refused."""
    r = await _set_status(
        client, accepted_ride["ride_id"], accepted_ride["driver_token"], "completed"
    )
    assert r.status_code == 400
    assert "Cannot transition" in r.json()["detail"]


@pytest.mark.asyncio
async def test_driver_cancel_frees_the_driver(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    r = await _set_status(
        client, accepted_ride["ride_id"], accepted_ride["driver_token"], "cancelled"
    )
    assert r.status_code == 200
    assert r.json()["status"] == "cancelled"
    assert r.json()["cancelled_at"] is not None

    driver = (
        await db.execute(
            select(Driver).where(Driver.id == uuid.UUID(accepted_ride["driver_id"]))
        )
    ).scalar_one()
    await db.refresh(driver)
    assert driver.status == DriverStatus.available


@pytest.mark.asyncio
async def test_driver_cannot_update_someone_elses_ride(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    other_driver = await _register_verified_driver(client, db)
    r = await _set_status(
        client, accepted_ride["ride_id"], other_driver, "driver_en_route"
    )
    assert r.status_code == 403


# ── Patient cancellation ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_patient_cancels_pending_ride_with_reason(client: AsyncClient):
    token = await _register(client, "patient")
    ride_id = await _create_emergency(client, token)

    r = await _set_status(
        client, ride_id, token, "cancelled", cancel_reason="Symptoms eased"
    )
    assert r.status_code == 200
    assert r.json()["status"] == "cancelled"
    assert r.json()["cancel_reason"] == "Symptoms eased"


@pytest.mark.asyncio
async def test_patient_cannot_set_a_non_cancelled_status(client: AsyncClient):
    token = await _register(client, "patient")
    ride_id = await _create_emergency(client, token)

    r = await _set_status(client, ride_id, token, "completed")
    assert r.status_code == 400
    assert "only cancel" in r.json()["detail"]


@pytest.mark.asyncio
async def test_patient_cannot_cancel_once_transport_has_started(
    client: AsyncClient, accepted_ride: dict
):
    ride_id = accepted_ride["ride_id"]
    for status in ("driver_en_route", "patient_picked_up"):
        assert (
            await _set_status(client, ride_id, accepted_ride["driver_token"], status)
        ).status_code == 200

    r = await _set_status(client, ride_id, accepted_ride["patient_token"], "cancelled")
    assert r.status_code == 400
    assert "current state" in r.json()["detail"]


# ── Admin cancellation ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_admin_cancel_releases_the_assigned_driver(
    client: AsyncClient, accepted_ride: dict, admin_token: str, db: AsyncSession
):
    r = await _set_status(client, accepted_ride["ride_id"], admin_token, "cancelled")
    assert r.status_code == 200
    assert r.json()["cancel_reason"] == "Cancelled by admin"

    driver = (
        await db.execute(
            select(Driver).where(Driver.id == uuid.UUID(accepted_ride["driver_id"]))
        )
    ).scalar_one()
    await db.refresh(driver)
    assert driver.status == DriverStatus.available


@pytest.mark.asyncio
async def test_admin_can_only_cancel(
    client: AsyncClient, accepted_ride: dict, admin_token: str
):
    r = await _set_status(
        client, accepted_ride["ride_id"], admin_token, "driver_en_route"
    )
    assert r.status_code == 400
    assert "only cancel" in r.json()["detail"]


# ── Rating ───────────────────────────────────────────────────────────────────


async def _complete(client: AsyncClient, accepted_ride: dict) -> None:
    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_status(
            client, accepted_ride["ride_id"], accepted_ride["driver_token"], status
        )
        assert r.status_code == 200, r.text


@pytest.mark.asyncio
async def test_patient_rates_completed_ride(client: AsyncClient, accepted_ride: dict):
    await _complete(client, accepted_ride)

    r = await client.post(
        f"/api/v1/rides/{accepted_ride['ride_id']}/rate",
        json={"rating": 5, "comment": "Fast and calm"},
        headers=_auth(accepted_ride["patient_token"]),
    )
    assert r.status_code == 200
    assert r.json()["patient_rating"] == 5
    assert r.json()["rating_comment"] == "Fast and calm"


@pytest.mark.asyncio
async def test_rating_the_same_ride_twice_conflicts(
    client: AsyncClient, accepted_ride: dict
):
    await _complete(client, accepted_ride)
    headers = _auth(accepted_ride["patient_token"])
    url = f"/api/v1/rides/{accepted_ride['ride_id']}/rate"

    first = await client.post(url, json={"rating": 4}, headers=headers)
    assert first.status_code == 200
    second = await client.post(url, json={"rating": 2}, headers=headers)
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_cannot_rate_an_incomplete_ride(client: AsyncClient, accepted_ride: dict):
    r = await client.post(
        f"/api/v1/rides/{accepted_ride['ride_id']}/rate",
        json={"rating": 5},
        headers=_auth(accepted_ride["patient_token"]),
    )
    assert r.status_code == 400
    assert "completed" in r.json()["detail"]


@pytest.mark.asyncio
async def test_other_patient_cannot_rate_the_ride(
    client: AsyncClient, accepted_ride: dict
):
    await _complete(client, accepted_ride)
    stranger = await _register(client, "patient")

    r = await client.post(
        f"/api/v1/rides/{accepted_ride['ride_id']}/rate",
        json={"rating": 1},
        headers=_auth(stranger),
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_rating_outside_one_to_five_is_rejected(
    client: AsyncClient, accepted_ride: dict
):
    await _complete(client, accepted_ride)
    r = await client.post(
        f"/api/v1/rides/{accepted_ride['ride_id']}/rate",
        json={"rating": 9},
        headers=_auth(accepted_ride["patient_token"]),
    )
    assert r.status_code == 422


# ── Ride detail and PHI scoping ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_detail_gives_patient_their_own_symptom_text(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    from app.models.models import Specialty, SeverityLevel, TriageEvent

    ride_id = accepted_ride["ride_id"]
    db.add(
        TriageEvent(
            ride_id=uuid.UUID(ride_id),
            symptom_text="crushing chest pain radiating to left arm",
            predicted_specialty=Specialty.cardiology,
            confidence_score=0.91,
            severity_level=SeverityLevel.one,
            model_version="test",
        )
    )
    await db.commit()

    r = await client.get(
        f"/api/v1/rides/{ride_id}/detail",
        headers=_auth(accepted_ride["patient_token"]),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["triage"]["predicted_specialty"] == "cardiology"
    assert body["triage"]["symptom_text"].startswith("crushing chest pain")
    assert body["patient"]["full_name"] == "T"
    assert body["driver"]["vehicle_type"] == "sedan"


@pytest.mark.asyncio
async def test_detail_withholds_symptom_text_from_the_driver(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    from app.models.models import Specialty, SeverityLevel, TriageEvent

    ride_id = accepted_ride["ride_id"]
    db.add(
        TriageEvent(
            ride_id=uuid.UUID(ride_id),
            symptom_text="patient reports recent overdose",
            predicted_specialty=Specialty.general_emergency,
            confidence_score=0.5,
            severity_level=SeverityLevel.two,
            model_version="test",
        )
    )
    await db.commit()

    r = await client.get(
        f"/api/v1/rides/{ride_id}/detail",
        headers=_auth(accepted_ride["driver_token"]),
    )
    assert r.status_code == 200
    triage = r.json()["triage"]
    assert triage["severity_level"] == "2"
    assert "symptom_text" not in triage


@pytest.mark.asyncio
async def test_detail_forbidden_for_unrelated_patient(
    client: AsyncClient, accepted_ride: dict
):
    stranger = await _register(client, "patient")
    r = await client.get(
        f"/api/v1/rides/{accepted_ride['ride_id']}/detail", headers=_auth(stranger)
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_detail_allows_admin(
    client: AsyncClient, accepted_ride: dict, admin_token: str
):
    r = await client.get(
        f"/api/v1/rides/{accepted_ride['ride_id']}/detail", headers=_auth(admin_token)
    )
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_detail_404_for_unknown_ride(client: AsyncClient, admin_token: str):
    r = await client.get(
        f"/api/v1/rides/{uuid.uuid4()}/detail", headers=_auth(admin_token)
    )
    assert r.status_code == 404


# ── Push notification on status change ───────────────────────────────────────


@pytest.mark.asyncio
async def test_status_change_pushes_to_patient_with_a_token(
    client: AsyncClient, accepted_ride: dict, db: AsyncSession
):
    """A patient with a registered FCM token must not break the transition."""
    patient = (
        await db.execute(select(Patient).order_by(Patient.created_at.desc()).limit(1))
    ).scalar_one()
    user = (await db.execute(select(User).where(User.id == patient.user_id))).scalar_one()
    db.add(UserFcmToken(user_id=user.id, token="fcm-test-token"))
    await db.commit()

    with patch("app.services.notifications.send_push", new=AsyncMock()):
        r = await _set_status(
            client,
            accepted_ride["ride_id"],
            accepted_ride["driver_token"],
            "driver_en_route",
        )
    assert r.status_code == 200


# ── Scheduled rides and listings ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_scheduled_ride_must_be_in_the_future(client: AsyncClient):
    token = await _register(client, "patient")
    past = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()

    r = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": past},
        headers=_auth(token),
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_driver_my_rides_lists_only_their_own(
    client: AsyncClient, accepted_ride: dict
):
    r = await client.get(
        "/api/v1/rides/mine", headers=_auth(accepted_ride["driver_token"])
    )
    assert r.status_code == 200
    items = r.json()["items"]
    assert items
    assert all(i["driver_id"] == accepted_ride["driver_id"] for i in items)


@pytest.mark.asyncio
async def test_admin_list_filters_by_status_and_type(
    client: AsyncClient, accepted_ride: dict, admin_token: str
):
    r = await client.get(
        "/api/v1/rides?status=driver_assigned&ride_type=emergency",
        headers=_auth(admin_token),
    )
    assert r.status_code == 200
    for item in r.json()["items"]:
        assert item["status"] == "driver_assigned"
        assert item["ride_type"] == "emergency"


@pytest.mark.asyncio
async def test_admin_list_rejects_an_unparseable_filter(
    client: AsyncClient, admin_token: str
):
    r = await client.get("/api/v1/rides?status=not_a_status", headers=_auth(admin_token))
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_admin_exports_rides_as_csv(
    client: AsyncClient, accepted_ride: dict, admin_token: str
):
    r = await client.get("/api/v1/rides/export.csv", headers=_auth(admin_token))
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/csv")
    text = r.text
    assert text.splitlines()[0].startswith("id,ride_type,status")
    assert accepted_ride["ride_id"] in text


@pytest.mark.asyncio
async def test_csv_export_requires_admin(client: AsyncClient):
    token = await _register(client, "patient")
    r = await client.get("/api/v1/rides/export.csv", headers=_auth(token))
    assert r.status_code == 403


# ── Background dispatch wrapper ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_run_dispatch_ignores_a_missing_ride():
    """The background task must not raise when the ride has vanished."""
    from app.routers.rides import _run_dispatch

    await _run_dispatch(str(uuid.uuid4()), "chest pain")


@pytest.mark.asyncio
async def test_run_dispatch_swallows_and_logs_dispatch_failure(
    client: AsyncClient, db: AsyncSession
):
    """A triage/dispatch outage must not escape into the request lifecycle."""
    from app.routers.rides import _run_dispatch

    token = await _register(client, "patient")
    ride_id = await _create_emergency(client, token)

    with patch(
        "app.services.emergency_dispatch.dispatch_emergency",
        new=AsyncMock(side_effect=RuntimeError("triage down")),
    ):
        await _run_dispatch(ride_id, "chest pain")
