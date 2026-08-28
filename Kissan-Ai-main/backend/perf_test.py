"""
Lightweight performance & load test for KissanAI backend.

Usage:
    python perf_test.py                          # Run all tests
    python perf_test.py --base-url http://localhost:8000
    python perf_test.py --concurrency 10

Requires: httpx (already in requirements.txt)

Tests measure:
- /health baseline
- POST /api/auth/register + /login latency
- Protected endpoint latency with JWT
- Concurrent request handling (load test)

NOTE: Tests for /api/disease/detect, /api/pests/detect, /api/chat,
      /api/weather/current require valid credentials and external services.
      They are included but will be skipped if services are unavailable.
"""
import asyncio
import time
import statistics
import argparse
import sys
from typing import Callable, Awaitable

import httpx

# ─── Configuration ────────────────────────────────────────────────────────────

DEFAULT_BASE_URL = "http://localhost:8000"
DEFAULT_CONCURRENCY = 5
REQUEST_TIMEOUT = 30.0


# ─── Helpers ──────────────────────────────────────────────────────────────────

class TestResult:
    def __init__(self, name: str):
        self.name = name
        self.times: list[float] = []
        self.errors: list[str] = []
        self.status_codes: list[int] = []

    @property
    def count(self) -> int:
        return len(self.times)

    @property
    def avg_ms(self) -> float:
        return statistics.mean(self.times) * 1000 if self.times else 0

    @property
    def min_ms(self) -> float:
        return min(self.times) * 1000 if self.times else 0

    @property
    def max_ms(self) -> float:
        return max(self.times) * 1000 if self.times else 0

    @property
    def p95_ms(self) -> float:
        if not self.times:
            return 0
        sorted_t = sorted(self.times)
        idx = int(len(sorted_t) * 0.95)
        return sorted_t[min(idx, len(sorted_t) - 1)] * 1000

    def record(self, elapsed: float, status_code: int = 0):
        self.times.append(elapsed)
        if status_code:
            self.status_codes.append(status_code)

    def record_error(self, msg: str):
        self.errors.append(msg)

    def report(self) -> str:
        lines = [f"\n{'='*60}", f"  {self.name}", f"{'='*60}"]
        lines.append(f"  Requests:  {self.count}")
        if self.times:
            lines.append(f"  Avg:       {self.avg_ms:.1f} ms")
            lines.append(f"  Min:       {self.min_ms:.1f} ms")
            lines.append(f"  Max:       {self.max_ms:.1f} ms")
            lines.append(f"  P95:       {self.p95_ms:.1f} ms")
        if self.status_codes:
            from collections import Counter
            codes = Counter(self.status_codes)
            lines.append(f"  Status:    {dict(codes)}")
        if self.errors:
            lines.append(f"  Errors:    {len(self.errors)}")
            for e in self.errors[:3]:
                lines.append(f"    - {e}")
        lines.append("")
        return "\n".join(lines)


async def timed_request(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    result: TestResult,
    **kwargs,
) -> dict | None:
    """Make a single timed HTTP request."""
    start = time.perf_counter()
    try:
        resp = await client.request(method, url, **kwargs)
        elapsed = time.perf_counter() - start
        result.record(elapsed, resp.status_code)
        try:
            return resp.json()
        except Exception:
            return None
    except Exception as e:
        elapsed = time.perf_counter() - start
        result.record(elapsed, 0)
        result.record_error(str(e)[:120])
        return None


async def concurrent_requests(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    result: TestResult,
    concurrency: int,
    **kwargs,
):
    """Fire N concurrent requests."""
    tasks = [
        timed_request(client, method, url, result, **kwargs)
        for _ in range(concurrency)
    ]
    await asyncio.gather(*tasks)


# ─── Test Suite ───────────────────────────────────────────────────────────────

async def run_tests(base_url: str, concurrency: int):
    results: list[TestResult] = []

    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:

        # --- 1. Health check (baseline) ---
        r = TestResult("GET /health (baseline)")
        await concurrent_requests(client, "GET", f"{base_url}/health", r, concurrency)
        results.append(r)

        # --- 2. Auth: Register ---
        r = TestResult("POST /api/auth/register")
        import random
        email = f"perf_test_{random.randint(1000,9999)}@test.com"
        await timed_request(
            client, "POST", f"{base_url}/api/auth/register", r,
            json={"email": email, "password": "TestPass123!", "full_name": "Perf Test"},
        )
        results.append(r)

        # --- 3. Auth: Login ---
        r = TestResult("POST /api/auth/login")
        login_data = await timed_request(
            client, "POST", f"{base_url}/api/auth/login", r,
            json={"email": email, "password": "TestPass123!"},
        )
        results.append(r)

        # Extract JWT token
        token = None
        if login_data and "access_token" in login_data:
            token = login_data["access_token"]
        headers = {"Authorization": f"Bearer {token}"} if token else {}

        # --- 4. Protected endpoint: Weather (cache MISS) ---
        r = TestResult("GET /api/weather/current (cache MISS)")
        if token:
            await timed_request(
                client, "GET", f"{base_url}/api/weather/current", r,
                params={"lat": 31.5497, "lon": 74.3436},
                headers=headers,
            )
        else:
            r.record_error("No JWT token — skipped")
        results.append(r)

        # --- 5. Protected endpoint: Weather (cache HIT) ---
        r = TestResult("GET /api/weather/current (cache HIT)")
        if token:
            await timed_request(
                client, "GET", f"{base_url}/api/weather/current", r,
                params={"lat": 31.5497, "lon": 74.3436},
                headers=headers,
            )
        else:
            r.record_error("No JWT token — skipped")
        results.append(r)

        # --- 6. Auth: Login (concurrent load test) ---
        r = TestResult(f"POST /api/auth/login (concurrent x{concurrency})")
        if token:
            await concurrent_requests(
                client, "POST", f"{base_url}/api/auth/login", r, concurrency,
                json={"email": email, "password": "TestPass123!"},
            )
        results.append(r)

        # --- 7. Health (concurrent load test) ---
        r = TestResult(f"GET /health (concurrent x{concurrency * 4})")
        await concurrent_requests(
            client, "GET", f"{base_url}/health", r, concurrency * 4,
        )
        results.append(r)

        # --- 8. Protected: History (concurrent) ---
        r = TestResult(f"GET /api/history (concurrent x{concurrency})")
        if token:
            await concurrent_requests(
                client, "GET", f"{base_url}/api/history", r, concurrency,
                headers=headers,
            )
        results.append(r)

        # --- 9. Disease detect (cold start — model may need loading) ---
        r = TestResult("POST /api/disease/detect (cold, needs image)")
        if token:
            # Create a minimal valid JPEG in memory
            import io
            try:
                from PIL import Image
                img = Image.new("RGB", (224, 224), color="green")
                buf = io.BytesIO()
                img.save(buf, format="JPEG")
                buf.seek(0)
                await timed_request(
                    client, "POST", f"{base_url}/api/disease/detect", r,
                    files={"file": ("test.jpg", buf, "image/jpeg")},
                    headers=headers,
                )
            except ImportError:
                r.record_error("Pillow not available — skipped")
        else:
            r.record_error("No JWT token — skipped")
        results.append(r)

        # --- 10. Disease detect (warm — model already loaded) ---
        r = TestResult("POST /api/disease/detect (warm)")
        if token:
            try:
                from PIL import Image
                img = Image.new("RGB", (224, 224), color="red")
                buf = io.BytesIO()
                img.save(buf, format="JPEG")
                buf.seek(0)
                await timed_request(
                    client, "POST", f"{base_url}/api/disease/detect", r,
                    files={"file": ("test.jpg", buf, "image/jpeg")},
                    headers=headers,
                )
            except ImportError:
                r.record_error("Pillow not available — skipped")
        else:
            r.record_error("No JWT token — skipped")
        results.append(r)

    # ─── Print Report ─────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  KISSANAI BACKEND — PERFORMANCE TEST REPORT")
    print("=" * 60)
    print(f"  Base URL:    {base_url}")
    print(f"  Concurrency: {concurrency}")
    print(f"  Timestamp:   {time.strftime('%Y-%m-%d %H:%M:%S')}")

    for r in results:
        print(r.report())

    # Summary
    print("=" * 60)
    print("  SUMMARY")
    print("=" * 60)
    total_errors = sum(len(r.errors) for r in results)
    total_requests = sum(r.count for r in results)
    print(f"  Total requests: {total_requests}")
    print(f"  Total errors:   {total_errors}")

    health_results = [r for r in results if "/health" in r.name and "concurrent" not in r.name]
    if health_results and health_results[0].avg_ms > 0:
        print(f"  Health avg:     {health_results[0].avg_ms:.1f} ms")

    auth_results = [r for r in results if "login" in r.name and "concurrent" not in r.name]
    if auth_results and auth_results[0].avg_ms > 0:
        print(f"  Login avg:      {auth_results[0].avg_ms:.1f} ms")

    detect_warm = [r for r in results if "detect (warm)" in r.name]
    if detect_warm and detect_warm[0].avg_ms > 0:
        print(f"  Disease detect (warm): {detect_warm[0].avg_ms:.1f} ms")

    detect_cold = [r for r in results if "detect (cold" in r.name]
    if detect_cold and detect_cold[0].avg_ms > 0:
        print(f"  Disease detect (cold): {detect_cold[0].avg_ms:.1f} ms")

    cache_hit = [r for r in results if "cache HIT" in r.name]
    cache_miss = [r for r in results if "cache MISS" in r.name]
    if cache_hit and cache_hit[0].avg_ms > 0:
        print(f"  Weather (cache HIT):  {cache_hit[0].avg_ms:.1f} ms")
    if cache_miss and cache_miss[0].avg_ms > 0:
        print(f"  Weather (cache MISS): {cache_miss[0].avg_ms:.1f} ms")

    print("")
    return results


# ─── Entry Point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KissanAI Performance Test")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="Backend URL")
    parser.add_argument("--concurrency", type=int, default=DEFAULT_CONCURRENCY, help="Concurrent requests")
    args = parser.parse_args()

    print(f"\nStarting performance tests against {args.base_url} ...")
    print(f"Concurrency: {args.concurrency}\n")

    asyncio.run(run_tests(args.base_url, args.concurrency))
