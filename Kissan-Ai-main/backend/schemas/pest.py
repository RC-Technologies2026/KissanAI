from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class PestDetectionResponse(BaseModel):
    id: Optional[UUID] = None
    image_id: UUID
    crop_name: Optional[str] = None
    pest_name: str
    pest_category: Optional[str] = None
    confidence_score: Optional[float] = None
    model_version: Optional[str] = None
    detected_at: Optional[datetime] = None
    diagnosis: Optional[str] = None


class PestFallbackResponse(BaseModel):
    message: str = "Photo unclear — please retake"
    top_candidates: List[str] = []
    confidence_score: float = 0.0
    threshold: float = 0.0
    image_id: Optional[UUID] = None
