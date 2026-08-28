from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class WeatherResponse(BaseModel):
    location: str
    temperature: float
    humidity: float
    rain_probability: float
    wind_speed: float
    description: str
    cached: bool
    cached_at: Optional[datetime] = None
