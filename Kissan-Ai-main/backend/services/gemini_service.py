import os
import json
import asyncio
import logging
import re
from typing import Optional, List, Union, Tuple, Any, Dict
from fastapi import HTTPException, status
from google import genai
from prompts import KISSAN_SYSTEM_PROMPT
from rules_engine.pesticide_rules import PESTICIDE_RULES
from rules_engine.insecticide_rules import INSECTICIDE_RULES

logger = logging.getLogger(__name__)

# Fixed English category keys the rules engine understands. Gemini is asked
# to classify into exactly one of these (in addition to giving a localized
# display name), so pesticide/insecticide lookups never depend on matching
# free-form or translated text.
DISEASE_CATEGORIES = list(PESTICIDE_RULES.keys()) + ["healthy"]
PEST_CATEGORIES = list(INSECTICIDE_RULES.keys()) + ["none"]

models_to_try = [
    "gemini-3.6-flash",
    "gemini-3.7-flash",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-3.1-pro-preview",
    "gemini-3-flash-preview",
    "gemini-2.5-flash",
    "gemini-2.5-pro",
    "gemini-2.5-flash-lite",
    "gemini-flash-latest",
    "gemini-pro-latest",
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
  ]
}}"""


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
  ]
}}"""


class GeminiService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None
        self.default_models = models_to_try

        # Low-hallucination configuration settings accessed directly via genai.types
        self.config = genai.types.GenerateContentConfig(
            system_instruction=KISSAN_SYSTEM_PROMPT,
            temperature=0.2,
            top_p=0.85,
            top_k=30,
            max_output_tokens=1500,
        )

    async def generate_content_with_fallback(
        self,
        contents: Union[str, List[Any]],
        config: Optional[Any] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 15.0,
    ) -> Tuple[str, str]:
        """
        Asynchronously generates content iterating through fallback models on error or timeout.
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
                    return response.text.strip(), model
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
        timeout: float = 15.0,
    ) -> str:
        """Asynchronously generates a text response with fallback support."""
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
        timeout: float = 15.0,
        crop_name: Optional[str] = None,
    ) -> Tuple[Dict[str, Any], str, str]:
        """
        Diagnoses a leaf image in the requested language and returns (parsed_json_dict, formatted_markdown, model_used).
        """
        active_prompt = prompt or build_diagnosis_prompt(language=language, crop_name=crop_name)

        contents = [
            genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            active_prompt,
        ]

        raw_response, model_used = await self.generate_content_with_fallback(
            contents=contents,
            models_list=models_list,
            timeout=timeout,
        )

        # Parse JSON output from Gemini response
        parsed_data: Dict[str, Any] = {}
        try:
            # Strip markdown json block wrappers if present
            cleaned_json = raw_response
            if "```" in cleaned_json:
                match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned_json)
                if match:
                    cleaned_json = match.group(1)
            parsed_data = json.loads(cleaned_json)
        except Exception as json_err:
            logger.warning("Failed to parse direct JSON from Gemini: %s. Using text extraction.", json_err)
            # Fallback regex extraction for disease_name
            disease_match = re.search(r'"disease_name"\s*:\s*"([^"]+)"', raw_response) or re.search(
                r"(?:Disease Name|Diagnosis|بیماری کا نام|ਬਿਮਾਰੀ ਦਾ ਨਾਂ)\s*:\s*([^\n\r]+)", raw_response, re.IGNORECASE
            )
            parsed_data["disease_name"] = disease_match.group(1).strip() if disease_match else "Plant Disease Diagnosis"
            parsed_data["confidence_score"] = 0.95
            parsed_data["symptoms"] = ["See detailed diagnosis below."]
            parsed_data["treatment"] = [raw_response]

        # Guarantee crop_name is present even if Gemini omitted it
        if not parsed_data.get("crop_name"):
            crop_fallback = re.search(r'"crop_name"\s*:\s*"([^"]+)"', raw_response)
            parsed_data["crop_name"] = (
                crop_fallback.group(1).strip() if crop_fallback else (crop_name or "Unknown crop")
            )

        # Construct readable localized markdown for UI display
        identified_crop = parsed_data.get("crop_name")
        disease_name = parsed_data.get("disease_name", "Plant Disease Diagnosis")
        symptoms = parsed_data.get("symptoms", [])
        treatments = parsed_data.get("treatment", [])

        symptoms_md = "\n".join(f"- {s}" for s in symptoms) if isinstance(symptoms, list) else str(symptoms)
        treatment_md = "\n".join(f"- {t}" for t in treatments) if isinstance(treatments, list) else str(treatments)

        formatted_markdown = (
            f"### **Crop**: {identified_crop}\n\n"
            f"### **Diagnosis**: {disease_name}\n\n"
            f"#### **Symptoms**:\n{symptoms_md}\n\n"
            f"#### **Treatment & Management**:\n{treatment_md}"
        )

        return parsed_data, formatted_markdown, model_used

    async def diagnose_pest_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        language: str = "english",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 15.0,
        crop_name: Optional[str] = None,
    ) -> Tuple[Dict[str, Any], str, str]:
        """
        Identifies a pest in a crop image in the requested language.
        Returns (parsed_json_dict, formatted_markdown, model_used).
        """
        active_prompt = prompt or build_pest_prompt(language=language, crop_name=crop_name)

        contents = [
            genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            active_prompt,
        ]

        raw_response, model_used = await self.generate_content_with_fallback(
            contents=contents,
            models_list=models_list,
            timeout=timeout,
        )

        # Parse JSON output from Gemini response
        parsed_data: Dict[str, Any] = {}
        try:
            cleaned_json = raw_response
            if "```" in cleaned_json:
                match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned_json)
                if match:
                    cleaned_json = match.group(1)
            parsed_data = json.loads(cleaned_json)
        except Exception as json_err:
            logger.warning("Failed to parse pest JSON from Gemini: %s. Using text extraction.", json_err)
            pest_match = re.search(r'"pest_name"\s*:\s*"([^"]+)"', raw_response) or re.search(
                r"(?:Pest Name|Insect|کیڑا|ਕੀੜਾ)\s*:\s*([^\n\r]+)", raw_response, re.IGNORECASE
            )
            parsed_data["pest_name"] = pest_match.group(1).strip() if pest_match else "Pest Identification"
            parsed_data["confidence_score"] = 0.95
            parsed_data["damage_symptoms"] = ["See detailed report below."]
            parsed_data["recommended_pesticide"] = [raw_response]

        # Guarantee crop_name is present even if Gemini omitted it
        if not parsed_data.get("crop_name"):
            crop_fallback = re.search(r'"crop_name"\s*:\s*"([^"]+)"', raw_response)
            parsed_data["crop_name"] = (
                crop_fallback.group(1).strip() if crop_fallback else (crop_name or "Unknown crop")
            )

        # Construct readable localized markdown for UI display
        identified_crop = parsed_data.get("crop_name")
        pest_name = parsed_data.get("pest_name", "Pest Identification")
        damage_symptoms = parsed_data.get("damage_symptoms", [])
        pesticides = parsed_data.get("recommended_pesticide", [])

        symptoms_md = "\n".join(f"- {s}" for s in damage_symptoms) if isinstance(damage_symptoms, list) else str(damage_symptoms)
        pesticide_md = "\n".join(f"- {p}" for p in pesticides) if isinstance(pesticides, list) else str(pesticides)

        formatted_markdown = (
            f"### **Crop**: {identified_crop}\n\n"
            f"### **Identified Pest**: {pest_name}\n\n"
            f"#### **Damage Symptoms**:\n{symptoms_md}\n\n"
            f"#### **Recommended Pesticide & Treatment**:\n{pesticide_md}"
        )

        return parsed_data, formatted_markdown, model_used


# Global singleton instance for FastAPI dependency injection
gemini_service = GeminiService()