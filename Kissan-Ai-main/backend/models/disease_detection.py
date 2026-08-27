from sqlalchemy import Column, String, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class DiseaseDetection(Base):
    __tablename__ = "disease_detections"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    image_id = Column(UUID(as_uuid=True), ForeignKey("images.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    disease_name = Column(String(255), nullable=False)
    confidence_score = Column(Float, nullable=False)
    model_version = Column(String(50), nullable=True)
    detected_at = Column(DateTime, default=datetime.utcnow)

    image = relationship("Image", back_populates="disease_detection")
    pesticide_recommendations = relationship("PesticideRecommendation", back_populates="disease_detection")
