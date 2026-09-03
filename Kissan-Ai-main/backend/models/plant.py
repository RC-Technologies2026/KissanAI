from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class Plant(Base):
    __tablename__ = "plants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    plant_name = Column(String(255), nullable=False)
    species = Column(String(255), nullable=True)
    image_url = Column(String(500), nullable=True)
    health_status = Column(String(50), default="healthy")
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="plants")
    diagnoses = relationship("PlantDiagnosis", back_populates="plant", cascade="all, delete-orphan")
