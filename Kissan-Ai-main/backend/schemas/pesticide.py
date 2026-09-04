from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class PesticideProduct(BaseModel):
    product_name: str
    dosage: str
    application_method: Optional[str] = None
    application_guidance: Optional[str] = None
    safety_precautions: Optional[str] = None


class PesticideRecommendationRequest(BaseModel):
    disease_detection_id: UUID
    lat: Optional[float] = None
    lon: Optional[float] = None


class PesticideRecommendationResponse(BaseModel):
    id: UUID
    disease_detection_id: UUID
    products: List[PesticideProduct]
    weather_blocked: bool
    created_at: datetime

    model_config = {"from_attributes": True}
