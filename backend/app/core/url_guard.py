"""Outbound URL safety checks (SSRF defence).

Hospital FHIR endpoints are supplied by admins and stored in the database. The
notification service POSTs patient pre-alerts to them, so a compromised or
careless admin account could otherwise point the backend at internal services
(``http://169.254.169.254/`` cloud metadata, ``http://redis:6379/``, a private
subnet host) and exfiltrate PHI or reach systems the backend can see but the
internet cannot.

Every outbound URL built from stored configuration must pass
:func:`assert_safe_outbound_url` before a request is made.
"""

import asyncio
import ipaddress
import socket
from urllib.parse import urlsplit

from app.core.config import settings


class UnsafeOutboundURL(ValueError):
    """Raised when a configured outbound URL must not be requested."""


def _require_allowed_scheme(scheme: str) -> None:
    # Plain HTTP would send PHI in the clear. It is tolerated only in local
    # development, where endpoints point at throwaway mock servers.
    allowed = {"https", "http"} if settings.DEBUG else {"https"}
    if scheme not in allowed:
        raise UnsafeOutboundURL(f"scheme {scheme!r} is not permitted")


def _require_allowed_host(host: str) -> None:
    allow_list = [h.strip().lower() for h in settings.FHIR_ALLOWED_HOSTS if h.strip()]
    if allow_list and host.lower() not in allow_list:
        raise UnsafeOutboundURL(f"host {host!r} is not in FHIR_ALLOWED_HOSTS")


def _require_public_address(address: str) -> None:
    try:
        ip = ipaddress.ip_address(address)
    except ValueError as exc:  # pragma: no cover - getaddrinfo always returns IPs
        raise UnsafeOutboundURL(f"unparseable address {address!r}") from exc
    # is_global excludes loopback, private, link-local (including the
    # 169.254.169.254 metadata address), reserved, multicast and unspecified
    # ranges in a single check.
    if not ip.is_global:
        raise UnsafeOutboundURL(f"address {address} is not a public address")


async def assert_safe_outbound_url(url: str) -> None:
    """Validate that ``url`` is safe for the backend to request.

    Raises :class:`UnsafeOutboundURL` when the scheme is not permitted, the host
    is outside the configured allow-list, or the host resolves to any
    non-public address.
    """
    parts = urlsplit(url)
    if not parts.scheme or not parts.hostname:
        raise UnsafeOutboundURL("URL must be absolute with a scheme and host")

    _require_allowed_scheme(parts.scheme.lower())
    _require_allowed_host(parts.hostname)

    port = parts.port or (443 if parts.scheme.lower() == "https" else 80)
    loop = asyncio.get_running_loop()
    try:
        infos = await loop.getaddrinfo(parts.hostname, port, type=socket.SOCK_STREAM)
    except socket.gaierror as exc:
        raise UnsafeOutboundURL(f"host {parts.hostname!r} does not resolve") from exc

    if not infos:
        raise UnsafeOutboundURL(f"host {parts.hostname!r} does not resolve")

    # Every resolved address must be public: a host with one public and one
    # private record must still be refused.
    for info in infos:
        _require_public_address(info[4][0])
