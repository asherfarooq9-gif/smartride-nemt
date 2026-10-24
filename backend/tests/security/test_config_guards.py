"""Misconfiguration that would silently weaken production must stop the app starting."""

import pytest
from pydantic import ValidationError

from app.core.config import Settings

PRODUCTION = {
    "DEBUG": False,
    "SECRET_KEY": "k" * 40,
    "ALLOWED_ORIGINS": ["https://admin.example.com"],
    "ENVIRONMENT": "production",
}


def test_production_settings_are_accepted():
    assert Settings(**PRODUCTION).RATE_LIMITS_ENABLED is True


def test_production_cannot_run_without_rate_limits():
    with pytest.raises(ValidationError, match="RATE_LIMITS_ENABLED"):
        Settings(**PRODUCTION, RATE_LIMITS_ENABLED=False)


def test_rate_limits_may_be_off_outside_production():
    assert Settings(**{**PRODUCTION, "ENVIRONMENT": "test"}, RATE_LIMITS_ENABLED=False)


def test_production_rejects_a_short_secret_key():
    with pytest.raises(ValidationError, match="at least 32"):
        Settings(**{**PRODUCTION, "SECRET_KEY": "k" * 31})


def test_production_accepts_a_32_character_secret_key():
    assert Settings(**{**PRODUCTION, "SECRET_KEY": "k" * 32})


def test_debug_mode_allows_a_short_secret_key():
    assert Settings(
        **{
            **PRODUCTION,
            "ENVIRONMENT": "development",
            "DEBUG": True,
            "SECRET_KEY": "short",
            "ALLOWED_ORIGINS": ["*"],
        }
    )


def test_production_environment_cannot_run_in_debug_mode():
    with pytest.raises(ValidationError, match="DEBUG must be false"):
        Settings(
            **{
                **PRODUCTION,
                "DEBUG": True,
                "SECRET_KEY": "short",
                "ALLOWED_ORIGINS": ["*"],
            }
        )


def test_service_area_bbox_is_parsed():
    settings = Settings(**PRODUCTION, SERVICE_AREA_BBOX="23,60.5,37.5,78")
    assert settings.service_area_bbox() == (23.0, 60.5, 37.5, 78.0)


def test_service_area_bbox_is_off_by_default():
    assert Settings(**PRODUCTION).service_area_bbox() is None


@pytest.mark.parametrize("bad", ["1,2,3", "a,b,c,d", "10,10,5,20", "1,20,5,10"])
def test_malformed_service_area_bbox_stops_startup(bad):
    with pytest.raises(ValidationError, match="SERVICE_AREA_BBOX"):
        Settings(**PRODUCTION, SERVICE_AREA_BBOX=bad)
