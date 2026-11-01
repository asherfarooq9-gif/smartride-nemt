"""A ride a driver accepts by hand must still pre-alert its hospital (audit A1)."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import metrics
from app.models.models import Hospital, Ride, Specialty
from tests.test_dispatch_endpoints import PICKUP, _create_emergency, _register

ALERT = "app.services.emergency_dispatch.send_hospital_alert"


def _not_prealerted() -> float:
    return metrics.dispatch_failures_total.labels(
        reason="hospital_not_prealerted"
    )._value.get()


async def _sole_hospital(db: AsyncSession, name: str) -> Hospital:
    """One hospital ~5 km away; every other one is taken out of the running."""
    hospital = Hospital(
        name=name,
        address="A",
        city="Islamabad",
        lat=PICKUP["pickup_lat"] + 0.045,
        lng=PICKUP["pickup_lng"],
        specialties=[s.value for s in Specialty],
        ed_capacity=1000,
        ed_current_load=0,
    )
    db.add(hospital)
    await db.commit()
    await db.execute(
        update(Hospital).where(Hospital.id != hospital.id).values(is_active=False)
    )
    await db.commit()
    return hospital


async def _accept(client: AsyncClient, driver_token: str, phone: str):
    patient_token = await _register(client, phone, "patient")
    ride_id = await _create_emergency(client, patient_token)
    response = await client.post(
        f"/api/v1/rides/{ride_id}/accept",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    return ride_id, response


@pytest.mark.asyncio
async def test_manual_accept_pre_alerts_the_hospital_it_chose(
    client, verified_driver_token, db
):
    hospital = await _sole_hospital(db, "Prealert Test Hospital")
    try:
        with patch(ALERT, new=AsyncMock(return_value=True)) as alert:
            ride_id, r = await _accept(client, verified_driver_token, "+92300730191")
    finally:
        await db.execute(update(Hospital).values(is_active=True))
        await db.commit()

    assert r.status_code == 200, r.text
    alert.assert_awaited_once()
    sent = alert.await_args.kwargs
    assert sent["hospital"].hospital_name == hospital.name
    assert str(sent["ride"].id) == ride_id
    assert sent["triage"]["severity"]


@pytest.mark.asyncio
async def test_a_failed_pre_alert_is_counted_and_does_not_undo_the_accept(
    client, verified_driver_token, db
):
    await _sole_hospital(db, "Prealert Fail Hospital")
    before = _not_prealerted()
    try:
        with patch(ALERT, new=AsyncMock(return_value=False)):
            ride_id, r = await _accept(client, verified_driver_token, "+92300730192")
    finally:
        await db.execute(update(Hospital).values(is_active=True))
        await db.commit()

    assert r.status_code == 200, r.text
    assert _not_prealerted() == before + 1
    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    assert ride.driver_id is not None


@pytest.mark.asyncio
async def test_a_crashing_pre_alert_does_not_fail_the_accept(
    client, verified_driver_token, db
):
    await _sole_hospital(db, "Prealert Crash Hospital")
    before = _not_prealerted()
    try:
        with patch(ALERT, new=AsyncMock(side_effect=RuntimeError("boom"))):
            _, r = await _accept(client, verified_driver_token, "+92300730193")
    finally:
        await db.execute(update(Hospital).values(is_active=True))
        await db.commit()

    assert r.status_code == 200, r.text
    assert _not_prealerted() == before + 1
