"""WebSocket handler behaviour, driven with a fake socket.

(TestClient's own event loop conflicts with the asyncpg pool, so the handler
coroutines are called directly - same approach as test_websocket.py.)
"""

import asyncio
import json
import logging
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import WebSocketDisconnect
from redis.exceptions import ConnectionError as RedisConnectionError
from sqlalchemy.exc import OperationalError
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.models import Ride, RideStatus, UserRole, UserRoleLink
from app.routers import ws
from app.services.ws_manager import LocationManager
from tests.conftest import TEST_DATABASE_URL
from tests.test_websocket import _seed_driver_ride as _seed_users


async def _seed_driver_ride(db):
    """The shared seed helper plus the role links that `held_roles` reads."""
    seeded = await _seed_users(db)
    _, _, patient_user, driver_user, _, _ = seeded
    db.add(UserRoleLink(user_id=patient_user.id, role=UserRole.patient))
    db.add(UserRoleLink(user_id=driver_user.id, role=UserRole.driver))
    await db.commit()
    return seeded


HANG = object()  # a receive that never completes


class FakeWebSocket:
    """Just enough of starlette's WebSocket for the handlers."""

    def __init__(self, incoming, host="203.0.113.7"):
        self.client = SimpleNamespace(host=host)
        self._incoming = list(incoming)
        self.accepted = False
        self.closed_with: list[int] = []
        self.sent: list = []
        self.close_error: Exception | None = None

    async def accept(self):
        self.accepted = True

    async def close(self, code=1000):
        self.closed_with.append(code)
        if self.close_error:
            raise self.close_error

    async def _next(self):
        if not self._incoming:
            raise WebSocketDisconnect()
        item = self._incoming.pop(0)
        if callable(item):  # a side effect that happens between two frames
            await item()
            return await self._next()
        if item is HANG:
            await asyncio.sleep(3600)
        if isinstance(item, BaseException):
            raise item
        return item

    async def receive_text(self):
        return await self._next()

    async def receive_json(self):
        return json.loads(await self._next())

    async def send_json(self, data):
        self.sent.append(data)

    async def send_text(self, text):
        self.sent.append(text)


def _auth_msg(token: str) -> str:
    return json.dumps({"token": token})


def _frame(lat=33.72, lng=73.04) -> str:
    return json.dumps({"lat": lat, "lng": lng})


@pytest.fixture(autouse=True)
def _clean_counters():
    ws._open_sockets.clear()
    ws._preauth_sockets.clear()
    yield
    ws._open_sockets.clear()
    ws._preauth_sockets.clear()


@pytest.fixture
def fast_frames(monkeypatch):
    monkeypatch.setattr(ws, "_MIN_GPS_INTERVAL_SECONDS", 0)


@pytest.fixture
async def ws_factory(monkeypatch):
    """Point the handlers' own sessions at the test database."""
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    monkeypatch.setattr(ws, "AsyncSessionLocal", factory)
    yield factory
    await engine.dispose()


async def _drive(db, ws_factory, frames):
    ride, driver, pu, du, driver_token, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(driver_token), *frames])
    return ride, driver, du, fake


# ── driver stream ────────────────────────────────────────────────────────────


async def test_publish_failure_does_not_kill_the_gps_stream(
    db, ws_factory, fast_frames, caplog
):
    ride, _, du, fake = await _drive(db, ws_factory, [_frame(), _frame(33.73)])
    publish = AsyncMock(side_effect=[RedisConnectionError("blip"), None])

    with patch.object(ws.location_manager, "publish", publish):
        await ws.driver_location_ws(fake, str(ride.id))

    acks = [m for m in fake.sent if m.get("ack")]
    assert len(acks) == 2  # both frames acknowledged despite the first failure
    assert publish.await_count == 2
    assert fake.closed_with == []
    assert ws._open_sockets[du.id] == 0
    assert any("publish failed" in r.message for r in caplog.records)


async def test_db_writes_are_throttled_but_every_frame_is_published(
    db, ws_factory, fast_frames, monkeypatch
):
    monkeypatch.setattr(ws, "_GPS_PERSIST_INTERVAL_SECONDS", 3600)
    ride, driver, du, fake = await _drive(
        db, ws_factory, [_frame(33.1 + i / 100) for i in range(3)]
    )
    persist = AsyncMock(wraps=ws._persist_location)
    publish = AsyncMock()

    with (
        patch.object(ws, "_persist_location", persist),
        patch.object(ws.location_manager, "publish", publish),
    ):
        await ws.driver_location_ws(fake, str(ride.id))

    assert persist.await_count == 1
    assert publish.await_count == 3
    await db.refresh(driver)
    assert driver.current_lat == pytest.approx(33.1)  # only the first frame was saved


async def test_every_frame_is_saved_when_the_interval_is_zero(
    db, ws_factory, fast_frames, monkeypatch
):
    monkeypatch.setattr(ws, "_GPS_PERSIST_INTERVAL_SECONDS", 0)
    ride, driver, du, fake = await _drive(
        db, ws_factory, [_frame(33.1 + i / 100) for i in range(3)]
    )
    persist = AsyncMock(wraps=ws._persist_location)

    with (
        patch.object(ws, "_persist_location", persist),
        patch.object(ws.location_manager, "publish", AsyncMock()),
    ):
        await ws.driver_location_ws(fake, str(ride.id))

    assert persist.await_count == 3
    await db.refresh(driver)
    assert driver.current_lat == pytest.approx(33.12)


async def test_persisting_uses_a_single_session(db, ws_factory):
    ride, driver, *_ = await _seed_driver_ride(db)
    opened = MagicMock(wraps=ws.AsyncSessionLocal)

    with patch.object(ws, "AsyncSessionLocal", opened):
        assert await ws._persist_location(str(ride.id), driver.id, 33.5, 73.5) is True

    assert opened.call_count == 1


async def test_a_finished_ride_ends_the_socket_without_publishing(
    db, ws_factory, fast_frames
):
    ride, _, du, fake = await _drive(db, ws_factory, [_frame()])
    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.completed)
    )
    await db.commit()
    publish = AsyncMock()

    with patch.object(ws.location_manager, "publish", publish):
        await ws.driver_location_ws(fake, str(ride.id))

    assert {"event": "ride_ended"} in fake.sent
    assert fake.closed_with == [1000]
    publish.assert_not_awaited()
    assert ws._open_sockets[du.id] == 0


async def test_a_database_error_while_saving_keeps_the_stream_alive(
    db, ws_factory, caplog
):
    ride, driver, *_ = await _seed_driver_ride(db)
    broken = MagicMock(side_effect=OperationalError("select", {}, Exception("down")))

    with patch.object(ws, "AsyncSessionLocal", broken):
        still_active = await ws._persist_location(str(ride.id), driver.id, 33.5, 73.5)

    assert still_active is True
    assert any("GPS persist failed" in r.message for r in caplog.records)


async def test_bad_frames_earn_strikes_then_close(db, ws_factory, fast_frames):
    ride, _, du, fake = await _drive(db, ws_factory, ["not json"] * ws._MAX_STRIKES)

    await ws.driver_location_ws(fake, str(ride.id))

    assert fake.closed_with == [1008]
    assert ws._open_sockets[du.id] == 0


async def test_unexpected_error_is_logged_closed_with_1011_and_releases_the_slot(
    db, ws_factory, caplog
):
    ride, _, du, fake = await _drive(db, ws_factory, [_frame()])
    fake.close_error = RuntimeError("socket already gone")

    with patch.object(
        ws, "_stream_driver_gps", AsyncMock(side_effect=ValueError("boom"))
    ):
        await ws.driver_location_ws(fake, str(ride.id))  # must not raise

    assert fake.closed_with == [1011]
    assert ws._open_sockets[du.id] == 0
    assert str(ride.id) in caplog.text
    assert "ValueError: boom" in caplog.text


async def test_patient_token_cannot_open_the_driver_socket(db, ws_factory):
    ride, _, _, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token)])

    await ws.driver_location_ws(fake, str(ride.id))

    assert fake.closed_with == [1008]


# ── authentication failures ──────────────────────────────────────────────────


@pytest.mark.parametrize(
    "first_message,reason",
    [
        ("not json", "not valid JSON"),
        ("[1, 2]", "no token"),
        ('{"nope": 1}', "no token"),
        ('{"token": ""}', "no token"),
        ('{"token": 5}', "no token"),
        ('{"token": "garbage"}', "auth rejected"),
        (KeyError("text"), "not a text frame"),
        (WebSocketDisconnect(), "left before authenticating"),
        (HANG, "no first message"),
    ],
)
async def test_each_auth_failure_closes_with_1008_and_logs_its_reason(
    first_message, reason, monkeypatch, caplog
):
    monkeypatch.setattr(ws, "_AUTH_TIMEOUT_SECONDS", 0.05)
    caplog.set_level(logging.DEBUG, logger="smartride.ws")
    fake = FakeWebSocket([first_message])

    await ws.ride_tracking_ws(fake, "5f0c1e6c-2c6a-4f5e-9d3c-0e9c6f1d2a11")

    assert fake.accepted is True
    assert fake.closed_with == [1008]
    assert reason in caplog.text
    assert "garbage" not in caplog.text  # a token is never logged
    assert not ws._preauth_sockets


async def test_malformed_ride_id_is_rejected_after_accept():
    fake = FakeWebSocket([])

    await ws.driver_location_ws(fake, "not-a-uuid")

    assert fake.accepted and fake.closed_with == [1008]


async def test_preauth_cap_refuses_new_sockets_from_a_flooding_ip(monkeypatch):
    monkeypatch.setattr(ws, "_MAX_PREAUTH_PER_IP", 2)
    ws._preauth_sockets["198.51.100.9"] = 2
    fake = FakeWebSocket([], host="198.51.100.9")

    await ws.ride_tracking_ws(fake, "5f0c1e6c-2c6a-4f5e-9d3c-0e9c6f1d2a11")

    assert fake.accepted is False  # refused before the handshake completes
    assert fake.closed_with == [1008]
    assert ws._preauth_sockets["198.51.100.9"] == 2  # not counted, not released


async def test_preauth_slot_is_released_after_authentication(
    db, ws_factory, fast_frames
):
    ride, _, _, fake = await _drive(db, ws_factory, [])

    await ws.driver_location_ws(fake, str(ride.id))

    assert fake.accepted
    assert "203.0.113.7" not in ws._preauth_sockets


# ── patient stream ───────────────────────────────────────────────────────────


async def test_subscribe_failure_releases_the_socket_slot(db, ws_factory, caplog):
    ride, _, pu, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token)])
    subscribe = AsyncMock(side_effect=RedisConnectionError("down"))

    with patch.object(ws.location_manager, "subscribe", subscribe):
        await ws.ride_tracking_ws(fake, str(ride.id))

    assert fake.closed_with == [1011]
    assert ws._open_sockets[pu.id] == 0
    assert str(ride.id) in caplog.text


async def test_failing_pubsub_cleanup_does_not_mask_the_stream_or_leak(db, ws_factory):
    ride, _, pu, _, _, patient_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(patient_token)])
    pubsub = MagicMock()
    pubsub.get_message = AsyncMock(side_effect=[None, WebSocketDisconnect()])
    pubsub.unsubscribe = AsyncMock(side_effect=RedisConnectionError("gone"))
    pubsub.aclose = AsyncMock()

    with patch.object(ws.location_manager, "subscribe", AsyncMock(return_value=pubsub)):
        await ws.ride_tracking_ws(fake, str(ride.id))

    assert {"event": "ping"} in fake.sent
    pubsub.aclose.assert_awaited_once()  # still closed after unsubscribe failed
    assert ws._open_sockets[pu.id] == 0


async def test_stranger_cannot_watch_a_ride(db, ws_factory):
    ride, *_ = await _seed_driver_ride(db)
    _, _, _, _, _, stranger_token = await _seed_driver_ride(db)
    fake = FakeWebSocket([_auth_msg(stranger_token)])

    await ws.ride_tracking_ws(fake, str(ride.id))

    assert fake.closed_with == [1008]


# ── LocationManager ──────────────────────────────────────────────────────────


async def test_publish_gives_up_instead_of_hanging(monkeypatch):
    monkeypatch.setattr("app.services.ws_manager.REDIS_OP_TIMEOUT_SECONDS", 0.05)
    mgr = LocationManager()
    slow = MagicMock()
    slow.publish = lambda *a: asyncio.sleep(3600)
    mgr._redis = slow

    with pytest.raises(asyncio.TimeoutError):
        await mgr.publish("r", 1.0, 2.0)


async def test_failed_subscribe_closes_the_half_open_pubsub():
    mgr = LocationManager()
    pubsub = AsyncMock()
    pubsub.subscribe.side_effect = RedisConnectionError("down")
    redis = MagicMock()
    redis.pubsub = MagicMock(return_value=pubsub)
    mgr._redis = redis

    with pytest.raises(RedisConnectionError):
        await mgr.subscribe("r")

    pubsub.aclose.assert_awaited_once()


# ── ownership and relay cost ─────────────────────────────────────────────────


async def test_a_driver_who_no_longer_owns_the_ride_is_told_it_ended(db, ws_factory):
    ride, driver, *_ = await _seed_driver_ride(db)
    assert await ws._persist_location(str(ride.id), driver.id, 33.5, 73.5) is True

    await db.execute(update(Ride).where(Ride.id == ride.id).values(driver_id=None))
    await db.commit()

    assert await ws._persist_location(str(ride.id), driver.id, 33.5, 73.5) is False


async def test_a_reassigned_ride_ends_the_old_drivers_socket(
    db, ws_factory, fast_frames, monkeypatch
):
    monkeypatch.setattr(ws, "_GPS_PERSIST_INTERVAL_SECONDS", 0)
    ride_id = None

    async def another_driver_takes_the_ride():
        await db.execute(update(Ride).where(Ride.id == ride_id).values(driver_id=None))
        await db.commit()

    ride, _, du, fake = await _drive(db, ws_factory, [])
    ride_id = ride.id
    fake._incoming += [_frame(), another_driver_takes_the_ride, _frame(33.73)]
    publish = AsyncMock()

    with patch.object(ws.location_manager, "publish", publish):
        await ws.driver_location_ws(fake, str(ride.id))

    assert {"event": "ride_ended"} in fake.sent
    assert publish.await_count == 1  # only the frame sent while they still owned it


class _ScriptedPubSub:
    """get_message returns the scripted items, then raises to stop the relay."""

    def __init__(self, items):
        self._items = list(items)

    async def get_message(self, **_kwargs):
        if not self._items:
            raise asyncio.CancelledError()
        return self._items.pop(0)


async def test_relay_does_not_query_the_database_for_every_gps_frame(
    db, ws_factory, monkeypatch
):
    ride, *_ = await _seed_driver_ride(db)
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 3600.0)
    opened = MagicMock(wraps=ws.AsyncSessionLocal)
    frames = [{"data": '{"lat": 1, "lng": 2}'}] * 6
    fake = FakeWebSocket([])

    with patch.object(ws, "AsyncSessionLocal", opened):
        with pytest.raises(asyncio.CancelledError):
            await ws._relay_location(
                fake, str(ride.id), _ScriptedPubSub(frames), ws_token_for_tests()
            )

    assert len(fake.sent) == 6
    assert opened.call_count == 1  # the first check only


async def test_relay_still_ends_when_the_ride_finishes_while_quiet(
    db, ws_factory, monkeypatch
):
    ride, *_ = await _seed_driver_ride(db)
    monkeypatch.setattr(ws, "_STATUS_RECHECK_SECONDS", 3600.0)
    fake = FakeWebSocket([])
    pubsub = _ScriptedPubSub([{"data": "x"}, None])

    with pytest.raises(asyncio.CancelledError):
        await ws._relay_location(fake, str(ride.id), pubsub, ws_token_for_tests())
    assert {"event": "ping"} in fake.sent  # quiet, ride still live

    await db.execute(
        update(Ride).where(Ride.id == ride.id).values(status=RideStatus.completed)
    )
    await db.commit()
    fake = FakeWebSocket([])

    await ws._relay_location(
        fake, str(ride.id), _ScriptedPubSub([None]), ws_token_for_tests()
    )

    assert fake.sent[0]["event"] == "ride_ended"


def ws_token_for_tests() -> str:
    from app.core.security import create_access_token

    return create_access_token({"sub": "x"})
