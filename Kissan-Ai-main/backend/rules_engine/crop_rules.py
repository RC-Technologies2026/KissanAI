"""
Crop recommendation rules engine.

Maps soil types to suitable crops and generates irrigation guidance.
Based on Pakistani agricultural conditions (Punjab, Sindh regions).
"""
from typing import Optional

# Soil type → recommended crops
CROP_RULES: dict[str, list[str]] = {
    "alluvial": ["wheat", "rice", "sugarcane", "cotton", "maize"],
    "clay": ["wheat", "rice", "sugarcane", "chickpea"],
    "sandy": ["groundnut", "potato", "watermelon", "millet", "sesame"],
    "loamy": ["wheat", "maize", "cotton", "vegetables", "fruits"],
    "black": ["cotton", "sugarcane", "soybean", "jowar", "wheat"],
    "red": ["groundnut", "potato", "ragi", "tobacco", "vegetables"],
}

DEFAULT_CROPS = ["wheat", "rice", "maize", "vegetables"]

# Crop → irrigation guidance
IRRIGATION_RULES: dict[str, dict] = {
    "wheat": {
        "schedule": "Every 10-15 days during vegetative stage; every 7-10 days during grain filling",
        "water_amount_liters": 5000,
        "method": "Furrow irrigation",
    },
    "rice": {
        "schedule": "Maintain 5-7 cm standing water; refresh every 5-7 days",
        "water_amount_liters": 8000,
        "method": "Flood irrigation",
    },
    "cotton": {
        "schedule": "Every 12-15 days; increase to every 7-10 days during boll formation",
        "water_amount_liters": 4500,
        "method": "Furrow or drip irrigation",
    },
    "sugarcane": {
        "schedule": "Every 10-12 days during germination; every 7-10 days during grand growth",
        "water_amount_liters": 7000,
        "method": "Furrow irrigation",
    },
    "maize": {
        "schedule": "Every 8-10 days; critical at tasseling and grain filling",
        "water_amount_liters": 4000,
        "method": "Drip or furrow irrigation",
    },
    "groundnut": {
        "schedule": "Every 10-15 days; reduce during flowering, resume at peg formation",
        "water_amount_liters": 3500,
        "method": "Furrow irrigation",
    },
    "potato": {
        "schedule": "Every 5-7 days; maintain consistent soil moisture",
        "water_amount_liters": 4500,
        "method": "Drip or sprinkler irrigation",
    },
    "vegetables": {
        "schedule": "Every 3-5 days depending on crop; keep soil consistently moist",
        "water_amount_liters": 3000,
        "method": "Drip irrigation",
    },
    "fruits": {
        "schedule": "Every 7-10 days during growing season; reduce in dormant period",
        "water_amount_liters": 5000,
        "method": "Drip irrigation",
    },
}

DEFAULT_IRRIGATION = {
    "schedule": "Every 7-10 days; adjust based on soil moisture and weather",
    "water_amount_liters": 4000,
    "method": "Drip irrigation",
}


def get_crop_recommendation(soil_type: Optional[str]) -> tuple[list[str], str]:
    """
    Get recommended crops for a given soil type.
    Returns (crop_list, reasoning_string).
    """
    soil_key = (soil_type or "").lower().strip()
    crops = CROP_RULES.get(soil_key, DEFAULT_CROPS)

    if soil_key in CROP_RULES:
        reasoning = f"Based on {soil_key} soil type, these crops are well-suited for your plot conditions."
    else:
        reasoning = "General crop recommendations based on common regional farming practices."

    return crops, reasoning


def get_irrigation_guidance(crop_name: str) -> dict:
    """
    Get irrigation guidance for a given crop.
    Returns dict with schedule, water_amount_liters, method.
    """
    crop_key = crop_name.lower().strip()
    return IRRIGATION_RULES.get(crop_key, DEFAULT_IRRIGATION.copy())
