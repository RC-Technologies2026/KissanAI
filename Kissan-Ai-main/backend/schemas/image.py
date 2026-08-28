from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class ImageUploadResponse(BaseModel):
    id: UUID
    image_url: str
    image_type: str
    public_id: Optional[str] = None
    uploaded_at: datetime

    model_config = {"from_attributes": True}
