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


def _forwarded_allow_ips(manifest: str) -> str:
    text = (REPO_ROOT / manifest).read_text()
    match = re.search(
        r'key:\s*FORWARDED_ALLOW_IPS\s*\n\s*value:\s*"([^"]*)"', text, re.M
    )
    assert match, f"{manifest} does not set FORWARDED_ALLOW_IPS to a literal value"
    return match.group(1)


def test_render_does_not_trust_every_forwarded_for_value():
    """A wildcard makes uvicorn take the left-most X-Forwarded-For entry, which the client
    writes (Render appends to it). That defeats the IP rate limits and the login
    lockout, so trust only the proxy's own address range."""
    if not (REPO_ROOT / "render.yaml").exists():
        pytest.skip("render.yaml not present")
    assert _forwarded_allow_ips("render.yaml").strip() != "*"


def test_render_trusted_proxies_ignore_a_spoofed_forwarded_for():
    from uvicorn.middleware.proxy_headers import _TrustedHosts

    if not (REPO_ROOT / "render.yaml").exists():
        pytest.skip("render.yaml not present")
    trusted = _TrustedHosts(_forwarded_allow_ips("render.yaml"))

    # The client sent "1.2.3.4"; Render appended the real client, 203.0.113.9.
    spoofed = "1.2.3.4, 203.0.113.9"
    host, _ = trusted.get_trusted_client_address(spoofed)

    assert host == "203.0.113.9"


def test_render_does_not_overwrite_twilio_secrets_on_sync():
    """A literal "" is re-applied on every blueprint sync and would wipe the secret
    set in the Render dashboard, silently turning SMS off. `sync: false` leaves it."""
    if not (REPO_ROOT / "render.yaml").exists():
        pytest.skip("render.yaml not present")
    text = (REPO_ROOT / "render.yaml").read_text()
    for name in ("TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_FROM_NUMBER"):
        block = re.search(rf"key:\s*{name}\s*\n\s*(\S[^\n]*)", text)
        assert block, f"{name} missing from render.yaml"
        assert block.group(1).startswith("sync: false"), f"{name} must be sync: false"


def test_every_setting_is_documented_in_env_example():
    """A variable that exists only in config.py cannot be found by whoever deploys."""
    path = REPO_ROOT / ".env.example"
    if not path.exists():
        pytest.skip(".env.example not present (running outside the repo)")
    documented = set(re.findall(r"^\s*#?\s*([A-Z][A-Z0-9_]+)=", path.read_text(), re.M))
    missing = sorted(set(Settings.model_fields) - documented)
    assert not missing, f".env.example does not mention: {missing}"


def test_release_waits_for_green_ci():
    """A tag push must not build and publish an APK from a commit CI has not passed."""
    path = REPO_ROOT / ".github" / "workflows" / "release.yml"
    if not path.exists():
        pytest.skip("release.yml not present (running outside the repo)")
    text = path.read_text()
    assert re.search(r"^\s+require-green-ci:", text, re.M), "no CI gate job"
    build = text[text.index("build-release-apks:") :]
    assert re.search(r"needs:\s*\[?\s*require-green-ci", build), (
        "the build job must depend on the CI gate"
    )


def test_render_checks_readiness_not_just_liveness():
    """/health always answers 200, so a new instance with no database would still
    receive traffic. Render's check is the deploy gate, so it must be /ready."""
    if not (REPO_ROOT / "render.yaml").exists():
        pytest.skip("render.yaml not present")
    text = (REPO_ROOT / "render.yaml").read_text()
    assert re.search(r"healthCheckPath:\s*/ready\b", text)
