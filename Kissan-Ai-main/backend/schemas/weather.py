from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List


class WeatherResponse(BaseModel):
    location: str
    temperature: float
    feels_like: Optional[float] = None
    humidity: float
    rain_probability: float
    wind_speed: float
    description: str
    cached: bool
    cached_at: Optional[datetime] = None


class DailyForecastItem(BaseModel):
    day: str
    high: int
    low: int
    condition: str
    condition_icon: str
    rain_chance: int
    humidity: int
    wind_speed: int


class HourlyForecastItem(BaseModel):
    hour: str
    temp: int
    condition_icon: str
    rain_chance: int


class WeatherForecastResponse(BaseModel):
    location: str
    current: WeatherResponse
    hourly: List[HourlyForecastItem] = []
    daily: List[DailyForecastItem]
    alerts: List[str] = []
