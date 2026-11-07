"""Who is told when a ride is cancelled or handed back after a hospital pre-alert."""

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from sqlalchemy import select, update

from app.models.models import Driver, Hospital, Ride, RideStatus, Specialty
from app.services import dispatch_loop, notifications
from tests.test_ride_lifecycle import _assigned_ride, _auth, _set_ride_status, _phone

HOSPITAL_PHONE = "+923005550100"


async def _attach_hospital(db, ride_id) -> uuid.UUID:
    hospital = Hospital(
        name="Stop Test Hospital",
        address="A",
        city="Islamabad",
        lat=33.76,
        lng=73.04,
        specialties=[s.value for s in Specialty],
        ed_capacity=100,
        coordinator_phone=HOSPITAL_PHONE,
    )
    db.add(hospital)
    await db.flush()
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(hospital_id=hospital.id)
    )
    await db.commit()
    return hospital.id


async def _driver_user_id(db, token_client, token) -> uuid.UUID:
    me = await token_client.get("/api/v1/drivers/me", headers=_auth(token))
    driver_id = me.json()["id"]
    return (
        await db.execute(select(Driver.user_id).where(Driver.id == driver_id))
    ).scalar_one()


async def test_patient_cancel_tells_the_driver_and_the_hospital(
    client, db, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    hospital_id = await _attach_hospital(db, ride_id)
    driver_user_id = await _driver_user_id(db, client, verified_driver_token)

    with (
        patch("app.services.ride_service.notify_user", new=AsyncMock()) as push,
        patch(
            "app.services.ride_service.tell_hospital_ride_stopped", new=AsyncMock()
        ) as alert,
    ):
        r = await _set_ride_status(client, patient_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    pushed_users = [c.kwargs.get("user_id") for c in push.await_args_list]
    assert driver_user_id in pushed_users
    alert.assert_awaited_once()
    assert alert.await_args.kwargs["hospital_id"] == hospital_id
    assert str(alert.await_args.kwargs["ride_id"]) == str(ride_id)


async def test_driver_handing_the_ride_back_tells_the_hospital_not_the_driver(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    hospital_id = await _attach_hospital(db, ride_id)
    driver_user_id = await _driver_user_id(db, client, verified_driver_token)

    with (
        patch("app.services.ride_service.notify_user", new=AsyncMock()) as push,
        patch(
            "app.services.ride_service.tell_hospital_ride_stopped", new=AsyncMock()
        ) as alert,
    ):
        r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "pending"
    assert driver_user_id not in [c.kwargs.get("user_id") for c in push.await_args_list]
    alert.assert_awaited_once()
    assert alert.await_args.kwargs["hospital_id"] == hospital_id


async def test_a_failed_notification_never_fails_the_cancel(
    client, db, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _attach_hospital(db, ride_id)

    with patch(
        "app.services.ride_service.tell_hospital_ride_stopped",
        new=AsyncMock(side_effect=RuntimeError("sms provider down")),
    ):
        r = await _set_ride_status(client, patient_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"


async def test_cancelling_before_any_assignment_tells_nobody(client):
    from tests.test_dispatch_endpoints import _create_emergency, _register

    patient_token = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient_token)

    with (
        patch("app.services.ride_service.notify_user", new=AsyncMock()) as push,
        patch(
            "app.services.ride_service.tell_hospital_ride_stopped", new=AsyncMock()
        ) as alert,
    ):
        await _set_ride_status(client, patient_token, ride_id, "cancelled")

    alert.assert_not_awaited()
    assert all(c.kwargs.get("user_id") is None for c in push.await_args_list)


async def test_unacknowledged_requeue_tells_the_hospital(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    hospital_id = await _attach_hospital(db, ride_id)
    long_ago = datetime.now(timezone.utc) - timedelta(hours=1)
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(driver_assigned_at=long_ago)
    )
    await db.commit()

    with (
        patch("app.services.dispatch_loop.notify_user", new=AsyncMock()),
        patch(
            "app.services.dispatch_loop.tell_hospital_ride_stopped", new=AsyncMock()
        ) as alert,
    ):
        await dispatch_loop._requeue_unacknowledged(db, datetime.now(timezone.utc))

    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    assert ride.status == RideStatus.pending
    # The loop is global, so other tests' stale rides may be requeued too.
    assert hospital_id in [c.kwargs["hospital_id"] for c in alert.await_args_list]


async def test_hospital_is_sent_an_sms_that_the_ride_stopped(db):
    hospital = Hospital(
        name="SMS Test Hospital",
        address="A",
        city="Islamabad",
        lat=33.7,
        lng=73.0,
        specialties=["cardiology"],
        ed_capacity=10,
        coordinator_phone=HOSPITAL_PHONE,
    )
    db.add(hospital)
    await db.commit()
    sent = []

    with patch.object(
        notifications, "_send_sms", lambda to, body: sent.append((to, body)) or True
    ):
        told = await notifications.tell_hospital_ride_stopped(
            db, ride_id="ride-7", hospital_id=hospital.id
        )

    assert told is True
    assert sent[0][0] == HOSPITAL_PHONE
    assert "ride-7" in sent[0][1]
    assert "disregard" in sent[0][1].lower()


async def test_telling_a_hospital_without_a_phone_reports_failure(db):
    hospital = Hospital(
        name="No Phone Hospital",
        address="A",
        city="Islamabad",
        lat=33.7,
        lng=73.0,
        specialties=["cardiology"],
        ed_capacity=10,
        coordinator_phone=None,
    )
    db.add(hospital)
    await db.commit()

    told = await notifications.tell_hospital_ride_stopped(
        db, ride_id="ride-8", hospital_id=hospital.id
    )

    assert told is False


async def test_telling_an_unknown_hospital_never_raises(db):
    told = await notifications.tell_hospital_ride_stopped(
        db, ride_id="ride-9", hospital_id=uuid.uuid4()
    )

    assert told is False
