from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # JWT
    SECRET_KEY: str = "change_me_to_a_32_char_random_string_here"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://smartride:password@postgres:5432/smartride"

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

    # App
    DEBUG: bool = False
    ALLOWED_ORIGINS: List[str] = ["*"]
    EMERGENCY_PIPELINE_TARGET_SECONDS: float = 60.0

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
