"""
Redis client for weather + plots cache.

Connection is configured via either:
  REDIS_URL  — full connection string (Render injects this automatically:
               redis://user:pass@host:80  or  rediss://... for TLS)
  or discrete Redis Cloud variables:
  REDIS_HOST, REDIS_PORT, REDIS_USERNAME, REDIS_PASSWORD
"""
import os
import json
import logging
from typing import Any, Optional

from redis.asyncio import Redis

logger = logging.getLogger("kissanai.redis")

REDIS_URL = os.getenv("REDIS_URL", "")
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

    Priority: REDIS_URL > REDIS_HOST/PORT.  If PING or any later operation
    fails, the client is reset so the next call retries with a fresh
    connection.
    """
    global _redis
    if _redis is None:
        common = dict(
            decode_responses=True,
            socket_timeout=5.0,
            socket_connect_timeout=5.0,
            retry_on_timeout=True,
            health_check_interval=30,
        )
        try:
            if REDIS_URL:
                # from_url() parses scheme (redis:// plain, rediss:// TLS)
                # and embedded credentials automatically.
                _redis = Redis.from_url(REDIS_URL, **common)
                endpoint = REDIS_URL.split("@")[-1]
            elif REDIS_HOST:
                _redis = Redis(
                    host=REDIS_HOST,
                    port=REDIS_PORT,
                    username=REDIS_USERNAME or None,
                    password=REDIS_PASSWORD or None,
                    ssl=False,
                    **common,
                )
                endpoint = f"{REDIS_HOST}:{REDIS_PORT}"
            else:
                logger.warning("Neither REDIS_URL nor REDIS_HOST set — cache disabled")
                return None
            logger.info("Redis client created for %s", endpoint)
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


async def redis_delete(*keys: str) -> int:
    """DEL key [key ...] — returns number of keys removed (0 on failure)."""
    if not keys:
        return 0
    client = _get_redis()
    if client is None:
        return 0
    try:
        removed = await client.delete(*keys)
        logger.info("Redis DEL: %s key(s) removed", removed)
        return int(removed)
    except Exception as e:
        logger.warning("Redis DEL failed for keys=%s: %s", keys, e)
        _reset_redis()
        return 0


async def cache_get_json(key: str) -> Optional[Any]:
    """GET key and JSON-decode it.  Returns None on miss or corrupt payload."""
    raw = await redis_get(key)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.warning("Bad JSON in cache key=%s — evicting", key)
        await redis_delete(key)
        return None


async def cache_set_json(key: str, value: Any, ex: int = 600) -> bool:
    """JSON-encode value and SET key with TTL (default 10 min)."""
    try:
        payload = json.dumps(value, default=str)
    except (TypeError, ValueError) as e:
        logger.warning("Cannot serialize value for key=%s: %s", key, e)
        return False
    return await redis_set(key, payload, ex=ex)
