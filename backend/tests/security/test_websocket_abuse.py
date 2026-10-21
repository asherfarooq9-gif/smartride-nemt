"""The live-tracking sockets under hostile or sloppy clients."""

import asyncio
import json
import uuid
from datetime import timedelta

import pytest
import pytest_asyncio
from sqlalchemy import update
from starlette.testclient import TestClient, WebSocketDisconnect

from app.core.database import engine
from app.core.security import create_access_token
from app.models.models import Ride, RideStatus
from app.services.ws_manager import location_manager
from main import app
from tests.test_review_fixes import _auth, _register
from tests.test_ride_lifecycle import _assigned_ride, _phone

POLICY_VIOLATION = 1008


@pytest_asyncio.fixture(autouse=True)
async def _isolate_loop_bound_clients():
    """The sockets run on TestClient's own event loop; do not leak its connections."""
    await engine.dispose()
    yield
    await engine.dispose()
    location_manager._redis = None
    import app.core.redis_client as rc

    rc._redis = None


def _run_ws(path: str, first_message: dict | None, script):
    """Connect on a fresh loop (in a thread, so the test loop stays free)."""
    import app.core.redis_client as rc

    def go():
        # Redis clients are bound to the loop that created them.
        rc._redis = None
        location_manager._redis = None
        try:
            with TestClient(app).websocket_connect(path) as ws:
                if first_message is not None:
                    ws.send_text(json.dumps(first_message))
                return script(ws)
        finally:
            rc._redis = None
            location_manager._redis = None

    return asyncio.to_thread(go)


def _closes_with_policy_violation(ws) -> bool:
    with pytest.raises(WebSocketDisconnect) as closed:
        ws.receive_text()
    return closed.value.code == POLICY_VIOLATION


async def _ride_with_driver(client, driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), driver_token)
    return ride_id


async def test_malformed_ride_id_closes_the_socket_cleanly():
    got = await _run_ws("/ws/driver/not-a-uuid", None, _closes_with_policy_violation)
    assert got is True
    got = await _run_ws("/ws/ride/not-a-uuid", None, _closes_with_policy_violation)
    assert got is True


async def test_unauthenticated_socket_is_closed():
    ride_id = uuid.uuid4()
    got = await _run_ws(
        f"/ws/driver/{ride_id}", {"token": "garbage"}, _closes_with_policy_violation
    )
    assert got is True


async def test_stranger_cannot_watch_someone_elses_ride(client, verified_driver_token):
    ride_id = await _ride_with_driver(client, verified_driver_token)
    stranger = await _register(client, _phone(), "patient")
    got = await _run_ws(
        f"/ws/ride/{ride_id}", {"token": stranger}, _closes_with_policy_violation
    )
    assert got is True


async def test_driver_cannot_stream_to_a_ride_that_is_not_theirs(
    client, verified_driver_token
):
    ride_id = await _ride_with_driver(client, verified_driver_token)
    other = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"W-{uuid.uuid4().hex[:8]}",
        vehicle_plate=f"W-{uuid.uuid4().hex[:6]}",
        vehicle_type="sedan",
    )
    got = await _run_ws(
        f"/ws/driver/{ride_id}", {"token": other}, _closes_with_policy_violation
    )
    assert got is True


async def test_owner_driver_gets_acks_and_bad_frames_get_errors(
    client, verified_driver_token
):
    ride_id = await _ride_with_driver(client, verified_driver_token)

    def script(ws):
        replies = []
        ws.send_text(json.dumps({"lat": 33.7, "lng": 73.0}))
        replies.append(ws.receive_json())
        for bad in ({"lat": 999, "lng": 0}, {"lat": "x"}, {"nope": 1}, [1, 2]):
            ws.send_text(json.dumps(bad))
            replies.append(ws.receive_json())
        return replies

    replies = await _run_ws(
        f"/ws/driver/{ride_id}", {"token": verified_driver_token}, script
    )

    assert replies[0].get("ack") is True
    assert all("error" in r for r in replies[1:])


async def test_gps_flood_is_throttled_then_disconnected(client, verified_driver_token):
    ride_id = await _ride_with_driver(client, verified_driver_token)

    def script(ws):
        ws.send_text(json.dumps({"lat": 33.7, "lng": 73.0}))
        assert ws.receive_json().get("ack") is True
        throttled = 0
        try:
            for _ in range(25):  # back-to-back: well under the minimum interval
                ws.send_text(json.dumps({"lat": 33.7, "lng": 73.0}))
                if "error" in ws.receive_json():
                    throttled += 1
        except WebSocketDisconnect as closed:
            return throttled, closed.code
        return throttled, None

    throttled, code = await _run_ws(
        f"/ws/driver/{ride_id}", {"token": verified_driver_token}, script
    )
    assert throttled >= 1
    assert code == POLICY_VIOLATION


async def test_stream_ends_once_the_ride_is_over(client, db, verified_driver_token):
    ride_id = await _ride_with_driver(client, verified_driver_token)
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(status=RideStatus.completed)
    )
    await db.commit()

    def script(ws):
        ws.send_text(json.dumps({"lat": 33.7, "lng": 73.0}))
        return ws.receive_json()

    reply = await _run_ws(
        f"/ws/driver/{ride_id}", {"token": verified_driver_token}, script
    )
    assert reply == {"event": "ride_ended"}


async def test_an_expired_token_cannot_keep_a_socket_open(
    client, verified_driver_token
):
    ride_id = await _ride_with_driver(client, verified_driver_token)
    me = await client.get("/api/v1/auth/me", headers=_auth(verified_driver_token))
    short_lived = create_access_token(
        {"sub": me.json()["user_id"], "role": "driver", "roles": ["driver"]},
        expires_delta=timedelta(seconds=2),
    )

    def script(ws):
        import time

        ws.send_text(json.dumps({"lat": 33.7, "lng": 73.0}))
        assert ws.receive_json().get("ack") is True
        time.sleep(3)
        ws.send_text(json.dumps({"lat": 33.71, "lng": 73.0}))
        with pytest.raises(WebSocketDisconnect) as closed:
            ws.receive_json()
        return closed.value.code

    assert (
        await _run_ws(f"/ws/driver/{ride_id}", {"token": short_lived}, script)
        == POLICY_VIOLATION
    )
