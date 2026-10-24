import logging

import pytest
from fastapi.testclient import TestClient

from main import MAX_TEXT_LENGTH, app

client = TestClient(app)


def triage(text: str) -> dict:
    resp = client.post("/triage", json={"text": text})
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_ear_does_not_match_inside_other_words():
    # "early" contains "ear": this used to be routed to ENT.
    assert triage("pain since early morning")["specialty"] == "general_emergency"
    assert triage("my nearby neighbour has a rash")["specialty"] == "dermatology"


def test_real_ear_complaints_still_route_to_ent():
    assert triage("severe ear pain")["specialty"] == "ent"
    assert triage("pain in both ears")["specialty"] == "ent"


def test_heart_is_cardiology_not_ent():
    assert triage("my heart is racing")["specialty"] == "cardiology"


def test_plural_and_inflected_forms_match():
    assert triage("possible broken bones")["specialty"] == "orthopedics"
    assert triage("vomiting all night")["specialty"] == "gastroenterology"


def test_curly_apostrophe_still_flags_critical():
    # iOS keyboards type U+2019, not an ASCII apostrophe.
    result = triage("he can’t breathe")
    assert result["severity"] == "5"
    assert result["rule_override"] is True


def test_critical_phrases_set_severity_5():
    for text in ("chest pain", "baby not breathing", "he is unconscious", "Severe  Bleeding"):
        assert triage(text)["severity"] == "5", text


def test_low_acuity_specialty_keeps_low_severity():
    assert triage("mild skin rash")["severity"] == "2"


def test_response_schema_is_backwards_compatible():
    body = triage("chest pain")
    assert set(body) == {
        "specialty", "confidence", "severity", "rule_override", "model_version", "inference_ms",
    }
    assert isinstance(body["confidence"], float)
    assert isinstance(body["severity"], str)
    assert isinstance(body["rule_override"], bool)
    assert isinstance(body["inference_ms"], int)
    assert len(body["model_version"]) <= 50


# ── input handling ───────────────────────────────────────────────────────────

def test_text_is_bounded():
    assert client.post("/triage", json={"text": ""}).status_code == 422
    assert client.post("/triage", json={"text": "a" * (MAX_TEXT_LENGTH + 1)}).status_code == 422
    assert client.post("/triage", json={"text": "a" * MAX_TEXT_LENGTH}).status_code == 200


@pytest.mark.parametrize("bad", [123, 1.5, True, None, ["chest pain"], {"a": "b"}])
def test_non_string_text_is_rejected(bad):
    assert client.post("/triage", json={"text": bad}).status_code == 422


def test_missing_text_is_rejected():
    assert client.post("/triage", json={}).status_code == 422


@pytest.mark.parametrize("blank", [" ", "   \n\t ", "!!! ???", "‌‍"])
def test_text_with_no_content_does_not_crash_and_is_cautious(blank):
    body = triage(blank)
    assert body["specialty"] == "general_emergency"
    assert int(body["severity"]) >= 3


def test_max_length_adversarial_input_is_fast_and_valid():
    for text in ("a " * 1000, "سانس " * 400, "chest " * 330, "’" * MAX_TEXT_LENGTH):
        assert client.post("/triage", json={"text": text}).status_code == 200


def test_request_text_is_never_logged(caplog):
    secret = "pt-zz91-chest-secret-marker"
    with caplog.at_level(logging.DEBUG):
        triage(f"{secret} he has a headache")
    assert secret not in caplog.text
