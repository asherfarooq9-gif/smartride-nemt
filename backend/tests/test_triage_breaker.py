"""A dead or hung triage service must cost one short timeout, then nothing."""

from types import SimpleNamespace

import httpx
import pytest
from prometheus_client import REGISTRY

from app.core.config import settings
from app.services import emergency_dispatch as dispatch

GOOD = {
    "specialty": "cardiology",
    "severity": "4",
    "confidence": 0.9,
    "rule_override": False,
    "model_version": "rules-v2.0-test",
}


def _client_class(behaviour, calls):
    class Client:
        def __init__(self, *args, **kwargs):
            calls.append({"timeout": kwargs.get("timeout")})

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def post(self, *args, **kwargs):
            result = behaviour()
            if isinstance(result, Exception):
                raise result
            return SimpleNamespace(raise_for_status=lambda: None, json=lambda: result)

    return Client


@pytest.fixture(autouse=True)
def _fresh_breaker():
    dispatch.reset_triage_breaker()
    yield
    dispatch.reset_triage_breaker()


@pytest.fixture
def clock(monkeypatch):
    now = {"t": 1000.0}
    monkeypatch.setattr(dispatch.time, "monotonic", lambda: now["t"])
    return now


def _count(reason: str) -> float:
    return (
        REGISTRY.get_sample_value(
            "smartride_dispatch_failures_total", {"reason": reason}
        )
        or 0.0
    )


async def test_the_call_uses_the_short_configured_timeout(monkeypatch):
    calls = []
    monkeypatch.setattr(
        dispatch.httpx, "AsyncClient", _client_class(lambda: GOOD, calls)
    )
    monkeypatch.setattr(settings, "TRIAGE_TIMEOUT_SECONDS", 2.5)

    await dispatch.call_triage_service("chest pain")

    assert calls == [{"timeout": 2.5}]


async def test_repeated_failures_open_the_breaker_and_stop_the_network_calls(
    monkeypatch, clock
):
    calls = []
    failing = _client_class(lambda: httpx.ConnectError("down"), calls)
    monkeypatch.setattr(dispatch.httpx, "AsyncClient", failing)
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_FAILURES", 3)
    before = _count("triage_circuit_open")

    for _ in range(3):
        await dispatch.call_triage_service("chest pain")
    assert len(calls) == 3

    result = await dispatch.call_triage_service("chest pain")

    assert len(calls) == 3  # the fourth did not touch the network
    assert result["model_version"].startswith("fallback-rules-")
    assert _count("triage_circuit_open") == before + 1


async def test_after_the_pause_one_probe_goes_through_and_a_success_closes_it(
    monkeypatch, clock
):
    calls = []
    state = {"up": False}
    monkeypatch.setattr(
        dispatch.httpx,
        "AsyncClient",
        _client_class(
            lambda: GOOD if state["up"] else httpx.ConnectError("down"), calls
        ),
    )
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_FAILURES", 2)
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_SECONDS", 30)
    for _ in range(2):
        await dispatch.call_triage_service("chest pain")
    await dispatch.call_triage_service("chest pain")  # open: skipped
    assert len(calls) == 2

    clock["t"] += 31
    state["up"] = True
    probe = await dispatch.call_triage_service("chest pain")

    assert len(calls) == 3
    assert probe["model_version"] == "rules-v2.0-test"
    await dispatch.call_triage_service("chest pain")
    assert len(calls) == 4  # closed again: calls go through


async def test_a_failed_probe_reopens_the_breaker_for_another_pause(monkeypatch, clock):
    calls = []
    monkeypatch.setattr(
        dispatch.httpx,
        "AsyncClient",
        _client_class(lambda: httpx.ReadTimeout("slow"), calls),
    )
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_FAILURES", 2)
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_SECONDS", 30)
    for _ in range(2):
        await dispatch.call_triage_service("chest pain")

    clock["t"] += 31
    await dispatch.call_triage_service("chest pain")  # the probe, fails
    await dispatch.call_triage_service("chest pain")  # open again: skipped

    assert len(calls) == 3


async def test_a_success_resets_the_count_of_consecutive_failures(monkeypatch, clock):
    calls = []
    results = iter([httpx.ConnectError("x"), GOOD, httpx.ConnectError("x"), GOOD])
    monkeypatch.setattr(
        dispatch.httpx, "AsyncClient", _client_class(lambda: next(results), calls)
    )
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_FAILURES", 2)

    for _ in range(4):
        await dispatch.call_triage_service("chest pain")

    assert len(calls) == 4  # never two failures in a row, so never opened


async def test_the_fallback_is_still_safe_while_the_breaker_is_open(monkeypatch, clock):
    calls = []
    monkeypatch.setattr(
        dispatch.httpx,
        "AsyncClient",
        _client_class(lambda: httpx.ConnectError("down"), calls),
    )
    monkeypatch.setattr(settings, "TRIAGE_BREAKER_FAILURES", 1)
    await dispatch.call_triage_service("x")

    result = dispatch.normalise_triage(
        await dispatch.call_triage_service("he is unconscious and not breathing"),
        "he is unconscious and not breathing",
    )

    assert result["severity"] == "5"
