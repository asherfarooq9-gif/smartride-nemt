from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def triage(text: str) -> dict:
    resp = client.post("/triage", json={"text": text})
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_ear_does_not_match_inside_other_words():
    # "early" contains "ear": this used to be routed to ENT.
    assert triage("abdominal pain since early morning")["specialty"] == "general_emergency"
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
    result = triage("he can\u2019t breathe")
    assert result["severity"] == "5"
    assert result["rule_override"] is True


def test_critical_phrases_set_severity_5():
    for text in ("chest pain", "baby not breathing", "he is unconscious", "Severe  Bleeding"):
        assert triage(text)["severity"] == "5", text


def test_non_critical_default_severity():
    assert triage("mild skin rash")["severity"] == "2"


def test_text_is_bounded():
    assert client.post("/triage", json={"text": ""}).status_code == 422
    assert client.post("/triage", json={"text": "a" * 2001}).status_code == 422
    assert client.post("/triage", json={"text": "a" * 2000}).status_code == 200
