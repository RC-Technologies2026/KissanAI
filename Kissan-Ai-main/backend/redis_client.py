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


def _reset_redis():
    """Clear the cached client so the next call creates a fresh connection."""
    global _redis
    _redis = None


def _get_redis() -> Optional[Redis]:
    """Lazy-init shared Redis connection (created once, reused forever).

    Verifies the connection with PING on first use.
    If PING or any later operation fails, the client is reset so the
    next call retries with a fresh connection.
    """
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
            logger.info("Redis client created for %s:%s", REDIS_HOST, REDIS_PORT)
        except Exception as e:
            logger.error("Failed to create Redis client: %s", e)
            return None

    return _redis


async def redis_ping() -> bool:
    """PING Redis to verify connectivity. Returns True if pong received."""
    client = _get_redis()
    if client is None:
        return False
    try:
        result = await client.ping()
        if result:
            logger.info("Redis PING successful")
        else:
            logger.warning("Redis PING returned unexpected value: %s", result)
        return bool(result)
    except Exception as e:
        logger.error("Redis PING failed: %s", e)
        _reset_redis()
        return False


async def redis_set(key: str, value: str, ex: int = 900) -> bool:
    """SET key value EX seconds — returns True on success."""
    client = _get_redis()
    if client is None:
        return False
    try:
        result = await client.set(key, value, ex=ex)
        logger.info("Redis SET OK: key=%s", key)
        return bool(result)
    except Exception as e:
        logger.warning("Redis SET failed for key=%s: %s", key, e)
        _reset_redis()
        return False


async def redis_get(key: str) -> Optional[str]:
    """GET key — returns value string or None."""
    client = _get_redis()
    if client is None:
        return None
    try:
        result = await client.get(key)
        if result is not None:
            logger.info("Redis GET HIT: key=%s", key)
        else:
            logger.info("Redis GET MISS: key=%s", key)
        return result
    except Exception as e:
        logger.warning("Redis GET failed for key=%s: %s", key, e)
        _reset_redis()
        return None
