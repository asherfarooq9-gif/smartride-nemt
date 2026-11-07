"""A driver may only take a scheduled ride once it is close to due (QA finding F2).

Without a window, the pending list and POST /rides/{id}/accept would let a driver
take a ride booked for next week. They would hold it as driver_assigned, be unable
to tap "on my way" for days, and after DRIVER_ACK_TIMEOUT_SECONDS the dispatch loop
would take the ride back and set the driver offline.

A scheduled ride is hidden from, and refused to, drivers until it is inside the
dispatch lead window (settings.SCHEDULED_DISPATCH_LEAD_MINUTES), the same moment the
dispatch loop starts placing it.
"""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.models import Driver, Ride, RideStatus

PICKUP = {"pickup_lat": 33.7215, "pickup_lng": 73.0433}


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def _register_patient(client: AsyncClient, phone: str) -> str:
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": phone,
            "password": "pass1234",
            "role": "patient",
            "full_name": "T",
        },
    )
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


async def _book_scheduled(client: AsyncClient, token: str, when: datetime) -> str:
    r = await client.post(
        "/api/v1/rides/scheduled",
        json={**PICKUP, "scheduled_for": when.isoformat()},
        headers=_auth(token),
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


async def _park_driver_near_pickup(db: AsyncSession) -> None:
    driver = (
        await db.execute(select(Driver).order_by(Driver.created_at.desc()).limit(1))
    ).scalar_one()
    driver.current_lat = PICKUP["pickup_lat"] + 0.01
    driver.current_lng = PICKUP["pickup_lng"]
    await db.commit()


@pytest.mark.asyncio
async def test_a_ride_booked_days_ahead_is_not_offered_to_drivers(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    patient = await _register_patient(client, "+92300790001")
    ride_id = await _book_scheduled(
        client, patient, datetime.now(timezone.utc) + timedelta(days=3)
    )
    await _park_driver_near_pickup(db)

    r = await client.get("/api/v1/rides/pending", headers=_auth(verified_driver_token))

    assert r.status_code == 200
    assert ride_id not in [ride["id"] for ride in r.json()["items"]]


@pytest.mark.asyncio
async def test_a_driver_cannot_accept_a_ride_booked_days_ahead(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    patient = await _register_patient(client, "+92300790002")
    ride_id = await _book_scheduled(
        client, patient, datetime.now(timezone.utc) + timedelta(days=3)
    )
    await _park_driver_near_pickup(db)

    r = await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(verified_driver_token)
    )

    assert r.status_code in (400, 403, 409), r.text
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    await db.refresh(ride)
    assert ride.status == RideStatus.pending
    assert ride.driver_id is None


@pytest.mark.asyncio
async def test_a_refused_accept_leaves_the_driver_available(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    """Refusing must not claim the driver (a claimed driver would stay busy)."""
    patient = await _register_patient(client, "+92300790003")
    ride_id = await _book_scheduled(
        client, patient, datetime.now(timezone.utc) + timedelta(days=3)
    )
    await _park_driver_near_pickup(db)

    await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(verified_driver_token)
    )

    driver = (
        await db.execute(select(Driver).order_by(Driver.created_at.desc()).limit(1))
    ).scalar_one()
    await db.refresh(driver)
    assert driver.status.value == "available"


@pytest.mark.asyncio
async def test_a_ride_inside_the_lead_window_is_still_offered_and_acceptable(
    client: AsyncClient, verified_driver_token: str, db: AsyncSession
):
    """Guard against over-fixing: a ride that is almost due must stay takeable."""
    soon = datetime.now(timezone.utc) + timedelta(
        minutes=max(1, settings.SCHEDULED_DISPATCH_LEAD_MINUTES // 3)
    )
    patient = await _register_patient(client, "+92300790004")
    ride_id = await _book_scheduled(client, patient, soon)
    await _park_driver_near_pickup(db)

    listed = await client.get(
        "/api/v1/rides/pending", headers=_auth(verified_driver_token)
    )
    assert ride_id in [ride["id"] for ride in listed.json()["items"]]

    accepted = await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(verified_driver_token)
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["status"] == "driver_assigned"
