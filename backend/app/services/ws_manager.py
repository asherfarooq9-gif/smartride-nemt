"""
WebSocket location manager.
Uses Redis pub/sub so multiple backend instances can forward driver GPS to
all connected patients watching the same ride.
"""

import asyncio
import contextlib
import json
from typing import Optional
import redis.asyncio as aioredis
from redis.exceptions import RedisError

from app.core.config import settings

# Bounds how long a Redis blip can stall the GPS stream. Reads of the pub/sub
# stream itself are bounded by the caller's get_message(timeout=...).
REDIS_OP_TIMEOUT_SECONDS = 2.0


class LocationManager:
    def __init__(self) -> None:
        self._redis: Optional[aioredis.Redis] = None

    async def _get_redis(self) -> aioredis.Redis:
        if self._redis is None:
            self._redis = aioredis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=REDIS_OP_TIMEOUT_SECONDS,
            )
        return self._redis

    def _channel(self, ride_id: str) -> str:
        return f"ride:{ride_id}:location"

    async def publish(self, ride_id: str, lat: float, lng: float) -> None:
        r = await self._get_redis()
        await asyncio.wait_for(
            r.publish(self._channel(ride_id), json.dumps({"lat": lat, "lng": lng})),
            timeout=REDIS_OP_TIMEOUT_SECONDS,
        )

    async def subscribe(self, ride_id: str) -> aioredis.client.PubSub:
        r = await self._get_redis()
        pubsub = r.pubsub()
        try:
            await asyncio.wait_for(
                pubsub.subscribe(self._channel(ride_id)),
                timeout=REDIS_OP_TIMEOUT_SECONDS,
            )
        except BaseException:
            # Do not leak the half-open connection when the subscribe fails.
            with contextlib.suppress(RedisError, OSError, asyncio.TimeoutError):
                await pubsub.aclose()
            raise
        return pubsub

    async def close(self) -> None:
        if self._redis:
            await self._redis.aclose()
            self._redis = None


location_manager = LocationManager()
