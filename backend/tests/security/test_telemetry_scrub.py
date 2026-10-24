"""Error reports must not carry tokens or patient data."""

from app.core.observability import _scrub


def test_scrub_removes_credentials_and_request_bodies():
    event = {
        "request": {
            "headers": {
                "Authorization": "Bearer secret",
                "Cookie": "a=b",
                "Accept": "x",
            },
            "data": {"symptom_text": "chest pain", "pickup_address": "12 Street"},
            "cookies": {"a": "b"},
            "query_string": "search=+923001234567",
            "url": "http://api/rides",
        },
        "message": "boom",
    }

    cleaned = _scrub(event, {})

    request = cleaned["request"]
    assert request["headers"]["Authorization"] == "[redacted]"
    assert request["headers"]["Cookie"] == "[redacted]"
    assert request["headers"]["Accept"] == "x"
    for field in ("data", "cookies", "query_string"):
        assert field not in request
    assert request["url"] == "http://api/rides"
    assert cleaned["message"] == "boom"


def test_scrub_tolerates_events_without_a_request():
    assert _scrub({"message": "boom"}, {}) == {"message": "boom"}
