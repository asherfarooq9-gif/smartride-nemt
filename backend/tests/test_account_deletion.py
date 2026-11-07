"""Deleting an account anonymizes it: personal data goes, history and money stay."""

import uuid
from decimal import Decimal

from sqlalchemy import select, update

from app.models.models import (
    Driver,
    Patient,
    Ride,
    RideStatus,
    RideType,
    TriageEvent,
    User,
)
from app.services.retention import PURGED_MARKER
from tests.test_review_fixes import _auth, _driver_extra, _register

ME = "/api/v1/auth/me"
DELETE = "/api/v1/auth/delete-account"
PASSWORD = "pass1234"


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _user_id(client, token: str) -> str:
    return (await client.get(ME, headers=_auth(token))).json()["user_id"]


async def _patient_with_ride(client, db, status: RideStatus):
    phone = _phone()
    token = await _register(client, phone, "patient", full_name="Real Name")
    user_id = await _user_id(client, token)
    patient = (
        await db.execute(select(Patient).where(Patient.user_id == user_id))
    ).scalar_one()
    patient.date_of_birth = None
    patient.mobility_needs = "wheelchair"
    patient.emergency_contact_name = "Aunt"
    patient.emergency_contact_phone = "+923001112222"
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.emergency,
        status=status,
        pickup_lat=33.721534,
        pickup_lng=73.043377,
        pickup_address="House 5, Street 2, G-9",
        symptom_text="chest pain since morning",
        cancel_reason="felt better",
        rating_comment="thanks",
    )
    db.add(ride)
    await db.commit()
    return phone, token, patient, ride


async def _delete(client, token: str, password: str = PASSWORD):
    return await client.post(DELETE, json={"password": password}, headers=_auth(token))


async def test_deleting_a_patient_clears_their_data_and_keeps_the_ride(client, db):
    phone, token, patient, ride = await _patient_with_ride(
        client, db, RideStatus.completed
    )

    out = await _delete(client, token)

    assert out.status_code == 204, out.text
    await db.refresh(patient)
    await db.refresh(ride)
    assert patient.full_name == "Deleted user"
    assert patient.mobility_needs is None
    assert patient.emergency_contact_name is None
    assert patient.emergency_contact_phone is None
    assert ride.pickup_address is None
    assert ride.symptom_text is None
    assert ride.cancel_reason is None
    assert ride.rating_comment is None
    assert round(ride.pickup_lat, 2) == ride.pickup_lat == 33.72
    assert ride.status == RideStatus.completed  # the row and its history stay


async def test_deleting_blanks_the_triage_text(client, db):
    _, token, _, ride = await _patient_with_ride(client, db, RideStatus.completed)
    db.add(
        TriageEvent(
            ride_id=ride.id,
            symptom_text="chest pain",
            predicted_specialty="cardiology",
            confidence_score=0.9,
            severity_level="3",
            model_version="t",
        )
    )
    await db.commit()

    await _delete(client, token)

    text_ = (
        await db.execute(
            select(TriageEvent.symptom_text).where(TriageEvent.ride_id == ride.id)
        )
    ).scalar_one()
    assert text_ == PURGED_MARKER


async def test_a_deleted_account_cannot_sign_in_or_use_old_tokens(client, db):
    phone, token, _, _ = await _patient_with_ride(client, db, RideStatus.completed)

    await _delete(client, token)

    assert (await client.get(ME, headers=_auth(token))).status_code == 401
    login = await client.post(
        "/api/v1/auth/login", json={"phone": phone, "password": PASSWORD}
    )
    assert login.status_code == 401


async def test_every_session_ends_not_just_the_one_that_deleted(client, db):
    phone, token, _, _ = await _patient_with_ride(client, db, RideStatus.completed)
    other = (
        await client.post(
            "/api/v1/auth/login", json={"phone": phone, "password": PASSWORD}
        )
    ).json()["access_token"]

    await _delete(client, token)

    assert (await client.get(ME, headers=_auth(other))).status_code == 401


async def test_the_phone_number_can_register_again(client, db):
    phone, token, _, _ = await _patient_with_ride(client, db, RideStatus.completed)

    await _delete(client, token)

    again = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": phone,
            "password": PASSWORD,
            "role": "patient",
            "full_name": "New Me",
        },
    )
    assert again.status_code == 201, again.text


async def test_a_wrong_password_deletes_nothing(client, db):
    _, token, patient, _ = await _patient_with_ride(client, db, RideStatus.completed)

    out = await _delete(client, token, password="not-my-password")

    assert out.status_code == 403
    assert (await client.get(ME, headers=_auth(token))).status_code == 200
    await db.refresh(patient)
    assert patient.full_name == "Real Name"


async def test_an_active_ride_blocks_deletion(client, db):
    _, token, patient, ride = await _patient_with_ride(
        client, db, RideStatus.driver_en_route
    )

    out = await _delete(client, token)

    assert out.status_code == 409
    assert "active ride" in out.json()["detail"]
    assert (await client.get(ME, headers=_auth(token))).status_code == 200
    await db.refresh(patient)
    await db.refresh(ride)
    assert patient.full_name == "Real Name"
    assert ride.pickup_address == "House 5, Street 2, G-9"


async def test_deleting_needs_a_token(client):
    out = await client.post(DELETE, json={"password": PASSWORD})

    assert out.status_code == 401


async def test_deleting_a_driver_keeps_the_wallet_and_frees_the_licence(client, db):
    token = await _register(client, _phone(), "driver", **_driver_extra())
    user_id = await _user_id(client, token)
    await db.execute(
        update(Driver)
        .where(Driver.user_id == user_id)
        .values(
            wallet_balance_pkr=Decimal("750.00"),
            is_verified=True,
            current_lat=33.7,
            current_lng=73.0,
        )
    )
    await db.commit()
    before = (
        await db.execute(select(Driver).where(Driver.user_id == user_id))
    ).scalar_one()
    licence = before.license_no

    out = await _delete(client, token)

    assert out.status_code == 204, out.text
    await db.refresh(before)
    assert before.full_name == "Deleted driver"
    assert before.license_no != licence
    assert before.is_verified is False
    assert before.current_lat is None and before.current_lng is None
    assert before.wallet_balance_pkr == Decimal("750.00")  # money is never touched
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one()
    assert user.is_active is False
    assert user.phone.startswith("deleted-")


async def test_deleting_a_driver_gives_their_claimed_rides_back(client, db):
    token = await _register(client, _phone(), "driver", **_driver_extra())
    user_id = await _user_id(client, token)
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == user_id))
    ).scalar_one()
    patient_token = await _register(client, _phone(), "patient")
    patient = (
        await db.execute(
            select(Patient).where(
                Patient.user_id == await _user_id(client, patient_token)
            )
        )
    ).scalar_one()
    ride = Ride(
        patient_id=patient.id,
        ride_type=RideType.scheduled,
        status=RideStatus.pending,
        pickup_lat=33.72,
        pickup_lng=73.04,
        claimed_driver_id=driver.id,
    )
    db.add(ride)
    await db.commit()
    ride_id = ride.id

    out = await _delete(client, token)

    assert out.status_code == 204, out.text
    await db.refresh(ride)
    assert ride.id == ride_id and ride.claimed_driver_id is None
