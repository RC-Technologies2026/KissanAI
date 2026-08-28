"""
Redis Cloud client for weather cache.

Uses redis.asyncio (redis-py) with RESP protocol over TLS.
Connects to Redis Cloud public endpoint via:
  REDIS_HOST, REDIS_PORT, REDIS_USERNAME, REDIS_PASSWORD
"""
import os
import logging
from typing import Optional

from redis.asyncio import Redis

logger = logging.getLogger("kissanai.redis")

REDIS_HOST = os.getenv("REDIS_HOST", "")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_USERNAME = os.getenv("REDIS_USERNAME", "")
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")

# Reusable async Redis client with connection pooling
_redis: Optional[Redis] = None


def _get_redis() -> Optional[Redis]:
    """Lazy-init shared Redis connection (created once, reused forever)."""
    global _redis
    if _redis is None:
        if not REDIS_HOST:
            logger.warning("REDIS_HOST not set — Redis cache disabled")
            return None
        try:
            _redis = Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                username=REDIS_USERNAME or None,
                password=REDIS_PASSWORD or None,
                ssl=True,
                decode_responses=True,
                socket_timeout=5.0,
                socket_connect_timeout=5.0,
                retry_on_timeout=True,
                health_check_interval=30,
            )
            logger.info("Redis client configured: %s:%s", REDIS_HOST, REDIS_PORT)
        except Exception as e:
            logger.error("Failed to create Redis client: %s", e)
            return None
    return _redis


async def redis_set(key: str, value: str, ex: int = 900) -> bool:
    """SET key value EX seconds — returns True on success."""
    client = _get_redis()
    if client is None:
        return False
    try:
        return await client.set(key, value, ex=ex)
    except Exception as e:
        logger.warning("Redis SET failed for key=%s: %s", key, e)
        return False


async def redis_get(key: str) -> Optional[str]:
    """GET key — returns value string or None."""
    client = _get_redis()
    if client is None:
        return None
    try:
        return await client.get(key)
    except Exception as e:
        logger.warning("Redis GET failed for key=%s: %s", key, e)
        return None
