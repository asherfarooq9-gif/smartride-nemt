"""Error tracking (Sentry) — initialised only when a DSN is configured.

No-op without SENTRY_DSN, so local development and CI never phone home.
PHI safety: send_default_pii stays False and a before_send scrubs the
Authorization header so tokens never reach Sentry.
"""

import logging

from app.core.config import settings

log = logging.getLogger("smartride.observability")


def _scrub(event: dict, _hint: dict) -> dict:
    # Defence in depth: strip auth headers before anything leaves the process.
    try:
        headers = event.get("request", {}).get("headers")
        if isinstance(headers, dict):
            for key in list(headers):
                if key.lower() in ("authorization", "cookie"):
                    headers[key] = "[redacted]"
    except Exception:
        pass
    return event


def init_error_tracking() -> bool:
    """Returns True if Sentry was initialised, False if it's a no-op."""
    if not settings.SENTRY_DSN:
        log.info("Sentry disabled (no SENTRY_DSN).")
        return False
    try:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
            send_default_pii=False,
            before_send=_scrub,
        )
        log.info("Sentry initialised for environment=%s", settings.ENVIRONMENT)
        return True
    except Exception as exc:  # never let telemetry setup break startup
        log.warning("Sentry init failed: %s", type(exc).__name__)
        return False
