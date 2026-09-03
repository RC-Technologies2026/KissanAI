from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class DiseaseDetectionResponse(BaseModel):
    id: Optional[UUID] = None
    image_id: UUID
    crop_name: Optional[str] = None
    disease_name: str
    disease_category: Optional[str] = None
    confidence_score: Optional[float] = None
    model_version: Optional[str] = None
    detected_at: Optional[datetime] = None
    diagnosis: Optional[str] = None


class DiseaseFallbackResponse(BaseModel):
    message: str = "Photo unclear — please retake"
    top_candidates: List[str] = []
    confidence_score: float = 0.0
    threshold: float = 0.0
    image_id: Optional[UUID] = None
