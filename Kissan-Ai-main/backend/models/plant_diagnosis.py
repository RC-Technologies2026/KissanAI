from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class PlantDiagnosis(Base):
    __tablename__ = "plant_diagnoses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    plant_id = Column(UUID(as_uuid=True), ForeignKey("plants.id"), nullable=False)
    image_id = Column(UUID(as_uuid=True), ForeignKey("images.id"), nullable=False)
    issue_name = Column(String(255), nullable=False)
    issue_category = Column(String(50), nullable=True)
    confidence_score = Column(Float, nullable=True)
    diagnosis = Column(Text, nullable=True)
    detected_at = Column(DateTime, default=datetime.utcnow)

    plant = relationship("Plant", back_populates="diagnoses")
    image = relationship("Image", back_populates="plant_diagnosis")
