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
        Asynchronously generates an AI response using the configured Gemini client.
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


# Global service instance for FastAPI dependency injection
gemini_service = GeminiService()