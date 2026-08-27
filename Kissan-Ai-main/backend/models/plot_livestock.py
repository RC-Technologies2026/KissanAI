from sqlalchemy import Column, String, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db import Base
import uuid
from datetime import datetime

class PlotLivestock(Base):
    __tablename__ = "plot_livestock"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    plot_id = Column(UUID(as_uuid=True), ForeignKey("plots.id"), nullable=False)
    species = Column(String(100), nullable=False)
    count = Column(Integer, nullable=False)
    health_status = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    plot = relationship("Plot", back_populates="plot_livestock")
