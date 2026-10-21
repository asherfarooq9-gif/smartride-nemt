"""Deploy manifests must use the env var names the app actually reads."""

import re
from pathlib import Path

import pytest

from app.core.config import Settings

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFESTS = ["render.yaml", "docker-compose.yml"]


def _env_names(text: str) -> set[str]:
    names = set(re.findall(r"^\s*-?\s*key:\s*([A-Z][A-Z0-9_]+)", text, re.M))  # render
    names |= set(re.findall(r"^\s+([A-Z][A-Z0-9_]+):\s", text, re.M))  # compose
    return names


@pytest.mark.parametrize("manifest", MANIFESTS)
def test_twilio_env_names_match_settings(manifest):
    path = REPO_ROOT / manifest
    if not path.exists():
        pytest.skip(f"{manifest} not present (running outside the repo)")
    twilio_vars = {n for n in _env_names(path.read_text()) if n.startswith("TWILIO_")}
    unknown = twilio_vars - set(Settings.model_fields)
    assert not unknown, f"{manifest} sets env vars the app ignores: {sorted(unknown)}"


def test_render_sets_allowed_origins_and_forwarded_ips():
    path = REPO_ROOT / "render.yaml"
    if not path.exists():
        pytest.skip("render.yaml not present")
    names = _env_names(path.read_text())
    # Without ALLOWED_ORIGINS the production validator rejects the default "*".
    assert "ALLOWED_ORIGINS" in names
    assert "FORWARDED_ALLOW_IPS" in names
