"""In-ride chat between the patient and the driver who accepted the ride.

Rules under test: only those two people can read or write; chat exists only while
the ride is live with a driver on it; messages are deleted the moment the ride
ends (or the driver gives it up), so nothing a patient said about their health
outlives the trip.
"""

import uuid

from sqlalchemy import func, select

from app.models.models import RideMessage
from tests.test_dispatch_endpoints import _register
from tests.test_ride_lifecycle import (
    _assigned_ride,
    _auth,
    _phone,
    _set_ride_status,
)


async def _post(client, token, ride_id, body):
    return await client.post(
        f"/api/v1/rides/{ride_id}/messages",
        json={"body": body},
        headers=_auth(token),
    )


async def _list(client, token, ride_id, after_id=None):
    params = {} if after_id is None else {"after_id": after_id}
    return await client.get(
        f"/api/v1/rides/{ride_id}/messages", params=params, headers=_auth(token)
    )


async def _count(db, ride_id) -> int:
    return (
        await db.execute(
            select(func.count())
            .select_from(RideMessage)
            .where(RideMessage.ride_id == uuid.UUID(ride_id))
        )
    ).scalar_one()


async def test_patient_and_driver_see_each_others_messages_in_order(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    first = await _post(client, patient_token, ride_id, "I am at the blue gate")
    second = await _post(client, verified_driver_token, ride_id, "Two minutes away")

    assert first.status_code == 201, first.text
    assert second.status_code == 201, second.text
    assert first.json()["sender"] == "patient"
    assert second.json()["sender"] == "driver"
    for token in (patient_token, verified_driver_token):
        seen = (await _list(client, token, ride_id)).json()["items"]
        assert [(m["sender"], m["body"]) for m in seen] == [
            ("patient", "I am at the blue gate"),
            ("driver", "Two minutes away"),
        ]


async def test_after_id_returns_only_newer_messages(client, verified_driver_token):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    one = (await _post(client, patient_token, ride_id, "one")).json()
    await _post(client, patient_token, ride_id, "two")

    newer = (await _list(client, verified_driver_token, ride_id, one["id"])).json()

    assert [m["body"] for m in newer["items"]] == ["two"]


async def test_after_id_outside_the_database_range_is_a_422_not_a_crash(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    for bad in (-1, 2**63, 10**30):
        r = await _list(client, patient_token, ride_id, bad)
        assert r.status_code == 422, bad


async def test_message_text_is_trimmed_and_kept_as_plain_text(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    r = await _post(client, patient_token, ride_id, "  <b>hi</b> & bye  ")

    assert r.status_code == 201
    assert r.json()["body"] == "<b>hi</b> & bye"


async def test_empty_and_overlong_messages_are_rejected(
    client, db, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    assert (await _post(client, patient_token, ride_id, "")).status_code == 422
    assert (await _post(client, patient_token, ride_id, "   \n ")).status_code == 422
    assert (await _post(client, patient_token, ride_id, "x" * 501)).status_code == 422
    assert (await _post(client, patient_token, ride_id, "x" * 500)).status_code == 201
    assert await _count(db, ride_id) == 1


async def test_a_stranger_can_neither_read_nor_write(client, verified_driver_token):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _post(client, patient_token, ride_id, "private")
    other_patient = await _register(client, _phone(), "patient")
    uid = uuid.uuid4().hex[:8]
    other_driver = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"ST-{uid}",
        vehicle_plate=f"ST-{uid[:6]}",
        vehicle_type="sedan",
    )

    for token in (other_patient, other_driver):
        assert (await _list(client, token, ride_id)).status_code == 403
        assert (await _post(client, token, ride_id, "hello")).status_code == 403


async def test_an_admin_cannot_read_a_private_chat(
    client, admin_token, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    assert (await _list(client, admin_token, ride_id)).status_code == 403


async def test_no_token_is_rejected(client, verified_driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    r = await client.get(f"/api/v1/rides/{ride_id}/messages")

    assert r.status_code in (401, 403)


async def test_chat_is_closed_until_a_driver_has_the_ride(client):
    patient_token = await _register(client, _phone(), "patient")
    from tests.test_dispatch_endpoints import _create_emergency

    ride_id = await _create_emergency(client, patient_token)  # dispatch is stubbed

    # Still pending: nobody to talk to, so both calls say the chat is not open.
    assert (await _post(client, patient_token, ride_id, "hello")).status_code == 409
    assert (await _list(client, patient_token, ride_id)).status_code == 409


async def test_unknown_ride_is_404(client, verified_driver_token):
    r = await _list(client, verified_driver_token, str(uuid.uuid4()))

    assert r.status_code == 404


async def test_completing_the_ride_deletes_the_chat_at_once(
    client, db, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _post(client, patient_token, ride_id, "my chest hurts")
    await _post(client, verified_driver_token, ride_id, "on my way")
    assert await _count(db, ride_id) == 2

    for step in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_ride_status(client, verified_driver_token, ride_id, step)
        assert r.status_code == 200, r.text

    assert await _count(db, ride_id) == 0
    assert (await _list(client, patient_token, ride_id)).status_code == 409
    assert (await _post(client, patient_token, ride_id, "thanks")).status_code == 409


async def test_cancelling_the_ride_deletes_the_chat(client, db, verified_driver_token):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _post(client, patient_token, ride_id, "never mind")

    r = await _set_ride_status(client, patient_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert await _count(db, ride_id) == 0


async def test_a_driver_giving_the_ride_back_deletes_the_chat(
    client, db, verified_driver_token
):
    """The next driver must not inherit what was said to the first one."""
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _post(client, patient_token, ride_id, "I use a wheelchair")

    r = await _set_ride_status(client, verified_driver_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert await _count(db, ride_id) == 0


async def test_the_sweep_removes_chats_left_on_ended_rides(
    client, db, verified_driver_token
):
    """Safety net for any path that ends a ride without going through the status
    update (an admin database fix, a future code path)."""
    from app.services import chat_service

    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _post(client, patient_token, ride_id, "left behind")
    from app.models.models import Ride, RideStatus

    ride = (
        await db.execute(select(Ride).where(Ride.id == uuid.UUID(ride_id)))
    ).scalar_one()
    ride.status = RideStatus.completed
    await db.commit()
    assert await _count(db, ride_id) == 1

    removed = await chat_service.purge_ended_ride_messages(db)

    assert removed >= 1
    assert await _count(db, ride_id) == 0
