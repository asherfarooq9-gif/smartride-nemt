"""Internet calls between the patient and the driver: ICE servers and signalling.

The server never touches the audio; it only hands out short-lived relay
credentials and passes call set-up messages (offer, answer, candidates) between
the two people on a live ride.
"""

import base64
import hashlib
import hmac

import pytest

from app.core.config import settings
from app.services import call_service
from tests.test_ride_chat import _auth
from tests.test_ride_lifecycle import _assigned_ride, _phone

TURN = "turn:turn.example.com:3478?transport=udp"


@pytest.fixture
def turn_configured(monkeypatch):
    monkeypatch.setattr(settings, "TURN_URLS", [TURN])
    monkeypatch.setattr(settings, "STUN_URLS", ["stun:turn.example.com:3478"])
    monkeypatch.setattr(settings, "TURN_SECRET", "s3cret")
    monkeypatch.setattr(settings, "TURN_TTL_SECONDS", 600)


def test_relay_credentials_follow_the_coturn_rest_scheme(turn_configured):
    result = call_service.ice_servers("user-1", now=1000)

    stun, turn = result["ice_servers"]
    assert stun == {"urls": ["stun:turn.example.com:3478"]}
    assert turn["urls"] == [TURN]
    assert turn["username"] == "1600:user-1"  # expires at now + ttl
    expected = base64.b64encode(
        hmac.new(b"s3cret", b"1600:user-1", hashlib.sha1).digest()
    ).decode()
    assert turn["credential"] == expected
    assert result["ttl_seconds"] == 600


def test_without_a_relay_there_are_no_servers_and_no_credentials(monkeypatch):
    monkeypatch.setattr(settings, "TURN_URLS", [])
    monkeypatch.setattr(settings, "STUN_URLS", [])
    monkeypatch.setattr(settings, "TURN_SECRET", "")

    result = call_service.ice_servers("user-1", now=1000)

    assert result["ice_servers"] == []


def test_a_relay_url_without_a_secret_is_never_handed_out(monkeypatch):
    monkeypatch.setattr(settings, "TURN_URLS", [TURN])
    monkeypatch.setattr(settings, "STUN_URLS", [])
    monkeypatch.setattr(settings, "TURN_SECRET", "")

    assert call_service.ice_servers("user-1", now=1000)["ice_servers"] == []


@pytest.mark.parametrize(
    "frame, expected",
    [
        ({"type": "invite"}, {"type": "invite"}),
        ({"type": "accept"}, {"type": "accept"}),
        ({"type": "decline"}, {"type": "decline"}),
        ({"type": "hangup"}, {"type": "hangup"}),
        ({"type": "offer", "sdp": "v=0"}, {"type": "offer", "sdp": "v=0"}),
        ({"type": "answer", "sdp": "v=0"}, {"type": "answer", "sdp": "v=0"}),
        (
            {
                "type": "ice",
                "candidate": {
                    "candidate": "candidate:1 1 udp 1 10.0.0.1 5000 typ host",
                    "sdpMid": "0",
                    "sdpMLineIndex": 0,
                },
            },
            {
                "type": "ice",
                "candidate": {
                    "candidate": "candidate:1 1 udp 1 10.0.0.1 5000 typ host",
                    "sdpMid": "0",
                    "sdpMLineIndex": 0,
                },
            },
        ),
        # extra fields never pass through; the sender cannot choose who it is
        ({"type": "hangup", "from": "driver", "x": 1}, {"type": "hangup"}),
    ],
)
def test_a_valid_signal_is_passed_on_with_only_known_fields(frame, expected):
    assert call_service.sanitize_signal(frame) == expected


@pytest.mark.parametrize(
    "frame",
    [
        None,
        "invite",
        [],
        {},
        {"type": "shout"},
        {"type": 5},
        {"type": "offer"},
        {"type": "offer", "sdp": ""},
        {"type": "offer", "sdp": 7},
        {"type": "answer", "sdp": "x" * 20_001},
        {"type": "ice"},
        {"type": "ice", "candidate": "nope"},
        {"type": "ice", "candidate": {"candidate": 3}},
        {"type": "ice", "candidate": {"candidate": "x" * 2_001}},
        {"type": "ice", "candidate": {"candidate": "c", "sdpMLineIndex": "0"}},
        {"type": "ice", "candidate": {"candidate": "c", "sdpMLineIndex": 999}},
    ],
)
def test_anything_else_is_dropped(frame):
    assert call_service.sanitize_signal(frame) is None


async def test_a_participant_gets_relay_servers_for_a_live_ride(
    client, verified_driver_token, turn_configured
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    for token in (patient_token, verified_driver_token):
        r = await client.get(
            f"/api/v1/rides/{ride_id}/call/ice-servers", headers=_auth(token)
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["ttl_seconds"] == 600
        assert body["ice_servers"][-1]["urls"] == [TURN]


async def test_each_person_gets_their_own_credentials(
    client, verified_driver_token, turn_configured
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )

    names = set()
    for token in (patient_token, verified_driver_token):
        r = await client.get(
            f"/api/v1/rides/{ride_id}/call/ice-servers", headers=_auth(token)
        )
        names.add(r.json()["ice_servers"][-1]["username"])

    assert len(names) == 2


async def test_a_stranger_gets_no_relay_credentials(
    client, verified_driver_token, turn_configured
):
    from tests.test_dispatch_endpoints import _register

    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    stranger = await _register(client, _phone(), "patient")

    r = await client.get(
        f"/api/v1/rides/{ride_id}/call/ice-servers", headers=_auth(stranger)
    )

    assert r.status_code == 403


async def test_no_relay_credentials_once_the_ride_is_over(
    client, verified_driver_token, turn_configured
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(patient_token),
    )

    r = await client.get(
        f"/api/v1/rides/{ride_id}/call/ice-servers", headers=_auth(patient_token)
    )

    assert r.status_code == 409
