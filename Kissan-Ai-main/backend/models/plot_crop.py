from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class PlotCrop(Base):
    __tablename__ = "plot_crops"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    plot_id = Column(UUID(as_uuid=True), ForeignKey("plots.id"), nullable=False)
    crop_type = Column(String(100), nullable=False)
    sowing_date = Column(DateTime, nullable=True)
    growth_stage = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    plot = relationship("Plot", back_populates="plot_crops")
