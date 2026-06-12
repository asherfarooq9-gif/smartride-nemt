from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Literal

_INSECURE_SECRET = "change_me_to_a_32_char_random_string_here"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

    # JWT
    SECRET_KEY: str = _INSECURE_SECRET
    JWT_ALGORITHM: Literal["HS256", "HS384", "HS512"] = "HS256"
    JWT_EXPIRE_MINUTES: int = 60

    # Database
    DATABASE_URL: str = (
        "postgresql+asyncpg://smartride:password@postgres:5432/smartride"
    )

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # AI Services
    TRIAGE_SERVICE_URL: str = "http://triage:8001"

    # Twilio
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # Google Maps
    GOOGLE_MAPS_API_KEY: str = ""

    # Firebase
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"

    # App
    DEBUG: bool = False
    # In production set ALLOWED_ORIGINS to explicit origins, e.g.:
    #   ALLOWED_ORIGINS=["https://your-admin.example.com"]
    # The wildcard is only acceptable for local development (DEBUG=True).
    ALLOWED_ORIGINS: List[str] = ["*"]
    EMERGENCY_PIPELINE_TARGET_SECONDS: float = 60.0
    LOG_LEVEL: str = "INFO"

    @model_validator(mode="after")
    def validate_production_secrets(self) -> "Settings":
        if not self.DEBUG:
            if self.SECRET_KEY == _INSECURE_SECRET:
                raise ValueError(
                    "SECRET_KEY must be set to a random value in production (DEBUG=False)"
                )
            if "*" in self.ALLOWED_ORIGINS:
                raise ValueError(
                    "Wildcard CORS origin is not allowed in production (DEBUG=False). "
                    "Set ALLOWED_ORIGINS to explicit origins."
                )
        return self


settings = Settings()
