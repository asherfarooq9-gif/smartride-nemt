"""SSRF guard for admin-supplied outbound URLs (hospital FHIR endpoints)."""

import pytest

from app.core.config import settings
from app.core.url_guard import UnsafeOutboundURL, assert_safe_outbound_url


@pytest.mark.asyncio
async def test_public_https_address_is_allowed():
    # A literal public IP so the check never depends on network DNS.
    await assert_safe_outbound_url("https://8.8.8.8/fhir")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url",
    [
        "https://127.0.0.1/fhir",  # loopback
        "https://10.0.0.5/fhir",  # RFC1918 private
        "https://192.168.1.10/fhir",  # RFC1918 private
        "https://169.254.169.254/latest/meta-data/",  # cloud metadata
        "https://[::1]/fhir",  # IPv6 loopback
    ],
)
async def test_non_public_addresses_are_refused(url: str):
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url(url)


@pytest.mark.asyncio
async def test_internal_hostname_is_refused():
    """A hostname resolving to a private address must be refused, not just a
    literal private IP — this is how an internal service would be reached."""
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url("https://localhost:6379/")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url",
    ["file:///etc/passwd", "gopher://8.8.8.8/", "ftp://8.8.8.8/fhir"],
)
async def test_non_http_schemes_are_refused(url: str):
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url(url)


@pytest.mark.asyncio
async def test_relative_url_is_refused():
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url("/fhir/Bundle")


@pytest.mark.asyncio
async def test_plain_http_is_refused_outside_debug(monkeypatch):
    """PHI must not leave over cleartext HTTP in production."""
    monkeypatch.setattr(settings, "DEBUG", False)
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url("http://8.8.8.8/fhir")


@pytest.mark.asyncio
async def test_allow_list_rejects_unlisted_host(monkeypatch):
    monkeypatch.setattr(settings, "FHIR_ALLOWED_HOSTS", ["fhir.approved.example"])
    with pytest.raises(UnsafeOutboundURL):
        await assert_safe_outbound_url("https://8.8.8.8/fhir")


@pytest.mark.asyncio
async def test_empty_allow_list_permits_any_public_host(monkeypatch):
    monkeypatch.setattr(settings, "FHIR_ALLOWED_HOSTS", [])
    await assert_safe_outbound_url("https://8.8.8.8/fhir")
