"""
Weather gate — blocks chemical application advice when conditions are unsafe.

Rules (from integration_README):
  - rain_probability > 40%  → unsafe (rain will wash away chemical)
  - wind_speed > 20 km/h    → unsafe (chemical drift risk)
"""
from typing import Optional


def is_weather_safe(rain_probability: float, wind_speed: float) -> bool:
    """Return True if weather conditions allow chemical application."""
    if rain_probability > 40:
        return False
    if wind_speed > 20:
        return False
    return True


def get_weather_block_reason(rain_probability: float, wind_speed: float) -> Optional[str]:
    """Return a human-readable reason if weather blocks application, else None."""
    reasons = []
    if rain_probability > 40:
        reasons.append(f"High rain probability ({rain_probability:.0f}%)")
    if wind_speed > 20:
        reasons.append(f"High wind speed ({wind_speed:.0f} km/h)")
    return "; ".join(reasons) if reasons else None
