"""Labelled vignettes (English, Roman Urdu, Urdu) with expected minimum
severity and specialty. Sensitivity for severity 5 must be exactly 100%."""
import json
from pathlib import Path

import pytest

from keywords import compute_severity, infer_specialty

GOLD_PATH = Path(__file__).with_name("gold_set.json")
GOLD = json.loads(GOLD_PATH.read_text(encoding="utf-8"))
SEVERITY_5 = [case for case in GOLD if case["min_severity"] == 5]


def _predict(case: dict) -> tuple[int, str]:
    return int(compute_severity(case["text"])[0]), infer_specialty(case["text"])[0]


def test_gold_set_is_large_and_well_formed():
    assert len(GOLD) >= 100
    assert {case["lang"] for case in GOLD} == {"en", "roman_urdu", "urdu"}
    for lang in ("en", "roman_urdu", "urdu"):
        assert sum(case["lang"] == lang for case in GOLD) >= 20
    assert len(SEVERITY_5) >= 50
    for case in GOLD:
        assert set(case) == {"text", "lang", "min_severity", "specialty"}
        assert isinstance(case["text"], str) and case["text"].strip()
        assert case["min_severity"] in (1, 2, 3, 4, 5)


def test_severity_5_sensitivity_is_100_percent(record_property):
    missed = [case["text"] for case in SEVERITY_5 if _predict(case)[0] < 5]
    sensitivity = 1 - len(missed) / len(SEVERITY_5)
    record_property("severity5_sensitivity", f"{sensitivity:.4f}")
    record_property("severity5_cases", len(SEVERITY_5))
    assert not missed, f"sensitivity {sensitivity:.1%}, missed life threats: {missed}"


def test_no_gold_case_is_under_triaged():
    under = [
        (case["text"], case["min_severity"], _predict(case)[0])
        for case in GOLD
        if _predict(case)[0] < case["min_severity"]
    ]
    assert not under, f"under-triaged (text, expected>=, got): {under}"


@pytest.mark.parametrize("lang", ["en", "roman_urdu", "urdu"])
def test_severity_5_sensitivity_per_language(lang):
    cases = [case for case in SEVERITY_5 if case["lang"] == lang]
    assert cases
    assert all(_predict(case)[0] == 5 for case in cases), [
        case["text"] for case in cases if _predict(case)[0] < 5
    ]


def test_specialty_accuracy_on_labelled_cases():
    labelled = [case for case in GOLD if case["specialty"]]
    wrong = [
        (case["text"], case["specialty"], _predict(case)[1])
        for case in labelled
        if _predict(case)[1] != case["specialty"]
    ]
    assert not wrong, f"wrong specialty (text, expected, got): {wrong}"
