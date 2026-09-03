from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime
from typing import Optional, List


# ---------------------------------------------------------------------------
# Plant CRUD schemas
# ---------------------------------------------------------------------------

class PlantCreate(BaseModel):
    """Request body for creating / registering a new Plant."""
    plant_name: str = Field(..., min_length=1, max_length=255, description="Common name of the plant, e.g. 'Rose', 'Tulsi', 'Money Plant'")
    species: Optional[str] = Field(None, max_length=255, description="Species / variety, e.g. 'Hibiscus rosa-sinensis'")
    image_url: Optional[str] = Field(None, max_length=500, description="Optional photo URL of the plant")
    health_status: Optional[str] = Field("healthy", max_length=50, description="Current health status: healthy, sick, recovering, etc.")
    notes: Optional[str] = Field(None, description="Free-text notes about the plant")


class PlantResponse(BaseModel):
    """Single plant returned from the API."""
    id: UUID
    user_id: UUID
    plant_name: str
    species: Optional[str] = None
    image_url: Optional[str] = None
    health_status: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Plant Diagnosis schemas
# ---------------------------------------------------------------------------

class PlantDiagnosisResponse(BaseModel):
    """Returned after a successful plant diagnosis."""
    id: Optional[UUID] = None
    plant_id: UUID
    image_id: UUID
    issue_name: str
    issue_category: Optional[str] = None
    confidence_score: Optional[float] = None
    diagnosis: Optional[str] = None
    detected_at: Optional[datetime] = None


class PlantDiagnosisFallbackResponse(BaseModel):
    """Returned when the uploaded image is genuinely unusable."""
    message: str = "Photo unclear — please retake"
    top_candidates: List[str] = []
    confidence_score: float = 0.0
    threshold: float = 0.0
    image_id: Optional[UUID] = None
