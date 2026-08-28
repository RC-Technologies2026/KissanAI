from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class AnalysisHistoryResponse(BaseModel):
    id: UUID
    user_id: UUID
    analysis_type: str
    reference_id: UUID
    result_snapshot: dict
    created_at: datetime

    model_config = {"from_attributes": True}
