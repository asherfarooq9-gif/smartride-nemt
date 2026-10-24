"""Idempotency-Key support for emergency ride creation.

A client that retries a create (double tap, timeout then retry) sends the same
Idempotency-Key; we remember which ride the first request produced so the retry
gets that ride back. The mapping lives in Redis for a short TTL and the whole
feature fails open: if Redis is down the key is ignored and the one-active-
emergency-ride-per-patient rule still prevents duplicates.
"""

import asyncio
import hashlib
import json
import logging
import re
from typing import Optional

from fastapi import HTTPException
from pydantic import BaseModel
from redis.exceptions import RedisError

from app.core.redis_client import get_redis

log = logging.getLogger("smartride.idempotency")

IDEMPOTENCY_TTL_SECONDS = 300
_KEY_PATTERN = re.compile(r"^[A-Za-z0-9_.:\-]{1,128}$")
_REDIS_ERRORS = (RedisError, OSError, asyncio.TimeoutError)


def validate_key(raw: Optional[str]) -> Optional[str]:
    """Return the key, None when absent, or raise 400 for a malformed one."""
    if raw is None:
        return None
    if not _KEY_PATTERN.match(raw):
        raise HTTPException(
            400, "Idempotency-Key must be 1-128 characters: letters, digits, _ . : -"
        )
    return raw


def _redis_key(scope: str, patient_id, key: str) -> str:
    return f"idem:{scope}:{patient_id}:{key}"


def fingerprint(body: BaseModel) -> str:
    """Stable digest of a request body, to tell a true retry from key reuse."""
    canonical = json.dumps(
        body.model_dump(mode="json"), sort_keys=True, separators=(",", ":")
    )
    return hashlib.sha256(canonical.encode()).hexdigest()[:32]


async def recall(
    scope: str, patient_id, key: str
) -> Optional[tuple[str, Optional[str]]]:
    """(ride id, body fingerprint) stored for this key, or None.

    None also covers Redis being down. The fingerprint is None for entries
    written without one.
    """
    try:
        r = await get_redis()
        raw = await r.get(_redis_key(scope, patient_id, key))
    except _REDIS_ERRORS:
        log.warning("Idempotency lookup failed; ignoring key", exc_info=True)
        return None
    if not raw:
        return None
    ride_id, _, stored_fingerprint = raw.partition(":")
    return ride_id, stored_fingerprint or None


async def remember(
    scope: str,
    patient_id,
    key: str,
    ride_id,
    body_fingerprint: Optional[str] = None,
) -> None:
    value = f"{ride_id}:{body_fingerprint}" if body_fingerprint else str(ride_id)
    try:
        r = await get_redis()
        await r.set(
            _redis_key(scope, patient_id, key),
            value,
            ex=IDEMPOTENCY_TTL_SECONDS,
            nx=True,
        )
    except _REDIS_ERRORS:
        log.warning("Idempotency key not stored (redis error)", exc_info=True)
