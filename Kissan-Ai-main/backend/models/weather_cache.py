from sqlalchemy import Column, String, Float, DateTime
from sqlalchemy.dialects.postgresql import UUID
from db import Base
import uuid
from datetime import datetime

class WeatherCache(Base):
    __tablename__ = "weather_cache"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    location = Column(String(255), nullable=False)
    temperature = Column(Float, nullable=False)
    humidity = Column(Float, nullable=False)
    rain_probability = Column(Float, nullable=False)
    wind_speed = Column(Float, nullable=False)
    cached_at = Column(DateTime, default=datetime.utcnow)
