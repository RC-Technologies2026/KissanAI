from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class InsecticideRecommendationRequest(BaseModel):
    pest_detection_id: UUID
    lat: Optional[float] = None
    lon: Optional[float] = None


class InsecticideRecommendationResponse(BaseModel):
    id: UUID
    pest_detection_id: UUID
    product_name: str
    dosage: str
    application_method: Optional[str] = None
    weather_blocked: bool
    usage_guidance: Optional[str] = None
    safety_precautions: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
