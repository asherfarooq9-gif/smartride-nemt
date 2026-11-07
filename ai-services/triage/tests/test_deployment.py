"""How the service is run matters as much as what it answers."""

import inspect
import re
from pathlib import Path

from main import app

ROOT = Path(__file__).resolve().parents[3]


def test_the_triage_handler_does_not_run_cpu_work_on_the_event_loop():
    """Matching a few hundred regexes is CPU-bound. In an `async def` it would hold
    the only event loop and make /health and every other request wait behind it;
    a plain `def` runs in FastAPI's threadpool."""
    handler = next(r.endpoint for r in app.routes if getattr(r, "path", "") == "/triage")

    assert not inspect.iscoroutinefunction(handler)


def test_the_container_limits_concurrency():
    dockerfile = (Path(__file__).resolve().parents[1] / "Dockerfile").read_text(
        encoding="utf-8"
    )

    assert re.search(r"--limit-concurrency[\"',\s]+\d+", dockerfile)


def test_compose_does_not_configure_things_the_service_never_reads():
    compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
    triage = compose[compose.index("  triage:") : compose.index("  admin_dashboard:")]

    assert "MODEL_PATH" not in triage
    assert "REDIS_URL" not in triage
    assert "triage_model" not in compose
