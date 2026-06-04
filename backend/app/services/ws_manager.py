"""
WebSocket location manager.
Uses Redis pub/sub so multiple backend instances can forward driver GPS to
all connected patients watching the same ride.
"""

import json
from typing import Optional
import redis.asyncio as aioredis

from app.core.config import settings


class LocationManager:
    def __init__(self) -> None:
        self._redis: Optional[aioredis.Redis] = None

    async def _get_redis(self) -> aioredis.Redis:
        if self._redis is None:
            self._redis = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        return self._redis

    def _channel(self, ride_id: str) -> str:
        return f"ride:{ride_id}:location"

    async def publish(self, ride_id: str, lat: float, lng: float) -> None:
        r = await self._get_redis()
        await r.publish(self._channel(ride_id), json.dumps({"lat": lat, "lng": lng}))

    async def subscribe(self, ride_id: str) -> aioredis.client.PubSub:
        r = await self._get_redis()
        pubsub = r.pubsub()
        await pubsub.subscribe(self._channel(ride_id))
        return pubsub

    async def close(self) -> None:
        if self._redis:
            await self._redis.aclose()
            self._redis = None


location_manager = LocationManager()
