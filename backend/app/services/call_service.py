"""Internet calls: relay credentials, signalling checks, and the ring push.

The audio never passes through this server. It hands out short-lived credentials
for our coturn relay and passes call set-up messages between the two people on a
live ride; the chat's rule decides who they are and when a call may happen.
"""

import base64
import hashlib
import hmac
import logging
import time

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services.chat_service import ChatAccess
from app.services.notifications import notify_user

log = logging.getLogger("smartride.call")

CALL_TYPES = frozenset(
    {"invite", "accept", "decline", "offer", "answer", "hangup", "ice"}
)
MAX_SDP_LENGTH = 20_000
MAX_CANDIDATE_LENGTH = 2_000
MAX_MID_LENGTH = 64
MAX_MLINE_INDEX = 64


def ice_servers(user_id: str, now: float | None = None) -> dict:
    """STUN and TURN servers for one person, with a TURN login that expires.

    coturn's "REST API" scheme: the username is the expiry time and the user,
    the password is an HMAC of it, so nothing is stored and a leaked login stops
    working within TURN_TTL_SECONDS. With no relay configured the list is empty.
    """
    ttl = settings.TURN_TTL_SECONDS
    servers: list[dict] = []
    if settings.TURN_URLS and settings.TURN_SECRET:
        if settings.STUN_URLS:
            servers.append({"urls": list(settings.STUN_URLS)})
        expires = int((time.time() if now is None else now) + ttl)
        username = f"{expires}:{user_id}"
        digest = hmac.new(
            settings.TURN_SECRET.encode(), username.encode(), hashlib.sha1
        ).digest()
        servers.append(
            {
                "urls": list(settings.TURN_URLS),
                "username": username,
                "credential": base64.b64encode(digest).decode(),
            }
        )
    return {"ice_servers": servers, "ttl_seconds": ttl}


def _text(value, limit: int, allow_empty: bool = False) -> str | None:
    if not isinstance(value, str) or len(value) > limit:
        return None
    return value if value or allow_empty else None


def _candidate(value) -> dict | None:
    if not isinstance(value, dict):
        return None
    # An empty candidate string is how a browser says "no more candidates".
    line = _text(value.get("candidate"), MAX_CANDIDATE_LENGTH, allow_empty=True)
    if line is None:
        return None
    clean: dict = {"candidate": line}
    mid = value.get("sdpMid")
    if mid is not None:
        if _text(mid, MAX_MID_LENGTH, allow_empty=True) is None:
            return None
        clean["sdpMid"] = mid
    index = value.get("sdpMLineIndex")
    if index is not None:
        if (
            isinstance(index, bool)
            or not isinstance(index, int)
            or not 0 <= index <= MAX_MLINE_INDEX
        ):
            return None
        clean["sdpMLineIndex"] = index
    return clean


def sanitize_signal(data) -> dict | None:
    """The call message to pass on, rebuilt from known fields only, or None.

    Nothing the sender adds survives, including who it claims to be from: the
    server sets that from the connection.
    """
    if not isinstance(data, dict) or data.get("type") not in CALL_TYPES:
        return None
    kind = data["type"]
    if kind in ("offer", "answer"):
        sdp = _text(data.get("sdp"), MAX_SDP_LENGTH)
        return None if sdp is None else {"type": kind, "sdp": sdp}
    if kind == "ice":
        candidate = _candidate(data.get("candidate"))
        return None if candidate is None else {"type": kind, "candidate": candidate}
    return {"type": kind}


async def ring_other_side(db: AsyncSession, access: ChatAccess) -> None:
    """Push "incoming call" when the other person has no open app to ring.
    Never raises, and says nothing about health."""
    if access.other_user_id is None:
        return
    who = "driver" if access.role == "driver" else "patient"
    try:
        await notify_user(
            db,
            user_id=access.other_user_id,
            title="Incoming call",
            body=f"Your {who} is calling. Open SmartRide to answer.",
            data={"ride_id": str(access.ride.id), "type": "call"},
        )
    except Exception as exc:  # noqa: BLE001 - a lost push must not break the call
        log.warning(
            "call push not sent ride_id=%s (%s)", access.ride.id, type(exc).__name__
        )
