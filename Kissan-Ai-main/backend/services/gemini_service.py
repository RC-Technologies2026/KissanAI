import os
import asyncio
import logging
from typing import Optional, List, Union, Tuple, Any
from fastapi import HTTPException, status
from google import genai
from prompts import KISSAN_SYSTEM_PROMPT

logger = logging.getLogger(__name__)

DEFAULT_FALLBACK_MODELS = [
    "gemini-2.5-flash",
    "gemini-1.5-flash",
    "gemini-1.5-pro",
]


class GeminiService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None
        self.default_models = DEFAULT_FALLBACK_MODELS

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
        timeout: float = 20.0,
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
                    return response.text, model
            except asyncio.TimeoutError as e:
                last_exception = e
                logger.warning("Model %s timed out after %.1fs, switching to fallback...", model, timeout)
            except Exception as e:
                last_exception = e
                logger.warning("Model %s failed with error: %s, switching to fallback...", model, str(e))

        logger.error("All AI models (%s) failed. Last error: %s", ", ".join(models), str(last_exception))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="All AI models are currently busy. Please try again.",
        )

    async def generate_response(
        self,
        message: str,
        models_list: Optional[List[str]] = None,
        timeout: float = 20.0,
    ) -> str:
        """
        Asynchronously generates a text response with fallback support.
        """
        text, _ = await self.generate_content_with_fallback(
            contents=message,
            models_list=models_list,
            timeout=timeout,
        )
        return text

    async def analyze_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        prompt: Optional[str] = None,
        models_list: Optional[List[str]] = None,
        timeout: float = 20.0,
    ) -> Tuple[str, str]:
        """
        Asynchronously analyzes an image with Gemini Vision with model fallback support.
        Returns a tuple of (diagnosis_text, model_used).
        """
        default_prompt = (
            "Diagnose the plant disease in this leaf image and provide a structured response:\n"
            "- **Disease Name**: (Identified disease or healthy)\n"
            "- **Symptoms Observed**: (Key visual signs on the leaf)\n"
            "- **Immediate Action Steps**: (What the farmer should do first)\n"
            "- **Treatment Options**:\n"
            "  - **Organic Solutions**: (Bio-fungicides, natural remedies)\n"
            "  - **Chemical Treatments & Dosages**: (Generic chemical names, exact dosage per acre/liter, safety gear)"
        )

        contents = [
            genai.types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            prompt or default_prompt,
        ]

        return await self.generate_content_with_fallback(
            contents=contents,
            models_list=models_list,
            timeout=timeout,
        )


# Global service instance for FastAPI dependency injection
gemini_service = GeminiService()