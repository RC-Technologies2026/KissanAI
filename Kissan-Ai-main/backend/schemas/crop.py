from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class CropRecommendationRequest(BaseModel):
    plot_id: UUID
    season: Optional[str] = None
    soil_type: Optional[str] = None
    water_availability: Optional[str] = None


class CropRecommendationResponse(BaseModel):
    id: UUID
    plot_id: UUID
    recommended_crops: str
    reasoning: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class IrrigationGuideResponse(BaseModel):
    id: UUID
    crop_recommendation_id: UUID
    schedule: str
    water_amount_liters: float
    method: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
