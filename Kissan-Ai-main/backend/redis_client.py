"""
Upstash Redis REST client.

Uses the Upstash REST API (HTTP) instead of the RESP protocol.
Expected REDIS_URL format: https://<host>:<port>
REDIS_TOKEN: Upstash REST token (from Upstash console)
"""
import httpx
import os
from typing import Optional

REDIS_URL = os.getenv("REDIS_URL", "")
REDIS_TOKEN = os.getenv("REDIS_TOKEN", "")

# Reusable async HTTP client for connection pooling
_http_client: Optional[httpx.AsyncClient] = None


def _get_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(timeout=5.0)
    return _http_client


async def redis_set(key: str, value: str, ex: int = 900) -> bool:
    """SET key value EX seconds — returns True on success."""
    if not REDIS_URL:
        return False
    try:
        client = _get_client()
        resp = await client.post(
            f"{REDIS_URL}/SET",
            json=[key, value, "EX", ex],
            headers=_headers(),
        )
        return resp.status_code == 200
    except Exception:
        return False


async def redis_get(key: str) -> Optional[str]:
    """GET key — returns value string or None."""
    if not REDIS_URL:
        return None
    try:
        client = _get_client()
        resp = await client.post(
            f"{REDIS_URL}/GET",
            json=[key],
            headers=_headers(),
        )
        if resp.status_code == 200:
            result = resp.json().get("result")
            return result
        return None
    except Exception:
        return None


def _headers() -> dict:
    headers = {"Content-Type": "application/json"}
    if REDIS_TOKEN:
        headers["Authorization"] = f"Bearer {REDIS_TOKEN}"
    return headers
