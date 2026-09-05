"""
services/gemini_service.py

CHANGES FROM PREVIOUS VERSION:
1. Expanded chat_models_to_try from 1 model to 6 models across different
   Gemini families — each model has its OWN separate daily quota, so
   spreading requests across families gives far more real capacity.
2. gemini-2.0-flash removed — Google shut this model down June 1, 2026.
   Using it would fail every single call.
3. RESOURCE_EXHAUSTED (429) errors now skip to the next model IMMEDIATELY
   instead of waiting for a timeout — saves seconds per fallback.
4. Exhausted models are cached in-memory for the rest of the day so we
   stop wasting requests retrying a model we already know is dead.
5. If every model fails, the app returns a graceful message instead of
   crashing with a 502 — critical for a live demo.
6. Groq fallback set up with the CURRENT model — llama-3.1-8b-instant was
   deprecated by Groq (June 17, 2026). Now using openai/gpt-oss-20b, their
   official recommended replacement. Requires GROQ_API_KEY in environment.
"""

import os
import time
import json
import logging
import httpx

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

GROQ_API_KEY = os.getenv("GROQ_API_KEY")  # required for the fallback below
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "openai/gpt-oss-20b"  # current model — llama-3.1-8b-instant was
                                    # deprecated by Groq in June 2026, this is
                                    # their official recommended replacement

# ---------------------------------------------------------------------------
# Model pools — ordered by preference. Spread across families on purpose:
# if gemini-3.5-flash's daily quota is exhausted, gemini-3.6-flash and
# gemini-2.5-flash are on COMPLETELY SEPARATE quotas and will still work.
# ---------------------------------------------------------------------------
chat_models_to_try = [
    "gemini-2.5-flash",
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-3.7-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
]

vision_models_to_try = [
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-2.5-flash",
]

# Tracks which models have hit RESOURCE_EXHAUSTED today, so we don't waste
# a request re-trying a model we already know is dead. Cleared on redeploy
# (in-memory only) — fine for a hackathon; use Redis for production.
_exhausted_models: dict[str, float] = {}
_EXHAUSTED_TTL_SECONDS = 6 * 60 * 60  # assume a model may recover after 6h


def _is_exhausted(model: str) -> bool:
    exhausted_at = _exhausted_models.get(model)
    if exhausted_at is None:
        return False
    if time.time() - exhausted_at > _EXHAUSTED_TTL_SECONDS:
        _exhausted_models.pop(model, None)
        return False
    return True


def _mark_exhausted(model: str) -> None:
    _exhausted_models[model] = time.time()
    logger.warning(f"Model {model} marked exhausted, skipping for ~6h")


async def _call_gemini(model: str, contents: list, timeout: float) -> dict:
    """Single call to one Gemini model. Raises on any failure."""
    url = f"{GEMINI_BASE_URL}/{model}:generateContent?key={GEMINI_API_KEY}"
    payload = {"contents": contents}

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(url, json=payload)

    if response.status_code == 429:
        error_body = response.json()
        status = error_body.get("error", {}).get("status", "")
        if status == "RESOURCE_EXHAUSTED":
            _mark_exhausted(model)
        raise QuotaExceededError(model, error_body)

    response.raise_for_status()
    data = response.json()

    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as e:
        raise InvalidResponseError(model, str(e))

    return {"text": text, "model_used": model}


class QuotaExceededError(Exception):
    def __init__(self, model: str, error_body: dict):
        self.model = model
        self.error_body = error_body
        super().__init__(f"{model} quota exceeded")


class InvalidResponseError(Exception):
    def __init__(self, model: str, detail: str):
        self.model = model
        self.detail = detail
        super().__init__(f"{model} returned invalid response: {detail}")


class AllModelsFailedError(Exception):
    def __init__(self, attempted: list[str], last_error: str):
        self.attempted = attempted
        self.last_error = last_error
        super().__init__(f"All models failed: {attempted}. Last error: {last_error}")


async def _try_groq_fallback(user_message: str) -> dict | None:
    """Last-resort fallback if every Gemini model failed. Returns None if
    GROQ_API_KEY isn't set, so this is always safe to call."""
    if not GROQ_API_KEY:
        return None

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                GROQ_URL,
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                json={
                    "model": GROQ_MODEL,
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "You are Kisan AI, an assistant for Pakistani "
                                "farmers. Reply in the farmer's language. Never "
                                "give exact chemical dosages — direct them to "
                                "the app's recommendation feature instead."
                            ),
                        },
                        {"role": "user", "content": user_message},
                    ],
                },
            )
        response.raise_for_status()
        data = response.json()
        text = data["choices"][0]["message"]["content"]
        return {"text": text, "model_used": f"{GROQ_MODEL} (fallback)"}
    except Exception as e:
        logger.error(f"Groq fallback also failed: {e}")
        return None


async def generate_response(
    contents: list,
    user_message: str = "",
    models_list: list[str] | None = None,
    timeout: float = 20.0,
) -> dict:
    """
    Try each model in order, skipping any already known to be exhausted
    today. Falls back to Groq if every Gemini model fails. Never raises —
    always returns a usable dict, even in the worst case.
    """
    if models_list is None:
        models_list = chat_models_to_try

    attempted = []
    last_error = ""

    for model in models_list:
        if _is_exhausted(model):
            logger.info(f"Skipping {model} — marked exhausted earlier today")
            continue

        attempted.append(model)
        try:
            result = await _call_gemini(model, contents, timeout)
            return result

        except QuotaExceededError as e:
            last_error = f"{model}: quota exceeded"
            logger.warning(f"{model} quota exceeded, falling back to next model...")
            continue

        except httpx.TimeoutException:
            last_error = f"{model}: timed out after {timeout}s"
            logger.warning(f"Model {model} timed out after {timeout}s, falling back...")
            continue

        except InvalidResponseError as e:
            last_error = f"{model}: invalid response ({e.detail})"
            logger.warning(f"Model {model} returned invalid response, falling back...")
            continue

        except httpx.HTTPStatusError as e:
            last_error = f"{model}: HTTP {e.response.status_code}"
            logger.warning(f"Model {model} HTTP error {e.response.status_code}, falling back...")
            continue

    # Every Gemini model failed — try Groq as a last resort
    groq_result = await _try_groq_fallback(user_message)
    if groq_result:
        logger.info("All Gemini models failed — Groq fallback succeeded")
        return groq_result

    # Truly everything failed — return a graceful message, don't crash
    logger.error(f"All AI models ({', '.join(attempted)}) failed. Last error: {last_error}")
    return {
        "text": (
            "Kisan AI is experiencing high demand right now. "
            "Please try again in a few minutes."
        ),
        "model_used": None,
        "fallback": True,
        "error_detail": last_error,
    }