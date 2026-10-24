from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Literal

_INSECURE_SECRET = "change_me_to_a_32_char_random_string_here"
_MIN_SECRET_LENGTH = 32


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
    # Set True when connecting through PgBouncer in transaction-pooling mode:
    # asyncpg prepared statements are per-session and break under transaction
    # pooling, so the statement cache must be disabled.
    DB_DISABLE_PREPARED_CACHE: bool = False

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # AI Services
    TRIAGE_SERVICE_URL: str = "http://triage:8001"

    # Twilio
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # Firebase
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"

    # Observability
    # Error tracking is a no-op unless SENTRY_DSN is set (same pattern as Twilio
    # / Firebase) so local + CI runs stay offline.
    SENTRY_DSN: str = ""
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1
    ENVIRONMENT: str = "development"

    # App
    DEBUG: bool = False
    # In production set ALLOWED_ORIGINS to explicit origins, e.g.:
    #   ALLOWED_ORIGINS=["https://your-admin.example.com"]
    # The wildcard is only acceptable for local development (DEBUG=True).
    ALLOWED_ORIGINS: List[str] = ["*"]
    EMERGENCY_PIPELINE_TARGET_SECONDS: float = 60.0
    # Credential-guessing defence and absolute session lifetime
    # Off only for end-to-end test runs, which sign up and in from one IP.
    RATE_LIMITS_ENABLED: bool = True
    # Failures per (phone, client IP) before that IP is locked out ...
    LOGIN_MAX_FAILURES: int = 5
    # ... and per phone across all IPs, so guessing from many IPs is still bounded
    # without letting one stranger lock the real owner out.
    LOGIN_PHONE_MAX_FAILURES: int = 25
    LOGIN_LOCK_SECONDS: int = 900
    SESSION_MAX_DAYS: int = 30
    # Bearer token Prometheus must send to /metrics (open without it only in DEBUG)
    METRICS_TOKEN: str = ""
    # Drivers farther than this from the pickup are not considered for dispatch
    DRIVER_SEARCH_RADIUS_KM: float = 50.0
    # Fares (flat base + per km) and the platform's share of each fare
    FARE_BASE_PKR: float = 200.0
    FARE_PER_KM_PKR: float = 40.0
    COMMISSION_RATE: float = 0.10
    # Dispatch retry loop (app/services/dispatch_loop.py)
    DISPATCH_LOOP_ENABLED: bool = True
    DISPATCH_LOOP_INTERVAL_SECONDS: float = 15.0
    DISPATCH_RETRY_AFTER_SECONDS: int = 30
    DISPATCH_MAX_AGE_SECONDS: int = 900
    SCHEDULED_DISPATCH_LEAD_MINUTES: int = 30
    LOG_LEVEL: str = "INFO"
    # Minimum seconds a driver must spend on the pickup->hospital and
    # hospital->completed legs before the next status is accepted. 0 disables it
    # (dev/tests); production sets a real value so a ride cannot be "completed"
    # instantly to book a fare and commission without any transport.
    RIDE_MIN_TRANSITION_SECONDS: int = 0
    # "min_lat,min_lng,max_lat,max_lng". Pickups outside this box are rejected.
    # Empty disables the check (emulator GPS defaults to California); production
    # sets it to the area the service operates in.
    SERVICE_AREA_BBOX: str = ""

    @model_validator(mode="after")
    def validate_production_secrets(self) -> "Settings":
        if not self.DEBUG:
            if self.SECRET_KEY == _INSECURE_SECRET:
                raise ValueError(
                    "SECRET_KEY must be set to a random value in production (DEBUG=False)"
                )
            if len(self.SECRET_KEY) < _MIN_SECRET_LENGTH:
                raise ValueError(
                    f"SECRET_KEY must be at least {_MIN_SECRET_LENGTH} characters "
                    "in production (DEBUG=False)"
                )
            if "*" in self.ALLOWED_ORIGINS:
                raise ValueError(
                    "Wildcard CORS origin is not allowed in production (DEBUG=False). "
                    "Set ALLOWED_ORIGINS to explicit origins."
                )
        if self.ENVIRONMENT == "production" and not self.RATE_LIMITS_ENABLED:
            raise ValueError("RATE_LIMITS_ENABLED must be true in production")
        if self.ENVIRONMENT == "production" and self.DEBUG:
            # DEBUG skips the key-strength and CORS checks above and opens /docs
            # and /metrics, so it must never be on in a production environment.
            raise ValueError("DEBUG must be false when ENVIRONMENT=production")
        if self.SERVICE_AREA_BBOX:
            self.service_area_bbox()
        return self

    def service_area_bbox(self) -> tuple[float, float, float, float] | None:
        """Parsed SERVICE_AREA_BBOX as (min_lat, min_lng, max_lat, max_lng)."""
        if not self.SERVICE_AREA_BBOX:
            return None
        try:
            min_lat, min_lng, max_lat, max_lng = (
                float(part) for part in self.SERVICE_AREA_BBOX.split(",")
            )
        except ValueError:
            raise ValueError(
                "SERVICE_AREA_BBOX must be 'min_lat,min_lng,max_lat,max_lng'"
            ) from None
        if min_lat >= max_lat or min_lng >= max_lng:
            raise ValueError("SERVICE_AREA_BBOX minimums must be below maximums")
        return min_lat, min_lng, max_lat, max_lng


settings = Settings()
