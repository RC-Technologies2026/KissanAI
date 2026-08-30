from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class DiseaseDetectionResponse(BaseModel):
    id: Optional[UUID] = None
    image_id: UUID
    disease_name: str
    disease_category: Optional[str] = None
    confidence_score: float
    model_version: str
    detected_at: datetime
    diagnosis: Optional[str] = None


class DiseaseFallbackResponse(BaseModel):
    message: str
    top_candidates: List[str]
    confidence_score: float
    threshold: float
    image_id: UUID
