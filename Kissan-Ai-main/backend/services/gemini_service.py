import os
import json
import asyncio
import logging
import re
import base64
from typing import Optional, List, Union, Tuple, Any, Dict
from pydantic import BaseModel, Field
from fastapi import HTTPException, status
from google import genai
import httpx
from prompts import KISSAN_SYSTEM_PROMPT, PLANT_DIAGNOSIS_PROMPT
from rules_engine.pesticide_rules import PESTICIDE_RULES
from rules_engine.insecticide_rules import INSECTICIDE_RULES
from schemas.disease import DiseaseFallbackResponse
from schemas.pest import PestFallbackResponse
from schemas.plant import PlantDiagnosisFallbackResponse


def _extract_json(text: str) -> Optional[str]:
    """Extract the first well-formed JSON object from a possibly malformed string.

    Handles truncated/unterminated JSON by finding a balanced brace block.
    Returns None if no JSON object can be extracted.
    """
    cleaned = text.strip()
    if "```" in cleaned:
        m = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned)
        if m:
            cleaned = m.group(1)

    start = cleaned.find("{")
    if start == -1:
        return None

    end = start
    depth = 0
    in_string = False
    escape = False
    for i, ch in enumerate(cleaned[start:], start=start):
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

    if depth != 0:
        return None
    candidate = cleaned[start:end]
    try:
        json.loads(candidate)
        return candidate
    except (json.JSONDecodeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# Grok (xAI) client for vision tasks — free tier, OpenAI-compatible API.
# Used as primary for disease/pest/plant image analysis.
# ---------------------------------------------------------------------------
class GrokVisionClient:
    """Simple async client for Grok vision via OpenAI-compatible API."""

    GROK_API_URL = "https://api.x.ai/v1/chat/completions"
    GROK_VISION_MODEL = "grok-2-vision-1212"

    def __init__(self):
        self.api_key = os.environ.get("GROK_API_KEY", "").strip()
        self.client: Optional[httpx.AsyncClient] = None

    def _get_client(self) -> httpx.AsyncClient:
        if self.client is None or self.client.is_closed:
            self.client = httpx.AsyncClient(
                timeout=httpx.Timeout(45.0, connect=10.0),
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
            )
        return self.client

    async def close(self):
        if self.client and not self.client.is_closed:
            await self.client.aclose()

    async def analyze_image(
        self,
        image_bytes: bytes,
        mime_type: str,
        prompt: str,
        model: Optional[str] = None,
    ) -> str:
        """Send image + prompt to Grok vision and return response text."""
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROK_API_KEY is not configured.",
            )

        # Encode image as base64 data URL
        b64 = base64.b64encode(image_bytes).decode("utf-8")
        data_url = f"data:{mime_type};base64,{b64}"

        payload = {
            "model": model or self.GROK_VISION_MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "image_url", "image_url": {"url": data_url}},
                        {"type": "text", "text": prompt},
                    ],
                }
            ],
            "temperature": 0.3,
            "max_tokens": 2048,
        }

        client = self._get_client()
        response = await client.post(self.GROK_API_URL, json=payload)

        if response.status_code != 200:
            error_text = response.text[:200]
            logger.warning("Grok API error %d: %s", response.status_code, error_text)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Grok API failed: {response.status_code}",
            )

        data = response.json()
        return data["choices"][0]["message"]["content"]


# Global Grok client instance
_grok_client = GrokVisionClient()

logger = logging.getLogger(__name__)

# Fixed English category keys the rules engine understands. Gemini is asked
# to classify into exactly one of these (in addition to giving a localized
# display name), so pesticide/insecticide lookups never depend on matching
# free-form or translated text.
DISEASE_CATEGORIES = list(PESTICIDE_RULES.keys()) + ["healthy"]
PEST_CATEGORIES = list(INSECTICIDE_RULES.keys()) + ["none"]


# ---------------------------------------------------------------------------
# Internal Pydantic models used ONLY for Gemini structured-output schema.
# They are converted via .model_json_schema() and passed as response_schema
# so Gemini always returns well-formed JSON — never plain text that could
# silently fall back to a generic placeholder.
# ---------------------------------------------------------------------------
class _ImageQualitySchema(BaseModel):
    """Schema for the image_quality field in Gemini structured output."""
    usable: bool = Field(description="True if the image contains a visible plant/crop that can be diagnosed.")
    reason: Optional[str] = Field(default=None, description="If usable is false, brief reason e.g. 'too blurry', 'no plant visible', 'too dark'.")


class _DiseaseStructuredResponse(BaseModel):
    """Gemini structured output schema for disease diagnosis."""
    crop_name: str = Field(description="Identified crop in English + local names")
    disease_name: str = Field(description="Exact short disease name")
    disease_category: str = Field(description="One value from the fixed disease_category list, always in English")
    confidence_score: float = Field(description="Confidence 0.0-1.0")
    symptoms: List[str] = Field(description="Short symptom bullet points")
    treatment: List[str] = Field(description="Treatment steps including brand+dosage")
    image_quality: _ImageQualitySchema = Field(description="Assessment of whether the image is usable for diagnosis")


class _PestStructuredResponse(BaseModel):
    """Gemini structured output schema for pest identification."""
    crop_name: str = Field(description="Identified crop in English + local names")
    pest_name: str = Field(description="Exact short pest name in English and local language")
    pest_category: str = Field(description="One value from the fixed pest_category list, always in English")
    confidence_score: float = Field(description="Confidence 0.0-1.0")
    damage_symptoms: List[str] = Field(description="Short damage symptom bullet points")
    recommended_pesticide: List[str] = Field(description="Pesticide steps including brand+dosage")
    image_quality: _ImageQualitySchema = Field(description="Assessment of whether the image is usable for diagnosis")


class _PlantDiagnosisStructuredResponse(BaseModel):
    """Gemini structured output schema for plant (houseplant/ornamental) diagnosis."""
    plant_species: str = Field(description="Identified plant species in English + local names")
    issue_name: str = Field(description="Short issue name, e.g. Powdery Mildew, Aphid Infestation")
    issue_category: str = Field(description="One value from the fixed issue_category list, always in English")
    confidence_score: float = Field(description="Confidence 0.0-1.0")
    symptoms: List[str] = Field(description="Short symptom bullet points")
    treatment: List[str] = Field(description="Treatment steps including product+dosage")
    image_quality: _ImageQualitySchema = Field(description="Assessment of whether the image is usable for diagnosis")

# Valid Gemini model names (verified as of Sep 2026).
# gemini-2.5-flash is retired (404 NOT_FOUND for new users).
# 3.5 models are prioritized; 3.6 is fallback.
models_to_try = [
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.6-flash",
]

# Chat-only model list — 3.5 models for text Q&A (2.5-flash retired for new users).
chat_models_to_try = [
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
]

# Vision / structured-output model list — image analysis (disease, pest,
# crop ID). 3.5 models are prioritized; 3.6 is fallback.
vision_models_to_try = [
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
    "gemini-3.6-flash",
]


def _crop_identification_step(crop_name: Optional[str]) -> str:
    """Mandatory Step-1 crop instruction, adapted to whether the caller
    already told us the crop or Gemini must identify it from the image."""
    if crop_name:
        return (
            f"CROP CONTEXT (authoritative): the farmer states this plant is \"{crop_name}\". "
            f"TRUST this crop over your own visual guess — do NOT re-identify it and do NOT "
            f"diagnose diseases/pests of any other crop. Return \"crop_name\" exactly as \"{crop_name}\"."
        )
    return (
        "CROP IDENTIFICATION FIRST: carefully identify the CROP TYPE (e.g., Pomegranate/Anar, "
        "Cotton, Wheat, Rice, Citrus, Maize, Sugarcane, Tomato, Onion, Canola) from the image based "
        "on leaf shape, venation, color, and stem structure. Diagnose the disease/pest for THAT "
        "identified crop only — never mix in another crop's diseases (e.g., do not report wheat "
        "rust on a pomegranate leaf). Write \"crop_name\" in English plus local names in brackets, "
        "e.g. \"Pomegranate (انار / ਅਨਾਰ)\"."
    )


def build_diagnosis_prompt(language: str = "english", crop_name: Optional[str] = None) -> str:
    """Builds a localized prompt for disease diagnosis in the requested language."""
    lang = (language or "english").strip().lower()
    return f"""Analyze the crop leaf image. Detect the disease and return the entire response strictly in the requested language: {lang}.
- If language is 'punjabi', write the disease name, symptoms, and treatment in clear Punjabi (Shahmukhi / Roman Punjabi).
- If 'urdu', write in Urdu (or Roman Urdu as requested).
- If 'english', write in English.
- If any other language is requested, write strictly in that requested language.

STEP ORDER (mandatory):
1. {_crop_identification_step(crop_name)}
2. Then diagnose the specific disease for that crop only.

IMPORTANT DIAGNOSTIC RULES:
- You must always commit to your single most likely diagnosis based on visible symptoms, even if you are not 100% certain. Never respond with vague answers like 'cannot be determined' or 'consult an expert' as your primary answer — that is only allowed as a last resort when the image is literally unusable (see image_quality below).
- Before finalizing, mentally compare the top 2-3 possible diseases that match the visible symptoms, and pick the one that best fits ALL visible signs (leaf color, spots, lesions, wilting pattern). Return that one as disease_name — do not list multiple options to the farmer.

Keep the explanations short, direct, and farmer-friendly (under 150-200 words).
You MUST respond with a valid JSON object matching this exact schema:
{{
  "crop_name": "Identified crop in English + local names, e.g. Pomegranate (انار / ਅਨਾਰ)",
  "disease_name": "Exact short disease name in {lang}",
  "disease_category": "One exact value from this fixed list (always in English, regardless of {lang}): {DISEASE_CATEGORIES}. Pick the closest match. Use \\"healthy\\" if the plant shows no disease.",
  "confidence_score": 0.95,
  "symptoms": [
    "Short symptom bullet point 1 in {lang}",
    "Short symptom bullet point 2 in {lang}"
  ],
  "treatment": [
    "Direct organic/cultural treatment step in {lang}",
    "Brand Name + Product Name (e.g., Syngenta - Virtako or FFC - Sona Urea), exact dosage per acre/liter, application timing, and safety gear in {lang}"
  ],
  "image_quality": {{
    "usable": true,
    "reason": null
  }}
}}
NOTE on image_quality: Set "usable" to false ONLY when the image is genuinely impossible to diagnose (completely blurry, no plant visible, too dark, entirely unrelated content). For any image where a plant is at least partially visible, set "usable" to true and provide your best-guess diagnosis even if confidence is lower."""


def build_pest_prompt(language: str = "english", crop_name: Optional[str] = None) -> str:
    """Builds a localized prompt for pest identification in the requested language."""
    lang = (language or "english").strip().lower()
    return f"""Analyze this crop image for pest identification. Return the entire response strictly in the requested language: {lang}.
- If language is 'punjabi', write in clear Punjabi (Shahmukhi / Roman Punjabi).
- If 'urdu', write in Urdu (or Roman Urdu as requested).
- If 'english', write in English.
- If any other language is requested, write strictly in that requested language.

STEP ORDER (mandatory):
1. {_crop_identification_step(crop_name)}
2. Then identify the pest damaging that crop only.

IMPORTANT DIAGNOSTIC RULES:
- You must always commit to your single most likely pest identification based on visible symptoms, even if you are not 100% certain. Never respond with vague answers like 'cannot be determined' or 'consult an expert' as your primary answer — that is only allowed as a last resort when the image is literally unusable (see image_quality below).
- Before finalizing, mentally compare the top 2-3 possible pests that match the visible damage and insect signs, and pick the one that best fits ALL visible signs (leaf damage pattern, insect body shape, eggs, webbing, wilting). Return that one as pest_name — do not list multiple options to the farmer.

Keep the explanations short, direct, and farmer-friendly (under 150-200 words).
You MUST respond with a valid JSON object matching this exact schema:
{{
  "crop_name": "Identified crop in English + local names, e.g. Pomegranate (انار / ਅਨਾਰ)",
  "pest_name": "Exact short pest name in English and {lang} (e.g. Cotton Bug / کپاس کا کیڑا)",
  "pest_category": "One exact value from this fixed list (always in English, regardless of {lang}): {PEST_CATEGORIES}. Pick the closest match. Use \\"none\\" if no pest is visible.",
  "confidence_score": 0.95,
  "damage_symptoms": [
    "Short damage symptom bullet point 1 in {lang}",
    "Short damage symptom bullet point 2 in {lang}"
  ],
  "recommended_pesticide": [
    "Recommended organic/biological spray step in {lang}",
    "Brand Name + Product Name (e.g., FMC - Coragen), exact dosage per acre/liter of water, application timing, and safety gear in {lang}"
  ],
  "image_quality": {{
    "usable": true,
    "reason": null
  }}
}}
NOTE on image_quality: Set "usable" to false ONLY when the image is genuinely impossible to diagnose (completely blurry, no plant visible, too dark, entirely unrelated content). For any image where a plant is at least partially visible, set "usable" to true and provide your best-guess pest identification even if confidence is lower."""


class GeminiService:
    def __init__(self, api_key: Optional[str] = None):
        # Priority: explicit param > env var
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None
        self.default_models = vision_models_to_try

        # Low-hallucination configuration settings accessed directly via genai.types
        self.config = genai.types.GenerateContentConfig(
            system_instruction=KISSAN_SYSTEM_PROMPT,
            temperature=0.2,
            top_p=0.85,
            top_k=30,
            max_output_tokens=900,  # JSON-only responses need far fewer tokens
        )

    @staticmethod
    def _build_structured_config(response_schema: type[BaseModel]) -> Any:
        """Build a GenerateContentConfig with Gemini structured-output enabled.

        Converts a Pydantic model to a JSON-Schema dict and passes it as
        response_schema together with response_mime_type='application/json'
        so Gemini is *forced* to return valid JSON matching the schema.
        """
        return genai.types.GenerateContentConfig(
            system_instruction=KISSAN_SYSTEM_PROMPT,
            temperature=0.2,
            top_p=0.85,
            top_k=30,
            max_output_tokens=900,  # JSON-only responses need far fewer tokens
            response_mime_type="application/json",
            response_schema=response_schema.model_json_schema(),
        )

    async def generate_content_with_fallback(
        self,
        contents: Union[str, List[Any]],
        config: Optional[Any] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
        validate_json: bool = False,
    ) -> Tuple[str, str]:
        """
        Asynchronously generates content iterating through fallback models on error,
        timeout, or (when *validate_json* is True) JSON parse failure.
        Returns a tuple of (response_text, model_used).
        """
        if not self.client:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Gemini API key is not configured. Set GEMINI_API_KEY in your environment.",
            )

        models = models_list or self.default_models
        gen_config = config or self.config
        last_exception = None

        for model in models:
            try:
                logger.info("Attempting content generation with model: %s", model)
                response = await asyncio.wait_for(
                    self.client.aio.models.generate_content(
                        model=model,
                        contents=contents,
                        config=gen_config,
                    ),
                    timeout=timeout,
                )
                if response and response.text:
                    text = response.text.strip()

                    # When structured output is requested, verify the response
                    # is actually parseable JSON.  Some models may still return
                    # malformed JSON despite response_mime_type — try to repair
                    # it first; only fall through to the next model if repair fails.
                    if validate_json:
                        cleaned = _extract_json(text)
                        if cleaned is not None:
                            return cleaned, model
                        je = json.JSONDecodeError("No valid JSON object found", text, 0)
                        last_exception = je
                        logger.warning(
                            "Model %s returned invalid JSON, falling back to next model...",
                            model,
                        )
                        continue  # try next model

                    return text, model
            except asyncio.TimeoutError as e:
                last_exception = e
                logger.warning(f"Model {model} timed out after {timeout}s: {e}, falling back to next model...")
            except Exception as e:
                last_exception = e
                logger.warning(f"Model {model} failed: {e}, falling back to next model...")

        logger.error("All AI models (%s) failed. Last error: %s", ", ".join(models), str(last_exception))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="All AI models are currently busy. Please try again.",
        )

    async def generate_response(
        self,
        message: str,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
    ) -> str:
        """Asynchronously generates a text response with fallback support."""
        # For chat (no explicit models_list), use the fast chat-optimized list
        # with a shorter timeout so responses feel instant.
        if models_list is None:
            models_list = chat_models_to_try
            timeout = min(timeout, 15.0)
        text, _ = await self.generate_content_with_fallback(
            contents=message,
            models_list=models_list,
            timeout=timeout,
        )
        return text

    async def diagnose_leaf_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
        crop_name: Optional[str] = None,
    ) -> Union[Tuple[Dict[str, Any], str, str], DiseaseFallbackResponse]:
        """
        Diagnoses a leaf image in the requested language.

        Returns either:
          - (parsed_json_dict, formatted_markdown, model_used) on success, or
          - DiseaseFallbackResponse when the image is genuinely unusable.
        """
        active_prompt = prompt or build_diagnosis_prompt(language=language, crop_name=crop_name)

        # Try Grok first (free tier, vision-capable), fall back to Gemini
        raw_response = None
        model_used = "grok-2-vision"

        if _grok_client.api_key:
            try:
                logger.info("Attempting disease diagnosis with Grok vision...")
                raw_response = await _grok_client.analyze_image(
                    image_bytes=image_bytes,
                    mime_type=mime_type,
                    prompt=active_prompt + "\n\nRespond ONLY with valid JSON. Do not include markdown code blocks.",
                )
                # Validate JSON
                cleaned = _extract_json(raw_response)
                if cleaned:
                    raw_response = cleaned
                else:
                    logger.warning("Grok returned invalid JSON, falling back to Gemini...")
                    raw_response = None
            except Exception as e:
                logger.warning("Grok vision failed: %s, falling back to Gemini...", e)
                raw_response = None

        # Fall back to Gemini if Grok failed
        if not raw_response:
            contents = [
                genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                active_prompt,
            ]
            structured_config = self._build_structured_config(_DiseaseStructuredResponse)
            raw_response, model_used = await self.generate_content_with_fallback(
                contents=contents,
                config=structured_config,
                models_list=models_list,
                timeout=timeout,
                validate_json=True,
            )

        # Parse JSON output from Gemini response
        parsed_data: Dict[str, Any] = {}
        try:
            cleaned_json = _extract_json(raw_response) or raw_response
            parsed_data = json.loads(cleaned_json)
        except Exception as json_err:
            logger.warning("Failed to parse direct JSON from Gemini: %s. Using text extraction.", json_err)
            # Fallback regex extraction — always provide a specific best-guess
            # disease name rather than a generic placeholder.
            disease_match = re.search(r'"disease_name"\s*:\s*"([^"]+)"', raw_response) or re.search(
                r"(?:Disease Name|Diagnosis|بیماری کا نام|ਬਿਮਾਰੀ ਦਾ ਨਾਂ)\s*:\s*([^\n\r]+)", raw_response, re.IGNORECASE
            )
            parsed_data["disease_name"] = (
                disease_match.group(1).strip() if disease_match else "Unclassified disease (image unclear)"
            )
            parsed_data["confidence_score"] = 0.5
            parsed_data["symptoms"] = ["Visible symptoms detected from image."]
            parsed_data["treatment"] = [raw_response]

        # --- Image quality gate ---
        # Only return a "please retake" response when the image is genuinely
        # unusable.  Every other case (even low confidence) proceeds normally.
        image_quality = parsed_data.get("image_quality", {})
        if isinstance(image_quality, dict) and image_quality.get("usable") is False:
            reason = image_quality.get("reason") or "Image is not suitable for diagnosis"
            logger.info("Image quality unusable: %s — returning fallback response.", reason)
            return DiseaseFallbackResponse(
                message=f"Please retake the photo: {reason}",
                confidence_score=0.0,
            )

        # Guarantee crop_name is present even if Gemini omitted it
        if not parsed_data.get("crop_name"):
            crop_fallback = re.search(r'"crop_name"\s*:\s*"([^"]+)"', raw_response)
            parsed_data["crop_name"] = (
                crop_fallback.group(1).strip() if crop_fallback else (crop_name or "Unknown crop")
            )

        # Construct readable localized markdown for UI display
        identified_crop = parsed_data.get("crop_name")
        disease_name = parsed_data.get("disease_name", "Unclassified disease (image unclear)")
        confidence_val = parsed_data.get("confidence_score", 0.5)
        symptoms = parsed_data.get("symptoms", [])
        treatments = parsed_data.get("treatment", [])

        symptoms_md = "\n".join(f"- {s}" for s in symptoms) if isinstance(symptoms, list) else str(symptoms)
        treatment_md = "\n".join(f"- {t}" for t in treatments) if isinstance(treatments, list) else str(treatments)

        # Add a low-confidence advisory note so the UI can surface it as a
        # small badge / footnote — but NEVER block or hide the diagnosis.
        confidence_note = ""
        try:
            if float(confidence_val) < 0.7:
                confidence_note = (
                    "\n\n---\n*Note: moderate confidence — verify by comparing "
                    "with reference images or consult a local extension officer.*"
                )
        except (ValueError, TypeError):
            pass

        formatted_markdown = (
            f"### **Crop**: {identified_crop}\n\n"
            f"### **Diagnosis**: {disease_name}\n\n"
            f"#### **Symptoms**:\n{symptoms_md}\n\n"
            f"#### **Treatment & Management**:\n{treatment_md}"
            f"{confidence_note}"
        )

        return parsed_data, formatted_markdown, model_used

    async def diagnose_pest_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
        crop_name: Optional[str] = None,
    ) -> Union[Tuple[Dict[str, Any], str, str], PestFallbackResponse]:
        """
        Identifies a pest in a crop image in the requested language.

        Returns either:
          - (parsed_json_dict, formatted_markdown, model_used) on success, or
          - PestFallbackResponse when the image is genuinely unusable.
        """
        active_prompt = prompt or build_pest_prompt(language=language, crop_name=crop_name)

        # Try Grok first (free tier, vision-capable), fall back to Gemini
        raw_response = None
        model_used = "grok-2-vision"

        if _grok_client.api_key:
            try:
                logger.info("Attempting pest identification with Grok vision...")
                raw_response = await _grok_client.analyze_image(
                    image_bytes=image_bytes,
                    mime_type=mime_type,
                    prompt=active_prompt + "\n\nRespond ONLY with valid JSON. Do not include markdown code blocks.",
                )
                cleaned = _extract_json(raw_response)
                if cleaned:
                    raw_response = cleaned
                else:
                    logger.warning("Grok returned invalid JSON for pest, falling back to Gemini...")
                    raw_response = None
            except Exception as e:
                logger.warning("Grok pest vision failed: %s, falling back to Gemini...", e)
                raw_response = None

        # Fall back to Gemini if Grok failed
        if not raw_response:
            contents = [
                genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                active_prompt,
            ]
            structured_config = self._build_structured_config(_PestStructuredResponse)
            raw_response, model_used = await self.generate_content_with_fallback(
                contents=contents,
                config=structured_config,
                models_list=models_list,
                timeout=timeout,
                validate_json=True,
            )

        # Parse JSON output from Gemini response
        parsed_data: Dict[str, Any] = {}
        try:
            cleaned_json = _extract_json(raw_response) or raw_response
            parsed_data = json.loads(cleaned_json)
        except Exception as json_err:
            logger.warning("Failed to parse pest JSON from Gemini: %s. Using text extraction.", json_err)
            # Fallback regex extraction — always provide a specific best-guess
            # pest name rather than a generic placeholder.
            pest_match = re.search(r'"pest_name"\s*:\s*"([^"]+)"', raw_response) or re.search(
                r"(?:Pest Name|Insect|کیڑا|ਕੀੜਾ)\s*:\s*([^\n\r]+)", raw_response, re.IGNORECASE
            )
            parsed_data["pest_name"] = (
                pest_match.group(1).strip() if pest_match else "Unclassified pest (image unclear)"
            )
            parsed_data["confidence_score"] = 0.5
            parsed_data["damage_symptoms"] = ["Visible damage detected from image."]
            parsed_data["recommended_pesticide"] = [raw_response]

        # --- Image quality gate ---
        # Only return a "please retake" response when the image is genuinely
        # unusable.  Every other case (even low confidence) proceeds normally.
        image_quality = parsed_data.get("image_quality", {})
        if isinstance(image_quality, dict) and image_quality.get("usable") is False:
            reason = image_quality.get("reason") or "Image is not suitable for diagnosis"
            logger.info("Image quality unusable: %s — returning pest fallback response.", reason)
            return PestFallbackResponse(
                message=f"Please retake the photo: {reason}",
                confidence_score=0.0,
            )

        # Guarantee crop_name is present even if Gemini omitted it
        if not parsed_data.get("crop_name"):
            crop_fallback = re.search(r'"crop_name"\s*:\s*"([^"]+)"', raw_response)
            parsed_data["crop_name"] = (
                crop_fallback.group(1).strip() if crop_fallback else (crop_name or "Unknown crop")
            )

        # Construct readable localized markdown for UI display
        identified_crop = parsed_data.get("crop_name")
        pest_name = parsed_data.get("pest_name", "Unclassified pest (image unclear)")
        confidence_val = parsed_data.get("confidence_score", 0.5)
        damage_symptoms = parsed_data.get("damage_symptoms", [])
        pesticides = parsed_data.get("recommended_pesticide", [])

        symptoms_md = "\n".join(f"- {s}" for s in damage_symptoms) if isinstance(damage_symptoms, list) else str(damage_symptoms)
        pesticide_md = "\n".join(f"- {p}" for p in pesticides) if isinstance(pesticides, list) else str(pesticides)

        # Add a low-confidence advisory note so the UI can surface it as a
        # small badge / footnote — but NEVER block or hide the diagnosis.
        confidence_note = ""
        try:
            if float(confidence_val) < 0.7:
                confidence_note = (
                    "\n\n---\n*Note: moderate confidence — verify by comparing "
                    "with reference images or consult a local extension officer.*"
                )
        except (ValueError, TypeError):
            pass

        formatted_markdown = (
            f"### **Crop**: {identified_crop}\n\n"
            f"### **Identified Pest**: {pest_name}\n\n"
            f"#### **Damage Symptoms**:\n{symptoms_md}\n\n"
            f"#### **Recommended Pesticide & Treatment**:\n{pesticide_md}"
            f"{confidence_note}"
        )

        return parsed_data, formatted_markdown, model_used

    async def diagnose_plant_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 30.0,
    ) -> Union[Tuple[Dict[str, Any], str, str], PlantDiagnosisFallbackResponse]:
        """
        Diagnoses a houseplant / ornamental plant image in the requested language.

        Returns either:
          - (parsed_json_dict, formatted_markdown, model_used) on success, or
          - PlantDiagnosisFallbackResponse when the image is genuinely unusable.
        """
        lang = (language or "english").strip().lower()
        active_prompt = prompt or PLANT_DIAGNOSIS_PROMPT.format(language=lang)

        contents = [
            genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            active_prompt,
        ]

        structured_config = self._build_structured_config(_PlantDiagnosisStructuredResponse)

        raw_response, model_used = await self.generate_content_with_fallback(
            contents=contents,
            config=structured_config,
            models_list=models_list,
            timeout=timeout,
            validate_json=True,
        )

        # Parse JSON output from Gemini response
        parsed_data: Dict[str, Any] = {}
        try:
            cleaned_json = raw_response
            cleaned_json = _extract_json(raw_response) or raw_response
            parsed_data = json.loads(cleaned_json)
        except Exception as json_err:
            logger.warning("Failed to parse plant diagnosis JSON from Gemini: %s. Using text extraction.", json_err)
            issue_match = re.search(r'"issue_name"\s*:\s*"([^"]+)"', raw_response) or re.search(
                r"(?:Issue|Problem|بیماری|مسئلہ)\s*:\s*([^\n\r]+)", raw_response, re.IGNORECASE
            )
            parsed_data["issue_name"] = (
                issue_match.group(1).strip() if issue_match else "Unclassified plant issue (image unclear)"
            )
            parsed_data["confidence_score"] = 0.5
            parsed_data["symptoms"] = ["Visible symptoms detected from image."]
            parsed_data["treatment"] = [raw_response]

        # --- Image quality gate ---
        image_quality = parsed_data.get("image_quality", {})
        if isinstance(image_quality, dict) and image_quality.get("usable") is False:
            reason = image_quality.get("reason") or "Image is not suitable for diagnosis"
            logger.info("Plant image quality unusable: %s — returning fallback response.", reason)
            return PlantDiagnosisFallbackResponse(
                message=f"Please retake the photo: {reason}",
                confidence_score=0.0,
            )

        # Guarantee plant_species is present
        if not parsed_data.get("plant_species"):
            species_fallback = re.search(r'"plant_species"\s*:\s*"([^"]+)"', raw_response)
            parsed_data["plant_species"] = (
                species_fallback.group(1).strip() if species_fallback else "Unknown plant"
            )

        # Construct readable localized markdown for UI display
        plant_species = parsed_data.get("plant_species")
        issue_name = parsed_data.get("issue_name", "Unclassified plant issue (image unclear)")
        confidence_val = parsed_data.get("confidence_score", 0.5)
        symptoms = parsed_data.get("symptoms", [])
        treatments = parsed_data.get("treatment", [])

        symptoms_md = "\n".join(f"- {s}" for s in symptoms) if isinstance(symptoms, list) else str(symptoms)
        treatment_md = "\n".join(f"- {t}" for t in treatments) if isinstance(treatments, list) else str(treatments)

        confidence_note = ""
        try:
            if float(confidence_val) < 0.7:
                confidence_note = (
                    "\n\n---\n*Note: moderate confidence — verify by comparing "
                    "with reference images or consult a local horticulturist.*"
                )
        except (ValueError, TypeError):
            pass

        formatted_markdown = (
            f"### **Plant**: {plant_species}\n\n"
            f"### **Diagnosis**: {issue_name}\n\n"
            f"#### **Symptoms**:\n{symptoms_md}\n\n"
            f"#### **Treatment & Care**:\n{treatment_md}"
            f"{confidence_note}"
        )

        return parsed_data, formatted_markdown, model_used


# Global singleton instance for FastAPI dependency injection
gemini_service = GeminiService()