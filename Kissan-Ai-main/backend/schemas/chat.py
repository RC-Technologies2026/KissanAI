from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class ChatMessageRequest(BaseModel):
    message: str


class ChatMessageResponse(BaseModel):
    id: UUID
    user_id: UUID
    message: str
    response: str
    created_at: datetime

    model_config = {"from_attributes": True}
