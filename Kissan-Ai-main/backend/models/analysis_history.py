from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class AnalysisHistory(Base):
    __tablename__ = "analysis_history"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    analysis_type = Column(String(50), nullable=False)
    reference_id = Column(UUID(as_uuid=True), nullable=False)
    result_snapshot = Column(JSONB, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="analysis_history")
