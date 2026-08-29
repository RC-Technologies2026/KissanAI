import os
from typing import Optional
from google import genai
from prompts import KISSAN_SYSTEM_PROMPT


class GeminiService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=self.api_key) if self.api_key else None

        # Low-hallucination configuration settings accessed directly via genai.types
        self.config = genai.types.GenerateContentConfig(
            system_instruction=KISSAN_SYSTEM_PROMPT,
            temperature=0.2,
            top_p=0.85,
            top_k=30,
            max_output_tokens=1500,
        )

    async def generate_response(self, message: str, model: str = "gemini-2.5-flash") -> str:
        """
        Asynchronously generates an AI text response using the configured Gemini client.
        """
        if not self.client:
            raise ValueError("Gemini API key is not configured. Set GEMINI_API_KEY in your environment.")

        # Non-blocking async generation call using client.aio
        response = await self.client.aio.models.generate_content(
            model=model,
            contents=message,
            config=self.config,
        )
        return response.text

    async def analyze_image(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        prompt: Optional[str] = None,
        model: str = "gemini-2.5-flash",
    ) -> str:
        """
        Asynchronously analyzes an image with Gemini Vision.
        """
        if not self.client:
            raise ValueError("Gemini API key is not configured. Set GEMINI_API_KEY in your environment.")

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

        response = await self.client.aio.models.generate_content(
            model=model,
            contents=contents,
            config=self.config,
        )
        return response.text


# Global service instance for FastAPI dependency injection
gemini_service = GeminiService()