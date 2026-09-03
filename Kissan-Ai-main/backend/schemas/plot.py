from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


# --- Plot ---

class PlotCreate(BaseModel):
    name: str
    location: Optional[str] = None
    area_hectares: Optional[float] = None
    soil_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class PlotUpdate(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    area_hectares: Optional[float] = None
    soil_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class PlotResponse(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    location: Optional[str] = None
    area_hectares: Optional[float] = None
    soil_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Plot Crop ---

class PlotCropCreate(BaseModel):
    crop_type: str
    sowing_date: Optional[datetime] = None
    growth_stage: Optional[str] = None


class PlotCropResponse(BaseModel):
    id: UUID
    plot_id: UUID
    crop_type: str
    sowing_date: Optional[datetime] = None
    growth_stage: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Plot Livestock ---

class PlotLivestockCreate(BaseModel):
    species: str
    count: int
    health_status: Optional[str] = None


class PlotLivestockResponse(BaseModel):
    id: UUID
    plot_id: UUID
    species: str
    count: int
    health_status: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# --- Plot with nested crops/livestock (GET /api/plots/{id}) ---

class PlotDetailResponse(PlotResponse):
    plot_crops: List[PlotCropResponse] = []
    plot_livestock: List[PlotLivestockResponse] = []
