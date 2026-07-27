"""WebSocket endpoint behaviour: auth, ride ownership, coordinate validation
and stream teardown.

test_websocket.py covers the helpers in isolation but never enters either
handler, because Starlette's TestClient spins up its own event loop and clashes
with the asyncpg pool. Here the handlers are awaited directly with a stub
WebSocket, which exercises the real authorisation and streaming logic without
that conflict.
"""

import json
import os
import uuid

import pytest
import pytest_asyncio
from fastapi import WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool
from unittest.mock import AsyncMock, patch

from app.core.security import create_access_token, hash_password
from app.models.models import (
    Driver,
    DriverStatus,
    Patient,
    Ride,
    RideStatus,
    RideType,
    User,
    UserRole,
    UserRoleLink,
)
from app.routers import ws as ws_module
from app.routers.ws import (
    _receive_auth,
    _valid_coords,
    driver_location_ws,
    ride_tracking_ws,
)

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test",
)


class StubWebSocket:
    """Minimal stand-in for starlette's WebSocket.

    Yields queued client frames, then raises WebSocketDisconnect the way a real
    client hanging up would, so the handler's disconnect path is exercised.
    """

    def __init__(self, incoming=None):
        self._incoming = list(incoming or [])
        self.sent: list = []
        self.closed_code: int | None = None
        self.accepted = False

    async def accept(self):
        self.accepted = True

    def _next(self):
        if not self._incoming:
            raise WebSocketDisconnect(1000)
        return self._incoming.pop(0)

    async def receive_text(self) -> str:
        item = self._next()
        return item if isinstance(item, str) else json.dumps(item)

    async def receive_json(self):
        item = self._next()
        return json.loads(item) if isinstance(item, str) else item

    async def send_json(self, data):
        self.sent.append(data)

    async def send_text(self, data):
        self.sent.append(data)

    async def close(self, code: int | None = None):
        self.closed_code = code


class StubPubSub:
    def __init__(self, messages):
        self._messages = list(messages)
        self.unsubscribed = False
        self.closed = False

    async def listen(self):
        for message in self._messages:
            yield message

    async def unsubscribe(self):
        self.unsubscribed = True

    async def aclose(self):
        self.closed = True


@pytest_asyncio.fixture
async def ws_db():
    engine = create_async_engine(TEST_DATABASE_URL, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
        try:
            await session.rollback()
        except Exception:
            pass
    await engine.dispose()


@pytest.fixture
def use_test_db():
    """Point the handlers' AsyncSessionLocal at the test database."""
    factory = async_sessionmaker(
        create_async_engine(TEST_DATABASE_URL, poolclass=NullPool),
        class_=AsyncSession,
        expire_on_commit=False,
    )
    with patch.object(ws_module, "AsyncSessionLocal", factory):
        yield


async def _make_user(session: AsyncSession, role: UserRole) -> User:
    user = User(
        phone=f"+92300{str(uuid.uuid4().int)[:7]}",
        password_hash=hash_password("x"),
        role=role,
    )
    session.add(user)
    await session.flush()
    session.add(UserRoleLink(user_id=user.id, role=role))
    await session.flush()
    return user


def _token(user: User) -> str:
    return create_access_token(
        {
            "sub": str(user.id),
            "role": user.role.value,
            "roles": [user.role.value],
            "active_role": user.role.value,
        }
    )


@pytest_asyncio.fixture
async def scenario(ws_db: AsyncSession):
    """A driver-assigned ride with its patient, driver and an admin."""
    suffix = uuid.uuid4().hex[:8]

    patient_user = await _make_user(ws_db, UserRole.patient)
    patient = Patient(user_id=patient_user.id, full_name="WS Patient")
    ws_db.add(patient)

    driver_user = await _make_user(ws_db, UserRole.driver)
    driver = Driver(
        user_id=driver_user.id,
        full_name="WS Driver",
        license_no=f"WSE-{suffix}",
        vehicle_plate=f"WSE-{suffix[:4]}",
        vehicle_type="ambulette",
        is_verified=True,
        status=DriverStatus.busy,
    )
    ws_db.add(driver)

    admin_user = await _make_user(ws_db, UserRole.admin)
    await ws_db.flush()

    ride = Ride(
        patient_id=patient.id,
        driver_id=driver.id,
        ride_type=RideType.emergency,
        status=RideStatus.driver_assigned,
        pickup_lat=33.7215,
        pickup_lng=73.0433,
    )
    ws_db.add(ride)
    await ws_db.commit()
    for obj in (ride, driver, patient, patient_user, driver_user, admin_user):
        await ws_db.refresh(obj)

    return {
        "ride": ride,
        "driver": driver,
        "patient": patient,
        "patient_token": _token(patient_user),
        "driver_token": _token(driver_user),
        "admin_token": _token(admin_user),
    }


# ── helpers ──────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_receive_auth_returns_none_on_malformed_json():
    assert await _receive_auth(StubWebSocket(["not json at all"])) is None


@pytest.mark.asyncio
async def test_receive_auth_returns_none_when_client_says_nothing():
    assert await _receive_auth(StubWebSocket([])) is None


@pytest.mark.asyncio
async def test_receive_auth_extracts_the_token():
    assert await _receive_auth(StubWebSocket([{"token": "abc"}])) == "abc"


@pytest.mark.parametrize(
    "lat,lng,expected",
    [
        (33.7, 73.0, True),
        (90, 180, True),
        (-90, -180, True),
        (91, 0, False),
        (0, 181, False),
        (-91, 0, False),
    ],
)
def test_valid_coords_bounds(lat, lng, expected):
    assert _valid_coords(lat, lng) is expected


# ── driver GPS stream ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_driver_ws_closes_without_a_token(use_test_db):
    socket = StubWebSocket([])
    await driver_location_ws(socket, str(uuid.uuid4()))
    assert socket.accepted
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_driver_ws_closes_on_invalid_token(use_test_db):
    socket = StubWebSocket([{"token": "not.a.jwt"}])
    await driver_location_ws(socket, str(uuid.uuid4()))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_driver_ws_rejects_a_patient_token(use_test_db, scenario):
    socket = StubWebSocket([{"token": scenario["patient_token"]}])
    await driver_location_ws(socket, str(scenario["ride"].id))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_driver_ws_rejects_a_ride_the_driver_does_not_own(
    use_test_db, scenario, ws_db: AsyncSession
):
    other_patient_user = await _make_user(ws_db, UserRole.patient)
    other_patient = Patient(user_id=other_patient_user.id, full_name="Other")
    ws_db.add(other_patient)
    await ws_db.flush()
    foreign_ride = Ride(
        patient_id=other_patient.id,
        ride_type=RideType.emergency,
        status=RideStatus.pending,
        pickup_lat=33.7,
        pickup_lng=73.0,
    )
    ws_db.add(foreign_ride)
    await ws_db.commit()
    await ws_db.refresh(foreign_ride)

    socket = StubWebSocket([{"token": scenario["driver_token"]}])
    await driver_location_ws(socket, str(foreign_ride.id))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_driver_ws_persists_and_publishes_a_fix(
    use_test_db, scenario, ws_db: AsyncSession
):
    socket = StubWebSocket(
        [{"token": scenario["driver_token"]}, {"lat": 33.725, "lng": 73.045}]
    )
    publish = AsyncMock()
    with patch.object(ws_module.location_manager, "publish", publish):
        await driver_location_ws(socket, str(scenario["ride"].id))

    assert socket.sent == [{"ack": True, "lat": 33.725, "lng": 73.045}]
    publish.assert_awaited_once_with(str(scenario["ride"].id), 33.725, 73.045)

    driver = (
        await ws_db.execute(select(Driver).where(Driver.id == scenario["driver"].id))
    ).scalar_one()
    await ws_db.refresh(driver)
    assert driver.current_lat == pytest.approx(33.725)
    assert driver.current_lng == pytest.approx(73.045)
    assert driver.last_seen_at is not None


@pytest.mark.asyncio
async def test_driver_ws_refuses_out_of_range_coordinates(use_test_db, scenario):
    socket = StubWebSocket(
        [{"token": scenario["driver_token"]}, {"lat": 999.0, "lng": 73.045}]
    )
    publish = AsyncMock()
    with patch.object(ws_module.location_manager, "publish", publish):
        await driver_location_ws(socket, str(scenario["ride"].id))

    assert socket.sent == [{"error": "invalid coordinates"}]
    publish.assert_not_awaited()


# ── ride tracking stream ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_tracking_ws_closes_on_invalid_token(use_test_db):
    socket = StubWebSocket([{"token": "not.a.jwt"}])
    await ride_tracking_ws(socket, str(uuid.uuid4()))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_tracking_ws_closes_for_an_unknown_ride(use_test_db, scenario):
    socket = StubWebSocket([{"token": scenario["patient_token"]}])
    await ride_tracking_ws(socket, str(uuid.uuid4()))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_tracking_ws_rejects_an_unrelated_patient(
    use_test_db, scenario, ws_db: AsyncSession
):
    stranger_user = await _make_user(ws_db, UserRole.patient)
    ws_db.add(Patient(user_id=stranger_user.id, full_name="Stranger"))
    await ws_db.commit()

    socket = StubWebSocket([{"token": _token(stranger_user)}])
    await ride_tracking_ws(socket, str(scenario["ride"].id))
    assert socket.closed_code == status.WS_1008_POLICY_VIOLATION


@pytest.mark.asyncio
async def test_tracking_ws_forwards_locations_to_the_owning_patient(
    use_test_db, scenario
):
    payload = json.dumps({"lat": 33.72, "lng": 73.04})
    pubsub = StubPubSub([{"type": "subscribe"}, {"type": "message", "data": payload}])
    socket = StubWebSocket([{"token": scenario["patient_token"]}])

    with patch.object(
        ws_module.location_manager, "subscribe", AsyncMock(return_value=pubsub)
    ):
        await ride_tracking_ws(socket, str(scenario["ride"].id))

    assert socket.sent == [payload]
    assert pubsub.unsubscribed and pubsub.closed


@pytest.mark.asyncio
async def test_tracking_ws_allows_the_assigned_driver(use_test_db, scenario):
    payload = json.dumps({"lat": 33.72, "lng": 73.04})
    pubsub = StubPubSub([{"type": "message", "data": payload}])
    socket = StubWebSocket([{"token": scenario["driver_token"]}])

    with patch.object(
        ws_module.location_manager, "subscribe", AsyncMock(return_value=pubsub)
    ):
        await ride_tracking_ws(socket, str(scenario["ride"].id))

    assert socket.sent == [payload]


@pytest.mark.asyncio
async def test_tracking_ws_allows_an_admin(use_test_db, scenario):
    payload = json.dumps({"lat": 33.72, "lng": 73.04})
    pubsub = StubPubSub([{"type": "message", "data": payload}])
    socket = StubWebSocket([{"token": scenario["admin_token"]}])

    with patch.object(
        ws_module.location_manager, "subscribe", AsyncMock(return_value=pubsub)
    ):
        await ride_tracking_ws(socket, str(scenario["ride"].id))

    assert socket.sent == [payload]


@pytest.mark.asyncio
async def test_tracking_ws_stops_streaming_once_the_ride_ends(
    use_test_db, scenario, ws_db: AsyncSession
):
    """A completed ride must not keep leaking GPS to the client."""
    ride = scenario["ride"]
    ride.status = RideStatus.completed
    ws_db.add(ride)
    await ws_db.commit()

    pubsub = StubPubSub(
        [
            {"type": "message", "data": json.dumps({"lat": 33.72, "lng": 73.04})},
            {"type": "message", "data": json.dumps({"lat": 33.73, "lng": 73.05})},
        ]
    )
    socket = StubWebSocket([{"token": scenario["patient_token"]}])

    with patch.object(
        ws_module.location_manager, "subscribe", AsyncMock(return_value=pubsub)
    ):
        await ride_tracking_ws(socket, str(ride.id))

    assert socket.sent == [{"event": "ride_ended", "status": "completed"}]
    assert pubsub.unsubscribed and pubsub.closed
