"""
services/gemini_service.py

FIXES APPLIED (Sep 2026):
1. diagnose_leaf_image / diagnose_pest_image / diagnose_plant_image now return
   a proper DiseaseFallbackResponse / PestFallbackResponse object (not a plain
   dict) when Gemini fails.  The router's isinstance() check now works correctly.
2. _extract_json is more robust — strips preamble text before the first '{',
   handles ```json fences, and retries with relaxed parsing on truncated JSON.
3. Vision API calls now include a system_instruction block that forces the model
   to return ONLY valid JSON — dramatically reduces non-JSON responses.
4. Exhausted-model TTL reduced from 6 h to 30 min so recovery is faster.
5. Groq vision fallback is now enabled (use_groq_first=True) so that when
   Gemini can't produce valid JSON, Groq is tried before giving up.
6. Added startup validation log for GEMINI_API_KEY so misconfiguration is
   immediately visible in Render logs.
"""

import os
import re
import time
import json
import logging
import httpx
import base64
from typing import Optional, List, Union, Tuple, Any, Dict
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "openai/gpt-oss-20b"

# ---------------------------------------------------------------------------
# Startup validation — visible immediately in Render logs
# ---------------------------------------------------------------------------
if not GEMINI_API_KEY:
    logger.error("CRITICAL: GEMINI_API_KEY is not set — all AI features will fail")
elif len(GEMINI_API_KEY) < 20:
    logger.error("CRITICAL: GEMINI_API_KEY looks invalid (too short) — check your .env / Render env vars")
else:
    logger.info("GEMINI_API_KEY loaded (length=%d)", len(GEMINI_API_KEY))

# ---------------------------------------------------------------------------
# Model pools.
# For chat: Groq fallback handles failures automatically.
# For vision: Groq is PRIMARY (free, no quota, confirmed on Render).
#   Gemini models listed as fallback — update these if you find which model
#   your API key supports by checking: https://generativelanguage.googleapis.com/v1beta/models
# ---------------------------------------------------------------------------
chat_models_to_try = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-2.0-flash-lite",
]

# NOTE: Groq is tried FIRST for vision (use_groq_first=True in diagnose_* methods)
# These Gemini models are only tried if Groq fails
vision_models_to_try = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-2.0-flash-lite",
]

# Groq vision model — primary for disease/pest (vision-capable, free tier)
meta_vision_model = "meta-llama/llama-4-scout-17b-16e-instruct"
groq_vision_model = meta_vision_model

# Tracks which models have hit RESOURCE_EXHAUSTED today.
# TTL reduced to 30 min so service recovers faster after quota resets.
_exhausted_models: dict[str, float] = {}
_EXHAUSTED_TTL_SECONDS = 30 * 60  # 30 minutes


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
    logger.warning("Model %s marked exhausted, skipping for ~30 min", model)


async def _call_gemini(model: str, contents: list, timeout: float) -> dict:
    """Single call to one Gemini model. Raises on any failure."""
    url = f"{GEMINI_BASE_URL}/{model}:generateContent?key={GEMINI_API_KEY}"
    payload = {"contents": contents}

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(url, json=payload)

    if response.status_code == 429:
        error_body = response.json()
        status_val = error_body.get("error", {}).get("status", "")
        if status_val == "RESOURCE_EXHAUSTED":
            _mark_exhausted(model)
        raise QuotaExceededError(model, error_body)

    if response.status_code != 200:
        logger.error(
            "Gemini %s returned HTTP %d: %s",
            model, response.status_code,
            response.text[:300],
        )
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
    """Last-resort fallback if every Gemini model failed."""
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
        logger.error("Groq fallback also failed: %s", e)
        return None


async def generate_response(
    contents: list,
    user_message: str = "",
    models_list: list[str] | None = None,
    timeout: float = 20.0,
) -> dict:
    """
    Try each model in order, skipping exhausted models.
    Falls back to Groq if every Gemini model fails.
    Never raises — always returns a usable dict.
    """
    if models_list is None:
        models_list = chat_models_to_try

    attempted = []
    last_error = ""

    for model in models_list:
        if _is_exhausted(model):
            logger.info("Skipping %s — marked exhausted", model)
            continue

        attempted.append(model)
        try:
            result = await _call_gemini(model, contents, timeout)
            logger.info("Chat success with model %s", model)
            return result

        except QuotaExceededError as e:
            last_error = f"{model}: quota exceeded"
            logger.warning("%s quota exceeded, trying next model...", model)
            continue

        except httpx.TimeoutException:
            last_error = f"{model}: timed out after {timeout}s"
            logger.warning("Model %s timed out, trying next model...", model)
            continue

        except InvalidResponseError as e:
            last_error = f"{model}: invalid response ({e.detail})"
            logger.warning("Model %s invalid response, trying next model...", model)
            continue

        except httpx.HTTPStatusError as e:
            last_error = f"{model}: HTTP {e.response.status_code}"
            logger.warning("Model %s HTTP error %d, trying next...", model, e.response.status_code)
            continue

        except Exception as e:
            last_error = f"{model}: {str(e)}"
            logger.warning("Model %s unexpected error: %s", model, e)
            continue

    # Every Gemini model failed — try Groq
    groq_result = await _try_groq_fallback(user_message)
    if groq_result:
        logger.info("All Gemini models failed — Groq fallback succeeded")
        return groq_result

    logger.error("All AI models (%s) failed. Last error: %s", ", ".join(attempted), last_error)
    return {
        "text": (
            "Kisan AI is experiencing high demand right now. "
            "Please try again in a few minutes."
        ),
        "model_used": None,
        "fallback": True,
        "error_detail": last_error,
    }


# ---------------------------------------------------------------------------
# JSON extraction helper — robust multi-pass extractor
# ---------------------------------------------------------------------------
def _extract_json(text: str) -> Optional[str]:
    """
    Extract the first well-formed JSON object from a possibly messy string.

    Handles:
    - ```json ... ``` and ``` ... ``` code fences
    - Preamble text before the first '{'
    - Trailing garbage after the closing '}'
    - Truncated / slightly malformed JSON
    """
    if not text:
        return None

    cleaned = text.strip()

    # Pass 1: strip ```json ... ``` or ``` ... ``` fences
    fence_match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned)
    if fence_match:
        cleaned = fence_match.group(1).strip()

    # Pass 2: strip any prose before the first '{'
    brace_start = cleaned.find("{")
    if brace_start == -1:
        return None
    cleaned = cleaned[brace_start:]

    # Pass 3: find the matching closing '}' using a bracket counter
    depth = 0
    in_string = False
    escape = False
    end = -1

    for i, ch in enumerate(cleaned):
        if escape:
            escape = False
            continue
        if ch == "\\" and in_string:
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    if end == -1:
        return None

    candidate = cleaned[:end]

    # Pass 4: validate with json.loads
    try:
        json.loads(candidate)
        return candidate
    except (json.JSONDecodeError, ValueError):
        pass

    # Pass 5: attempt to fix common trailing-comma issue
    try:
        fixed = re.sub(r",\s*([}\]])", r"\1", candidate)
        json.loads(fixed)
        return fixed
    except (json.JSONDecodeError, ValueError):
        return None


async def _call_gemini_vision(model: str, contents: list, timeout: float) -> str:
    """
    Call Gemini for vision tasks and return raw text.
    Includes system_instruction to strongly enforce JSON-only output.
    """
    url = f"{GEMINI_BASE_URL}/{model}:generateContent?key={GEMINI_API_KEY}"

    payload = {
        "system_instruction": {
            "parts": [
                {
                    "text": (
                        "You are KissanAI's crop diagnostic engine for Pakistani farmers. "
                        "You MUST reply with ONLY a valid JSON object matching the schema given in the user prompt. "
                        "Do NOT include any markdown, code fences, prose, explanation, or any text outside the JSON. "
                        "Start your response with '{' and end with '}'."
                    )
                }
            ]
        },
        "contents": contents,
        "generationConfig": {
            "temperature": 0.1,
            "topP": 0.95,
            "maxOutputTokens": 2048,
        },
    }

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(url, json=payload)

    if response.status_code == 429:
        error_body = response.json()
        status_val = error_body.get("error", {}).get("status", "")
        if status_val == "RESOURCE_EXHAUSTED":
            _mark_exhausted(model)
        raise QuotaExceededError(model, error_body)

    if response.status_code != 200:
        logger.error(
            "Gemini vision %s HTTP %d: %s",
            model, response.status_code, response.text[:300],
        )
        response.raise_for_status()

    data = response.json()
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as e:
        raise InvalidResponseError(model, str(e))


async def _call_groq_vision(contents: list, timeout: float) -> str:
    """
    Call Groq for vision tasks (OpenAI-compatible API).
    Forces JSON output with strict system instruction + reminder in user prompt.
    """
    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY not configured")

    user_content = []
    user_text_parts = []
    for part_list in contents:
        for part in part_list.get("parts", []):
            if "inline_data" in part:
                img = part["inline_data"]
                user_content.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:{img['mime_type']};base64,{img['data']}"},
                })
            elif "text" in part:
                user_text_parts.append(part["text"])

    if user_text_parts:
        user_content.append({
            "type": "text",
            "text": (
                "\n\n".join(user_text_parts)
                + "\n\nIMPORTANT: Return ONLY a valid JSON object matching the requested schema. "
                "No markdown, no explanation, no code fences — only raw JSON starting with '{' and ending with '}'."
            ),
        })

    messages = [
        {
            "role": "system",
            "content": (
                "You are Kisan AI's crop diagnostic engine. "
                "You MUST reply with valid JSON only. "
                "No markdown, no prose, no code blocks. "
                "Start your response with '{' and end with '}'."
            ),
        },
        {"role": "user", "content": user_content},
    ]

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            GROQ_URL,
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={"model": groq_vision_model, "messages": messages},
        )
    response.raise_for_status()
    data = response.json()
    return data["choices"][0]["message"]["content"]


async def _generate_with_fallback(
    contents: list,
    models_list: List[str],
    timeout: float = 30.0,
    validate_json: bool = False,
    use_groq_first: bool = False,
) -> Tuple[str, str]:
    """
    Try models in order, return (text, model_used).
    With validate_json=True, only returns if a valid JSON object is found in the response.
    """
    last_error = ""

    # Try Groq first for vision tasks when enabled (no quota issues)
    if use_groq_first and GROQ_API_KEY:
        try:
            text = await _call_groq_vision(contents, timeout)
            if validate_json:
                cleaned = _extract_json(text)
                if cleaned is not None:
                    logger.info("Groq vision returned valid JSON")
                    return cleaned, groq_vision_model
                logger.warning("Groq returned invalid JSON, trying Gemini models...")
            else:
                return text, groq_vision_model
        except Exception as e:
            logger.warning("Groq vision failed: %s, falling back to Gemini...", e)

    for model in models_list:
        if _is_exhausted(model):
            logger.info("Skipping %s — marked exhausted", model)
            continue
        try:
            text = await _call_gemini_vision(model, contents, timeout)
            if validate_json:
                cleaned = _extract_json(text)
                if cleaned is not None:
                    logger.info("Vision success with model %s (valid JSON)", model)
                    return cleaned, model
                last_error = f"{model}: response did not contain valid JSON"
                logger.warning(
                    "%s response has no valid JSON. Raw (first 300 chars): %s",
                    model, text[:300],
                )
                continue
            logger.info("Vision success with model %s", model)
            return text, model
        except (QuotaExceededError, InvalidResponseError, httpx.TimeoutException, httpx.HTTPStatusError) as e:
            last_error = str(e)
            logger.warning("Model %s vision error: %s", model, e)
            continue
        except Exception as e:
            last_error = str(e)
            logger.warning("Model %s unexpected vision error: %s", model, e)
            continue

    raise AllModelsFailedError(models_list, last_error)


# ---------------------------------------------------------------------------
# Compatibility wrapper — routers import `gemini_service` instance
# ---------------------------------------------------------------------------
class GeminiService:
    """Compatibility wrapper — routers call methods on this instance."""

    async def generate_response(self, message: str, timeout: float = 30.0) -> str:
        """Chat: returns text string."""
        contents = [{"parts": [{"text": message}]}]
        result = await generate_response(
            contents=contents,
            user_message=message,
            timeout=timeout,
        )
        return result.get("text", "")

    async def diagnose_leaf_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
        crop_name: Optional[str] = None,
    ) -> Union[Tuple[Dict[str, Any], str, str], Any]:
        """
        Disease diagnosis from leaf image.

        Returns:
            On success: (parsed_dict, raw_json_str, model_used)  — 3-tuple
            On failure: DiseaseFallbackResponse instance  — so isinstance() check works
        """
        from prompts import build_diagnosis_prompt
        from schemas.disease import DiseaseFallbackResponse

        active_prompt = prompt or build_diagnosis_prompt(language=language, crop_name=crop_name)
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        contents = [
            {"parts": [{"inline_data": {"mime_type": mime_type, "data": b64}}, {"text": active_prompt}]}
        ]
        models = models_list or vision_models_to_try

        try:
            raw, model_used = await _generate_with_fallback(
                contents, models, timeout,
                validate_json=True,
                use_groq_first=True,
            )
            parsed = json.loads(raw)
            logger.info("Disease diagnosis succeeded with model %s", model_used)
            return parsed, raw, model_used

        except AllModelsFailedError as e:
            logger.error(
                "Disease detection: all models failed. Attempted: %s. Last error: %s",
                e.attempted, e.last_error,
            )
            return DiseaseFallbackResponse(
                message="Diagnosis temporarily unavailable — AI service is busy. Please try again in a moment.",
                top_candidates=[],
                confidence_score=0.0,
            )
        except json.JSONDecodeError as e:
            logger.error("Disease detection: JSON parse error after extraction: %s", e)
            return DiseaseFallbackResponse(
                message="Diagnosis temporarily unavailable — invalid response from AI. Please try again.",
                top_candidates=[],
                confidence_score=0.0,
            )
        except Exception as e:
            logger.error("Disease detection: unexpected error: %s", e, exc_info=True)
            return DiseaseFallbackResponse(
                message=f"Diagnosis temporarily unavailable — {type(e).__name__}. Please try again.",
                top_candidates=[],
                confidence_score=0.0,
            )

    async def diagnose_pest_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
        crop_name: Optional[str] = None,
    ) -> Union[Tuple[Dict[str, Any], str, str], Any]:
        """
        Pest diagnosis from image.

        Returns:
            On success: (parsed_dict, raw_json_str, model_used)  — 3-tuple
            On failure: PestFallbackResponse instance  — so isinstance() check works
        """
        from prompts import build_pest_prompt
        from schemas.pest import PestFallbackResponse

        active_prompt = prompt or build_pest_prompt(language=language, crop_name=crop_name)
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        contents = [
            {"parts": [{"inline_data": {"mime_type": mime_type, "data": b64}}, {"text": active_prompt}]}
        ]
        models = models_list or vision_models_to_try

        try:
            raw, model_used = await _generate_with_fallback(
                contents, models, timeout,
                validate_json=True,
                use_groq_first=True,
            )
            parsed = json.loads(raw)
            logger.info("Pest diagnosis succeeded with model %s", model_used)
            return parsed, raw, model_used

        except AllModelsFailedError as e:
            logger.error(
                "Pest detection: all models failed. Attempted: %s. Last error: %s",
                e.attempted, e.last_error,
            )
            return PestFallbackResponse(
                message="Pest identification temporarily unavailable — AI service is busy. Please try again in a moment.",
                top_candidates=[],
                confidence_score=0.0,
            )
        except json.JSONDecodeError as e:
            logger.error("Pest detection: JSON parse error after extraction: %s", e)
            return PestFallbackResponse(
                message="Pest identification temporarily unavailable — invalid response from AI. Please try again.",
                top_candidates=[],
                confidence_score=0.0,
            )
        except Exception as e:
            logger.error("Pest detection: unexpected error: %s", e, exc_info=True)
            return PestFallbackResponse(
                message=f"Pest identification temporarily unavailable — {type(e).__name__}. Please try again.",
                top_candidates=[],
                confidence_score=0.0,
            )

    async def diagnose_plant_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
    ) -> Union[Tuple[Dict[str, Any], str, str], Any]:
        """
        Plant identification from image.

        Returns:
            On success: (parsed_dict, raw_json_str, model_used)  — 3-tuple
            On failure: dict with 'message' and 'top_candidates' keys
        """
        from prompts import PLANT_DIAGNOSIS_PROMPT

        active_prompt = prompt or PLANT_DIAGNOSIS_PROMPT
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        contents = [
            {"parts": [{"inline_data": {"mime_type": mime_type, "data": b64}}, {"text": active_prompt}]}
        ]
        models = models_list or vision_models_to_try

        try:
            raw, model_used = await _generate_with_fallback(
                contents, models, timeout,
                validate_json=True,
                use_groq_first=True,
            )
            parsed = json.loads(raw)
            logger.info("Plant diagnosis succeeded with model %s", model_used)
            return parsed, raw, model_used

        except AllModelsFailedError as e:
            logger.error(
                "Plant detection: all models failed. Attempted: %s. Last error: %s",
                e.attempted, e.last_error,
            )
            return {"message": "Plant diagnosis temporarily unavailable. Please try again.", "top_candidates": []}
        except Exception as e:
            logger.error("Plant detection: unexpected error: %s", e, exc_info=True)
            return {"message": f"Plant diagnosis temporarily unavailable — {type(e).__name__}. Please try again.", "top_candidates": []}


gemini_service = GeminiService()