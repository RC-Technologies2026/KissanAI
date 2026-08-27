from sqlalchemy import Column, String, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class IrrigationGuidance(Base):
    __tablename__ = "irrigation_guidance"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    crop_recommendation_id = Column(UUID(as_uuid=True), ForeignKey("crop_recommendations.id"), nullable=False)
    schedule = Column(String(255), nullable=False)
    water_amount_liters = Column(Float, nullable=False)
    method = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    crop_recommendation = relationship("CropRecommendation", back_populates="irrigation_guidance")
