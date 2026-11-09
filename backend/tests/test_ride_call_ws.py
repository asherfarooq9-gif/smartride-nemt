# ruff: noqa: F811  (fixtures imported from test_ws_handlers are used by name)
"""Call set-up messages between the patient and the driver, over the call socket.

Driven with a fake socket, like test_ws_handlers.py (TestClient's event loop
clashes with the asyncpg pool).
"""

import asyncio
import json
from unittest.mock import AsyncMock, patch

from sqlalchemy import update

from app.models.models import Ride, RideStatus
from app.routers import ws
from tests.test_ws_handlers import (  # noqa: F401  (fixtures)
    HANG,
    FakeWebSocket,
    _auth_msg,
    _clean_counters,
    _seed_driver_ride,
    ws_factory,
    ws_token_for_tests,
)


class _IdlePubSub:
    """Nothing ever arrives from the other side; clean-up calls are harmless."""

    async def get_message(self, **_kwargs):
        await asyncio.sleep(3600)

    async def unsubscribe(self):
        pass

    async def aclose(self):
        pass


class _ScriptedPubSub(_IdlePubSub):
    """Delivers the given messages, then goes idle."""

    def __init__(self, items):
        self._items = list(items)

    async def get_message(self, **_kwargs):
        if self._items:
            return self._items.pop(0)
        await asyncio.sleep(3600)


def _frame(**fields) -> str:
    return json.dumps(fields)


async def _run(fake, ride_id, pubsub=None, receivers=1):
    """Run the call socket with the Redis side replaced; returns the publish mock."""
    publish = AsyncMock(return_value=receivers)
    with (
        patch.object(ws.location_manager, "publish_call", publish),
        patch.object(
            ws.location_manager,
            "subscribe_call",
            AsyncMock(return_value=pubsub or _IdlePubSub()),
        ),
    ):
        await asyncio.wait_for(ws.ride_call_ws(fake, str(ride_id)), timeout=10)
    return publish


async def test_a_signal_goes_to_the_other_person_and_names_the_sender(db, ws_factory):
    ride, _, _, _, driver_token, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket(
        [
            _auth_msg(patient_token),
            _frame(type="offer", sdp="v=0"),
            _frame(type="hangup", **{"from": "driver"}),  # a lie about who it is
        ]
    )

    publish = await _run(fake, ride.id)

    calls = [c.args for c in publish.await_args_list]
    assert calls == [
        (str(ride.id), "driver", {"type": "offer", "sdp": "v=0", "from": "patient"}),
        (str(ride.id), "driver", {"type": "hangup", "from": "patient"}),
    ]


async def test_the_driver_signals_the_patient(db, ws_factory):
    ride, _, _, _, driver_token, _ = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(driver_token), _frame(type="accept")])

    publish = await _run(fake, ride.id)

    assert publish.await_args_list[0].args == (
        str(ride.id),
        "patient",
        {"type": "accept", "from": "driver"},
    )


async def test_messages_from_the_other_person_reach_the_socket(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    incoming = json.dumps({"type": "offer", "sdp": "v=0", "from": "driver"})
    fake = FakeWebSocket([])

    # the fake socket cannot wait, so drive the relay half directly
    pubsub = _ScriptedPubSub([{"data": incoming}])
    task = asyncio.create_task(
        ws._relay_chat(fake, str(ride.id), pubsub, ws_token_for_tests())
    )
    for _ in range(100):  # give the two database checks time to run
        if fake.sent:
            break
        await asyncio.sleep(0.05)
    task.cancel()
    await asyncio.gather(task, return_exceptions=True)

    assert incoming in fake.sent


async def test_ringing_nobody_sends_a_push_and_tells_the_caller(db, ws_factory):
    ride, _, _, driver_user, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token), _frame(type="invite")])

    with patch("app.services.call_service.notify_user", AsyncMock()) as push:
        await _run(fake, ride.id, receivers=0)

    assert {"event": "unreachable"} in fake.sent
    push.assert_awaited_once()
    assert push.await_args.kwargs["user_id"] == driver_user.id
    assert "Open SmartRide" in push.await_args.kwargs["body"]


async def test_ringing_an_open_app_sends_no_push(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token), _frame(type="invite")])

    with patch("app.services.call_service.notify_user", AsyncMock()) as push:
        await _run(fake, ride.id, receivers=1)

    push.assert_not_awaited()
    assert {"event": "unreachable"} not in fake.sent


async def test_a_redis_outage_while_ringing_reads_as_unreachable(db, ws_factory):
    from redis.exceptions import ConnectionError as RedisConnectionError

    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token), _frame(type="invite")])
    broken = AsyncMock(side_effect=RedisConnectionError("down"))

    with (
        patch.object(ws.location_manager, "publish_call", broken),
        patch.object(
            ws.location_manager,
            "subscribe_call",
            AsyncMock(return_value=_IdlePubSub()),
        ),
        patch("app.services.call_service.notify_user", AsyncMock()),
    ):
        await asyncio.wait_for(ws.ride_call_ws(fake, str(ride.id)), timeout=10)

    assert {"event": "unreachable"} in fake.sent


async def test_bad_messages_are_refused_and_never_passed_on(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket(
        [
            _auth_msg(patient_token),
            _frame(type="shout"),
            "not json at all",
            _frame(type="offer", sdp="x" * 30_000),
            _frame(type="ice", candidate="nope"),
        ]
    )

    publish = await _run(fake, ride.id)

    publish.assert_not_awaited()
    assert fake.sent.count({"error": "invalid call message"}) == 4


async def test_a_flood_of_bad_messages_closes_the_socket(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket(
        [_auth_msg(patient_token)] + [_frame(type="shout")] * (ws._MAX_STRIKES + 5)
    )

    await _run(fake, ride.id)

    assert fake.closed_with == [1008]


async def test_too_many_messages_in_a_moment_is_a_flood(db, ws_factory, monkeypatch):
    monkeypatch.setattr(ws, "_CALL_MAX_FRAMES_PER_WINDOW", 5)
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token)] + [_frame(type="hangup")] * 8)

    publish = await _run(fake, ride.id)

    assert publish.await_count == 5
    assert {"error": "too many call messages"} in fake.sent


async def test_a_stranger_cannot_use_the_call_socket(db, ws_factory):
    ride, *_ = await _seed_driver_ride(db)
    _, _, _, _, stranger_driver, stranger_patient = await _seed_driver_ride(db)
    for token in (stranger_driver, stranger_patient):
        fake = FakeWebSocket([_auth_msg(token)])

        await _run(fake, ride.id)

        assert fake.closed_with == [1008]


async def test_nobody_can_call_once_the_ride_is_over(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.completed)
    )
    await db.commit()
    fake = FakeWebSocket([_auth_msg(patient_token)])

    await _run(fake, ride.id)

    assert fake.closed_with == [1008]


async def test_the_call_socket_closes_when_the_ride_ends(db, ws_factory, monkeypatch):
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 0)
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)

    class _EndsTheRide(_IdlePubSub):
        async def get_message(self, **_kwargs):
            await db.execute(
                update(Ride)
                .where(Ride.id == ride.id)
                .values(status=RideStatus.cancelled)
            )
            await db.commit()
            return None  # a quiet moment: the relay re-checks the ride

    fake = FakeWebSocket([_auth_msg(patient_token), HANG])
    with (
        patch.object(ws.location_manager, "publish_call", AsyncMock()),
        patch.object(
            ws.location_manager,
            "subscribe_call",
            AsyncMock(return_value=_EndsTheRide()),
        ),
    ):
        await asyncio.wait_for(ws.ride_call_ws(fake, str(ride.id)), timeout=10)

    assert {"event": "call_closed"} in fake.sent
