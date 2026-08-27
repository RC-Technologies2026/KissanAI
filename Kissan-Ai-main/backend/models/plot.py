from sqlalchemy import Column, String, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class Plot(Base):
    __tablename__ = "plots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name = Column(String(255), nullable=False)
    location = Column(String(255), nullable=True)
    area_hectares = Column(Float, nullable=True)
    soil_type = Column(String(100), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="plots")
    plot_crops = relationship("PlotCrop", back_populates="plot")
    plot_livestock = relationship("PlotLivestock", back_populates="plot")
    crop_recommendations = relationship("CropRecommendation", back_populates="plot")
