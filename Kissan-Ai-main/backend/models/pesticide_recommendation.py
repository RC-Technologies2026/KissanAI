from sqlalchemy import Column, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class PesticideRecommendation(Base):
    __tablename__ = "pesticide_recommendations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    disease_detection_id = Column(UUID(as_uuid=True), ForeignKey("disease_detections.id"), nullable=False)
    product_name = Column(String(255), nullable=False)
    dosage = Column(String(255), nullable=False)
    application_method = Column(String(255), nullable=True)
    weather_blocked = Column(Boolean, default=False)
    application_guidance = Column(String(500), nullable=True)
    safety_precautions = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    disease_detection = relationship("DiseaseDetection", back_populates="pesticide_recommendations")
