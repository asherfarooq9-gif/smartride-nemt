"""A driver lists how they take payment; the patient sees it once they are assigned.

The app never handles the money. These are only the ways a driver says they accept.
"""

import uuid

from sqlalchemy import select

from app.models.models import Driver, Patient, Ride, RideStatus, RideType
from tests.test_review_fixes import _auth, _register

ME = "/api/v1/drivers/me"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _driver(client):
    uid = uuid.uuid4().hex[:8]
    token = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"PM-{uid}",
        vehicle_plate=f"PM-{uid[:6]}",
        vehicle_type="sedan",
    )
    return token


async def test_a_new_driver_lists_no_payment_methods(client):
    token = await _driver(client)

    me = await client.get(ME, headers=_auth(token))

    assert me.json()["payment_methods"] == []


async def test_a_driver_can_set_and_change_their_payment_methods(client):
    token = await _driver(client)

    first = await client.patch(
        ME,
        json={"payment_methods": ["cash", "easypaisa"]},
        headers=_auth(token),
    )
    again = await client.patch(
        ME, json={"payment_methods": ["jazzcash"]}, headers=_auth(token)
    )

    assert first.status_code == 200, first.text
    assert first.json()["payment_methods"] == ["cash", "easypaisa"]
    assert again.json()["payment_methods"] == ["jazzcash"]
    assert (await client.get(ME, headers=_auth(token))).json()["payment_methods"] == [
        "jazzcash"
    ]


async def test_an_unknown_payment_method_is_refused(client):
    token = await _driver(client)

    out = await client.patch(
        ME, json={"payment_methods": ["bitcoin"]}, headers=_auth(token)
    )

    assert out.status_code == 422


async def test_duplicates_collapse_and_order_is_kept(client):
    token = await _driver(client)

    out = await client.patch(
        ME,
        json={"payment_methods": ["cash", "jazzcash", "cash"]},
        headers=_auth(token),
    )

    assert out.json()["payment_methods"] == ["cash", "jazzcash"]


async def test_updating_another_field_leaves_payment_methods_alone(client):
    token = await _driver(client)
    await client.patch(ME, json={"payment_methods": ["cash"]}, headers=_auth(token))

    out = await client.patch(ME, json={"vehicle_type": "van"}, headers=_auth(token))

    assert out.json()["payment_methods"] == ["cash"]


async def test_the_patient_sees_the_assigned_drivers_methods_in_the_ride(client, db):
    driver_token = await _driver(client)
    await client.patch(
        ME,
        json={"payment_methods": ["cash", "easypaisa"]},
        headers=_auth(driver_token),
    )
    patient_token = await _register(client, _phone(), "patient")
    patient_user = (
        await client.get("/api/v1/auth/me", headers=_auth(patient_token))
    ).json()["user_id"]
    patient = (
        await db.execute(select(Patient).where(Patient.user_id == patient_user))
    ).scalar_one()
    driver_user = (
        await client.get("/api/v1/auth/me", headers=_auth(driver_token))
    ).json()["user_id"]
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == driver_user))
    ).scalar_one()
    ride = Ride(
        patient_id=patient.id,
        driver_id=driver.id,
        ride_type=RideType.scheduled,
        status=RideStatus.driver_assigned,
        pickup_lat=33.72,
        pickup_lng=73.04,
    )
    db.add(ride)
    await db.commit()

    detail = await client.get(
        f"/api/v1/rides/{ride.id}/detail", headers=_auth(patient_token)
    )

    assert detail.status_code == 200, detail.text
    assert detail.json()["driver"]["payment_methods"] == ["cash", "easypaisa"]
