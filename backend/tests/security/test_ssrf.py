"""Hospital pre-alert URLs are admin-supplied and the server POSTs patient data to
them: they must never reach loopback, private, link-local or metadata addresses."""

import logging
import socket
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from app.core import safe_url
from app.core.safe_url import UnsafeUrlError, is_public_address, resolve_public_ip
from app.schemas.hospitals import HospitalCreate
from app.services import notifications

BASE = {
    "name": "H",
    "address": "a",
    "city": "c",
    "lat": 33.0,
    "lng": 73.0,
}

RIDE = SimpleNamespace(id="ride-1")
PATIENT = SimpleNamespace(id="p1")
TRIAGE = {"specialty": "cardiology", "severity": "5"}


def _fake_dns(monkeypatch, answers: dict[str, list[str]]):
    def getaddrinfo(host, port, *args, **kwargs):
        if host not in answers:
            raise socket.gaierror("no such host")
        return [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", (addr, port))
            for addr in answers[host]
        ]

    monkeypatch.setattr(safe_url.socket, "getaddrinfo", getaddrinfo)


@pytest.mark.parametrize(
    "endpoint",
    [
        "https://2130706433/fhir",  # integer form of 127.0.0.1
        "https://0x7f000001/fhir",  # hex
        "https://0177.0.0.1/fhir",  # octal
        "https://127.1/fhir",  # short form
        "https://8.8.8.8/fhir",  # any IP literal
        "https://[::ffff:7f00:1]/fhir",  # IPv4-mapped IPv6 loopback
        "https://[2001:4860:4860::8888]/fhir",
        "https://localhost./fhir",
        "https://printer.lan/fhir",
        "https://user:pw@fhir.example.org/fhir",
        "http://fhir.example.org/fhir",
        "gopher://fhir.example.org/",
    ],
)
def test_schema_rejects_numeric_and_internal_hosts(endpoint):
    with pytest.raises(ValidationError):
        HospitalCreate(**BASE, fhir_endpoint=endpoint)


def test_schema_accepts_a_normal_https_hostname():
    h = HospitalCreate(**BASE, fhir_endpoint="https://fhir.example.org:8443/Bundle")
    assert h.fhir_endpoint == "https://fhir.example.org:8443/Bundle"


@pytest.mark.parametrize(
    "address",
    [
        "127.0.0.1",
        "10.1.2.3",
        "172.16.0.1",
        "192.168.1.1",
        "169.254.169.254",  # cloud metadata
        "100.64.0.1",  # carrier-grade NAT
        "0.0.0.0",
        "224.0.0.1",  # multicast
        "240.0.0.1",  # reserved
        "::1",
        "fe80::1",
        "fc00::1",
        "::ffff:10.0.0.1",
        "64:ff9b::7f00:1",  # NAT64 wrapping 127.0.0.1
        "2002:7f00:1::",  # 6to4 wrapping 127.0.0.1
    ],
)
def test_non_public_addresses_are_refused(address):
    assert not is_public_address(address)


@pytest.mark.parametrize("address", ["8.8.8.8", "93.184.216.34", "2606:2800:220:1::1"])
def test_public_addresses_are_allowed(address):
    assert is_public_address(address)


async def test_a_name_that_resolves_to_loopback_is_refused(monkeypatch):
    _fake_dns(monkeypatch, {"127.0.0.1.nip.io": ["127.0.0.1"]})
    with pytest.raises(UnsafeUrlError):
        await resolve_public_ip("127.0.0.1.nip.io", 443)


async def test_one_private_answer_among_public_ones_is_refused(monkeypatch):
    _fake_dns(monkeypatch, {"mixed.example": ["93.184.216.34", "169.254.169.254"]})
    with pytest.raises(UnsafeUrlError):
        await resolve_public_ip("mixed.example", 443)


async def test_unresolvable_host_is_refused(monkeypatch):
    _fake_dns(monkeypatch, {})
    with pytest.raises(UnsafeUrlError):
        await resolve_public_ip("nope.example", 443)


async def test_public_name_resolves(monkeypatch):
    _fake_dns(monkeypatch, {"fhir.example.org": ["93.184.216.34"]})
    assert await resolve_public_ip("fhir.example.org", 443) == "93.184.216.34"


class RecordingClient:
    calls: list = []
    init_kwargs: dict = {}

    def __init__(self, *args, **kwargs):
        RecordingClient.init_kwargs = kwargs

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def post(self, url, **kwargs):
        RecordingClient.calls.append((url, kwargs))
        return SimpleNamespace(raise_for_status=lambda: None)


def _hospital(endpoint, phone=None):
    return SimpleNamespace(
        has_fhir=True, fhir_endpoint=endpoint, coordinator_phone=phone
    )


async def test_alert_connects_to_the_validated_ip_without_redirects(monkeypatch):
    _fake_dns(monkeypatch, {"fhir.example.org": ["93.184.216.34"]})
    RecordingClient.calls = []
    monkeypatch.setattr(notifications.httpx, "AsyncClient", RecordingClient)

    ok = await notifications.send_hospital_alert(
        ride=RIDE,
        triage=TRIAGE,
        hospital=_hospital("https://fhir.example.org:8443/Bundle"),
        patient=PATIENT,
    )

    assert ok is True
    ((url, kwargs),) = RecordingClient.calls
    assert url == "https://93.184.216.34:8443/Bundle"
    assert kwargs["headers"]["Host"] == "fhir.example.org:8443"
    assert kwargs["extensions"] == {"sni_hostname": "fhir.example.org"}
    assert RecordingClient.init_kwargs["follow_redirects"] is False
    assert RecordingClient.init_kwargs["trust_env"] is False
    assert RecordingClient.init_kwargs["timeout"].read <= 5.0


@pytest.mark.parametrize("target", ["127.0.0.1", "169.254.169.254", "10.0.0.5"])
async def test_alert_never_posts_to_a_name_pointing_inside(monkeypatch, target):
    _fake_dns(monkeypatch, {"evil.example": [target]})
    RecordingClient.calls = []
    monkeypatch.setattr(notifications.httpx, "AsyncClient", RecordingClient)
    sent = []
    monkeypatch.setattr(
        notifications, "_send_sms", lambda to, body: sent.append(to) or True
    )

    ok = await notifications.send_hospital_alert(
        ride=RIDE,
        triage=TRIAGE,
        hospital=_hospital("https://evil.example/fhir", phone="+923001112222"),
        patient=PATIENT,
    )

    assert RecordingClient.calls == []
    assert sent == ["+923001112222"]  # fell back to SMS
    assert ok is True


async def test_alert_reports_undelivered_when_nothing_worked(monkeypatch, caplog):
    _fake_dns(monkeypatch, {})
    with caplog.at_level(logging.ERROR, logger="smartride.notifications"):
        ok = await notifications.send_hospital_alert(
            ride=RIDE,
            triage=TRIAGE,
            hospital=_hospital("https://down.example/fhir", phone=None),
            patient=PATIENT,
        )
    assert ok is False
    errors = [r.getMessage() for r in caplog.records if r.levelno == logging.ERROR]
    assert any("NOT delivered" in m and "ride-1" in m for m in errors)


async def test_alert_reports_undelivered_when_sms_fails(monkeypatch, caplog):
    monkeypatch.setattr(notifications, "_send_sms", lambda to, body: False)
    hospital = SimpleNamespace(
        has_fhir=False, fhir_endpoint=None, coordinator_phone="+923001112222"
    )
    with caplog.at_level(logging.ERROR, logger="smartride.notifications"):
        ok = await notifications.send_hospital_alert(
            ride=RIDE, triage=TRIAGE, hospital=hospital, patient=PATIENT
        )
    assert ok is False
    assert any("ride-1" in r.getMessage() for r in caplog.records)
