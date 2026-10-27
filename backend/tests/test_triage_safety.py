"""Triage output is only ever allowed to raise severity, never to lower it."""

import pytest
from prometheus_client import REGISTRY

from app.services.emergency_dispatch import normalise_triage
from app.services.triage_keywords import KEYWORDS_VERSION, compute_severity

TEXTS = [
    "chest pain and sweating",
    "my child has a high fever",
    "severe bleeding after a fall",
    "he is unconscious and not breathing",
    "mild headache since morning",
    "need transport to my dialysis appointment",
]


def _service(severity, **extra):
    return {"specialty": "cardiology", "severity": severity, **extra}


@pytest.mark.parametrize("text", TEXTS)
@pytest.mark.parametrize("service_severity", ["1", "2", "3", "4", "5"])
def test_severity_is_never_below_what_the_local_rules_compute(text, service_severity):
    local, _ = compute_severity(text)

    result = normalise_triage(_service(service_severity), text)

    assert int(result["severity"]) >= int(local)
    assert int(result["severity"]) >= int(service_severity)
    assert int(result["severity"]) == max(int(local), int(service_severity))


def test_a_stale_service_saying_two_for_a_dangerous_text_is_overruled():
    text = "chest pain and sweating"
    local, _ = compute_severity(text)
    assert int(local) >= 3, "pick a text the local rules take seriously"

    result = normalise_triage(_service("2"), text)

    assert result["severity"] == local


def test_a_higher_service_severity_is_kept():
    result = normalise_triage(_service("5"), "mild headache since morning")

    assert result["severity"] == "5"


def _mismatches() -> float:
    return (
        REGISTRY.get_sample_value(
            "smartride_dispatch_failures_total", {"reason": "triage_keywords_mismatch"}
        )
        or 0.0
    )


def test_a_service_running_different_keywords_is_noticed(caplog):
    before = _mismatches()

    with caplog.at_level("WARNING", logger="smartride.dispatch"):
        normalise_triage(_service("3", model_version="rules-v2.0-deadbeef"), "pain")

    assert _mismatches() == before + 1
    assert any("keyword" in r.message.lower() for r in caplog.records)


def test_a_service_on_the_same_keywords_is_not_flagged():
    before = _mismatches()
    same = f"rules-v2.0-{KEYWORDS_VERSION[:8]}"

    normalise_triage(_service("3", model_version=same), "pain")

    assert _mismatches() == before


def test_the_local_fallback_and_unversioned_output_are_not_flagged():
    before = _mismatches()

    normalise_triage(_service("3", model_version="fallback-rules-abc"), "pain")
    normalise_triage(_service("3"), "pain")

    assert _mismatches() == before
