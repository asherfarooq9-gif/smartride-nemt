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

    def _chat_channel(self, ride_id: str) -> str:
        return f"ride:{ride_id}:chat"

    async def publish_chat(self, ride_id: str, payload: dict) -> None:
        """Hand a chat message to everyone listening on this ride's chat."""
        r = await self._get_redis()
        await asyncio.wait_for(
            r.publish(self._chat_channel(ride_id), json.dumps(payload)),
            timeout=REDIS_OP_TIMEOUT_SECONDS,
        )

    def _call_channel(self, ride_id: str, role: str) -> str:
        return f"ride:{ride_id}:call:{role}"

    async def publish_call(self, ride_id: str, role: str, payload: dict) -> int:
        """Send a call message to one side. Returns how many sockets heard it, so a
        caller can tell the other person's app is not open."""
        r = await self._get_redis()
        return await asyncio.wait_for(
            r.publish(self._call_channel(ride_id, role), json.dumps(payload)),
            timeout=REDIS_OP_TIMEOUT_SECONDS,
        )

    async def subscribe_call(self, ride_id: str, role: str) -> aioredis.client.PubSub:
        return await self._subscribe(self._call_channel(ride_id, role))

    async def subscribe(self, ride_id: str) -> aioredis.client.PubSub:
        return await self._subscribe(self._channel(ride_id))

    async def subscribe_chat(self, ride_id: str) -> aioredis.client.PubSub:
        return await self._subscribe(self._chat_channel(ride_id))

    async def _subscribe(self, channel: str) -> aioredis.client.PubSub:
        r = await self._get_redis()
        pubsub = r.pubsub()
        try:
            await asyncio.wait_for(
                pubsub.subscribe(channel),
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
