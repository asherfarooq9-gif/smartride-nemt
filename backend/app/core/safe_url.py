"""SSRF defence for URLs an admin supplies and the server later calls.

Two layers, because a hostname can be harmless when saved and point at an
internal address when used (DNS rebinding, wildcard DNS such as 127.0.0.1.nip.io):

- check_public_hostname_url: cheap, no DNS. Run at validation time.
- resolve_public_ip: run at SEND time. Resolves the host and rejects every
  non-global address; the caller connects to the returned IP so the address
  that was checked is the address that is used.
"""

import asyncio
import ipaddress
import re
import socket
from urllib.parse import urlsplit

DNS_TIMEOUT_SECONDS = 3.0

# The URL standard parses a host whose last label is numeric (2130706433, 127.1,
# 0x7f000001, 0177.0.0.1) as an IPv4 address, so none of those may pass as a name.
_NUMERIC_LABEL = re.compile(r"^(0x[0-9a-f]*|[0-9]+)$", re.IGNORECASE)
_INTERNAL_SUFFIXES = (".local", ".internal", ".localhost", ".localdomain", ".lan")

_NAT64 = ipaddress.ip_network("64:ff9b::/96")
_SIX_TO_FOUR = ipaddress.ip_network("2002::/16")


class UnsafeUrlError(ValueError):
    """The URL targets, or resolves to, an address the server must not call."""


def check_public_hostname_url(value: str, *, schemes: tuple[str, ...]) -> str:
    """Syntax-only check. Rejects bad schemes, IP literals in any notation and
    obviously internal names; returns the value unchanged."""
    parts = urlsplit(value)
    host = (parts.hostname or "").rstrip(".")
    if parts.scheme not in schemes or not host:
        raise UnsafeUrlError(f"URL must use {' or '.join(schemes)} and include a host")
    if parts.username is not None or parts.password is not None:
        raise UnsafeUrlError("URL must not contain credentials")
    _ = parts.port  # raises ValueError on a malformed port
    if host == "localhost" or host.endswith(_INTERNAL_SUFFIXES):
        raise UnsafeUrlError("URL must point at a public host")
    if _is_ip_literal(host) or _NUMERIC_LABEL.match(host.rsplit(".", 1)[-1]):
        raise UnsafeUrlError("URL must use a DNS hostname, not an IP address")
    return value


def _is_ip_literal(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
    except ValueError:
        return False
    return True


def _embedded_ipv4(ip: ipaddress.IPv6Address) -> ipaddress.IPv4Address | None:
    if ip.ipv4_mapped:
        return ip.ipv4_mapped
    if ip in _NAT64:
        return ipaddress.IPv4Address(int(ip) & 0xFFFFFFFF)
    if ip in _SIX_TO_FOUR:
        return ipaddress.IPv4Address((int(ip) >> 80) & 0xFFFFFFFF)
    if ip.teredo:
        return ip.teredo[1]
    return None


def is_public_address(raw: str) -> bool:
    """True only for a globally routable unicast address (IPv4 or IPv6)."""
    ip = ipaddress.ip_address(raw.split("%", 1)[0])
    if isinstance(ip, ipaddress.IPv6Address):
        embedded = _embedded_ipv4(ip)
        if embedded is not None and not is_public_address(str(embedded)):
            return False
    return not (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
        or not ip.is_global
    )


async def resolve_public_ip(host: str, port: int) -> str:
    """Resolve `host`; return one address only if EVERY answer is public."""
    loop = asyncio.get_running_loop()
    try:
        infos = await asyncio.wait_for(
            loop.getaddrinfo(host, port, type=socket.SOCK_STREAM), DNS_TIMEOUT_SECONDS
        )
    except (socket.gaierror, asyncio.TimeoutError, UnicodeError) as exc:
        raise UnsafeUrlError(f"could not resolve host ({type(exc).__name__})") from exc
    addresses = [info[4][0] for info in infos]
    if not addresses:
        raise UnsafeUrlError("host did not resolve")
    for address in addresses:
        if not is_public_address(address):
            raise UnsafeUrlError("host resolves to a non-public address")
    return addresses[0]
