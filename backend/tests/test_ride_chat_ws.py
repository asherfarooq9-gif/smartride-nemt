# ruff: noqa: F811  (fixtures imported from test_ws_handlers are used by name)
"""Live delivery of chat messages over the ride chat socket.

Same approach as test_ws_handlers.py: the handler coroutines are called directly
with a fake socket, because TestClient's event loop clashes with the asyncpg pool.
"""

import asyncio
import json
from unittest.mock import AsyncMock, patch

import pytest
from redis.exceptions import ConnectionError as RedisConnectionError
from sqlalchemy import update

from app.models.models import Ride, RideStatus
from app.routers import ws
from tests.test_ride_chat import _list, _post
from tests.test_ride_lifecycle import _assigned_ride, _phone
from tests.test_ws_handlers import (  # noqa: F401  (fixtures)
    FakeWebSocket,
    _ScriptedPubSub,
    _auth_msg,
    _clean_counters,
    _seed_driver_ride,
    ws_factory,
    ws_token_for_tests,
)


class _ClosablePubSub(_ScriptedPubSub):
    """The scripted pubsub plus the clean-up calls the handler makes when it ends."""

    async def unsubscribe(self):
        pass

    async def aclose(self):
        pass


MESSAGE = json.dumps(
    {"id": 1, "ride_id": "r", "sender": "patient", "body": "hi", "created_at": "t"}
)


async def test_a_participant_receives_published_messages(db, ws_factory):
    ride, _, _, _, driver_token, patient_token = await _seed_driver_ride(db)
    for token in (patient_token, driver_token):
        fake = FakeWebSocket([_auth_msg(token)])
        pubsub = _ClosablePubSub([{"data": MESSAGE}])

        with patch.object(
            ws.location_manager, "subscribe_chat", AsyncMock(return_value=pubsub)
        ):
            with pytest.raises(asyncio.CancelledError):
                await ws.ride_chat_ws(fake, str(ride.id))

        assert MESSAGE in fake.sent


async def test_a_stranger_cannot_listen_to_the_chat(db, ws_factory):
    ride, *_ = await _seed_driver_ride(db)
    _, _, _, _, stranger_driver_token, stranger_patient_token = await _seed_driver_ride(
        db
    )
    for token in (stranger_driver_token, stranger_patient_token):
        fake = FakeWebSocket([_auth_msg(token)])

        await ws.ride_chat_ws(fake, str(ride.id))

        assert fake.closed_with == [1008]
        assert fake.sent == []


async def test_nobody_can_listen_to_a_chat_that_is_closed(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.completed)
    )
    await db.commit()
    fake = FakeWebSocket([_auth_msg(patient_token)])

    await ws.ride_chat_ws(fake, str(ride.id))

    assert fake.closed_with == [1008]


async def test_the_socket_says_chat_closed_when_the_ride_ends(
    db, ws_factory, monkeypatch
):
    ride, _, patient_user, *_ = await _seed_driver_ride(db)
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 3600.0)
    token = ws_token_for_tests()
    fake = FakeWebSocket([])
    with pytest.raises(asyncio.CancelledError):
        await ws._relay_chat(fake, str(ride.id), _ScriptedPubSub([None]), token)
    assert {"event": "ping"} in fake.sent  # quiet, chat still open

    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.completed)
    )
    await db.commit()
    fake = FakeWebSocket([])

    await ws._relay_chat(fake, str(ride.id), _ScriptedPubSub([None]), token)

    assert fake.sent[0] == {"event": "chat_closed"}


async def test_the_socket_closes_when_the_driver_gives_the_ride_back(
    db, ws_factory, monkeypatch
):
    ride, *_ = await _seed_driver_ride(db)
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 3600.0)
    await db.execute(
        update(Ride)
        .where(Ride.id == ride.id)
        .values(status=RideStatus.pending, driver_id=None)
    )
    await db.commit()
    fake = FakeWebSocket([])

    await ws._relay_chat(
        fake, str(ride.id), _ScriptedPubSub([None]), ws_token_for_tests()
    )

    assert fake.sent[0] == {"event": "chat_closed"}


async def test_a_revoked_token_stops_the_chat_socket(db, ws_factory, monkeypatch):
    from tests.test_ws_handlers import _block

    ride, *_ = await _seed_driver_ride(db)
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 0)
    token = ws_token_for_tests()
    await _block(token)
    fake = FakeWebSocket([])

    await ws._relay_chat(
        fake, str(ride.id), _ScriptedPubSub([{"data": MESSAGE}]), token
    )

    assert fake.closed_with == [1008]
    assert fake.sent == []


async def test_sending_publishes_the_message_to_the_ride_channel(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    publish = AsyncMock()

    with patch.object(ws.location_manager, "publish_chat", publish):
        r = await _post(client, patient_token, ride_id, "hello driver")

    assert r.status_code == 201
    publish.assert_awaited_once()
    sent_ride_id, payload = publish.await_args.args
    assert sent_ride_id == ride_id
    assert payload["sender"] == "patient"
    assert payload["body"] == "hello driver"
    assert payload["id"] == r.json()["id"]


async def test_a_redis_outage_does_not_stop_a_message_being_saved(
    client, verified_driver_token
):
    """The other side still gets it from the next fetch and the push."""
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    broken = AsyncMock(side_effect=RedisConnectionError("down"))

    with patch.object(ws.location_manager, "publish_chat", broken):
        r = await _post(client, patient_token, ride_id, "still saved")

    assert r.status_code == 201
    seen = (await _list(client, verified_driver_token, ride_id)).json()["items"]
    assert [m["body"] for m in seen] == ["still saved"]
