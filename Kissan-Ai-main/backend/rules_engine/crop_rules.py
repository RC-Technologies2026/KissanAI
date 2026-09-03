"""
Crop recommendation rules engine.

Scores crops against soil type, season (Rabi/Kharif) and water availability
so that recommendations actually change when the farmer changes any of
those inputs. Based on Pakistani agricultural conditions (Punjab, Sindh
regions).
"""
from typing import Optional

# ── Crop metadata ────────────────────────────────────────────────────────
# soils: soil types the crop grows well in
# seasons: cropping season(s) the crop belongs to ("rabi" and/or "kharif")
# water_need: relative irrigation requirement of the crop
CROPS: dict[str, dict] = {
    "wheat":      {"soils": ["alluvial", "clay", "loamy"],         "seasons": ["rabi"],           "water_need": "medium"},
    "chickpea":   {"soils": ["clay", "loamy", "sandy"],            "seasons": ["rabi"],           "water_need": "low"},
    "potato":     {"soils": ["sandy", "red", "loamy"],             "seasons": ["rabi"],           "water_need": "medium"},
    "tobacco":    {"soils": ["red", "loamy"],                      "seasons": ["rabi"],           "water_need": "medium"},
    "rice":       {"soils": ["alluvial", "clay"],                  "seasons": ["kharif"],         "water_need": "high"},
    "cotton":     {"soils": ["alluvial", "loamy", "black"],        "seasons": ["kharif"],         "water_need": "medium"},
    "groundnut":  {"soils": ["sandy", "red"],                      "seasons": ["kharif"],         "water_need": "low"},
    "watermelon": {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "medium"},
    "millet":     {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "low"},
    "sesame":     {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "low"},
    "soybean":    {"soils": ["black"],                             "seasons": ["kharif"],         "water_need": "medium"},
    "jowar":      {"soils": ["black"],                             "seasons": ["kharif"],         "water_need": "low"},
    "ragi":       {"soils": ["red"],                               "seasons": ["kharif"],         "water_need": "low"},
    "sugarcane":  {"soils": ["alluvial", "clay", "black"],         "seasons": ["kharif", "rabi"], "water_need": "high"},
    "maize":      {"soils": ["alluvial", "loamy", "black"],        "seasons": ["kharif", "rabi"], "water_need": "medium"},
    "vegetables": {"soils": ["loamy", "sandy", "red", "alluvial"], "seasons": ["kharif", "rabi"], "water_need": "medium"},
    "fruits":     {"soils": ["loamy", "alluvial"],                 "seasons": ["kharif", "rabi"], "water_need": "medium"},
}

DEFAULT_CROPS = ["wheat", "rice", "maize", "vegetables"]

_WATER_RANK = {"low": 1, "medium": 2, "high": 3}

# ── Crop → irrigation guidance ───────────────────────────────────────────
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
    "chickpea": {
        "schedule": "Rain-fed or 1-2 supplemental irrigations at flowering and pod filling",
        "water_amount_liters": 1500,
        "method": "Furrow irrigation",
    },
    "millet": {
        "schedule": "Every 12-18 days; drought tolerant, minimal irrigation needed",
        "water_amount_liters": 2000,
        "method": "Furrow irrigation",
    },
    "sesame": {
        "schedule": "Every 12-15 days; avoid waterlogging",
        "water_amount_liters": 2000,
        "method": "Furrow irrigation",
    },
    "soybean": {
        "schedule": "Every 8-12 days; critical at flowering and pod filling",
        "water_amount_liters": 3500,
        "method": "Furrow or drip irrigation",
    },
    "jowar": {
        "schedule": "Every 12-18 days; drought tolerant",
        "water_amount_liters": 2000,
        "method": "Furrow irrigation",
    },
    "ragi": {
        "schedule": "Every 10-15 days; tolerant of low water availability",
        "water_amount_liters": 2000,
        "method": "Furrow irrigation",
    },
    "tobacco": {
        "schedule": "Every 7-10 days; consistent moisture needed at establishment",
        "water_amount_liters": 4000,
        "method": "Drip or sprinkler irrigation",
    },
    "watermelon": {
        "schedule": "Every 6-8 days; increase during fruit development",
        "water_amount_liters": 4000,
        "method": "Drip irrigation",
    },
}

DEFAULT_IRRIGATION = {
    "schedule": "Every 7-10 days; adjust based on soil moisture and weather",
    "water_amount_liters": 4000,
    "method": "Drip irrigation",
}


def _normalize_soil(soil_type: Optional[str]) -> Optional[str]:
    if not soil_type:
        return None
    s = soil_type.strip().lower()
    # normalize plurals/variants like "loamy" already fine; handle "loam" -> "loamy"
    if s == "loam":
        return "loamy"
    return s


def _normalize_season(season: Optional[str]) -> Optional[str]:
    if not season:
        return None
    s = season.strip().lower()
    if "rabi" in s or "winter" in s:
        return "rabi"
    if "kharif" in s or "summer" in s:
        return "kharif"
    return None


def _normalize_water(water_availability: Optional[str]) -> str:
    if not water_availability:
        return "medium"
    w = water_availability.strip().lower()
    return w if w in _WATER_RANK else "medium"


def get_crop_recommendation(
    soil_type: Optional[str],
    season: Optional[str] = None,
    water_availability: Optional[str] = None,
) -> tuple[list[str], str]:
    """
    Score and rank crops for the given soil type, season and water
    availability. Returns (crop_list, reasoning_string).

    - Soil type match is weighted heavily but is not a hard filter (a crop
      that grows fine in other soils can still be suggested, just ranked lower).
    - Season is a hard filter: only crops grown in the selected season (or
      grown across both seasons) are ever suggested.
    - Water availability affects ranking: crops whose water needs exceed
      what's available are penalized instead of being ignored.
    """
    soil_key = _normalize_soil(soil_type)
    season_key = _normalize_season(season)
    water_key = _normalize_water(water_availability)
    avail_rank = _WATER_RANK[water_key]

    candidates = list(CROPS.items())
    if season_key:
        candidates = [(c, info) for c, info in candidates if season_key in info["seasons"]]

    scored: list[tuple[str, float]] = []
    for crop, info in candidates:
        score = 0.0
        if soil_key and soil_key in info["soils"]:
            score += 3
        elif soil_key:
            score -= 1  # grows, but not ideally suited to this soil

        need_rank = _WATER_RANK[info["water_need"]]
        if need_rank <= avail_rank:
            score += 2  # water needs are comfortably met
        elif need_rank - avail_rank == 1:
            score += 0  # borderline, doable with careful scheduling
        else:
            score -= 2  # needs far more water than is available

        scored.append((crop, score))

    if not scored:
        # No crop matches the season filter (shouldn't normally happen) —
        # fall back to a generic, season-agnostic list.
        crops = DEFAULT_CROPS
    else:
        scored.sort(key=lambda x: x[1], reverse=True)
        crops = [c for c, _ in scored[:5]]

    reasoning_parts = []
    if soil_key:
        reasoning_parts.append(f"{soil_key} soil")
    if season_key:
        reasoning_parts.append(f"{season_key} season")
    reasoning_parts.append(f"{water_key} water availability")

    if scored:
        reasoning = (
            f"Ranked for {', '.join(reasoning_parts)} — crops best suited to your soil "
            "and irrigation capacity are listed first."
        )
    else:
        reasoning = "General crop recommendations based on common regional farming practices."

    return crops, reasoning


def get_irrigation_guidance(crop_name: str, water_availability: Optional[str] = None) -> dict:
    """
    Get irrigation guidance for a given crop, with an advisory note when the
    farmer's stated water availability is below what the crop typically needs.
    """
    crop_key = crop_name.lower().strip()
    guidance = dict(IRRIGATION_RULES.get(crop_key, DEFAULT_IRRIGATION))

    water_key = _normalize_water(water_availability)
    crop_need = CROPS.get(crop_key, {}).get("water_need", "medium")
    if _WATER_RANK[water_key] < _WATER_RANK[crop_need]:
        guidance["note"] = (
            f"Your reported water availability ({water_key}) is lower than what {crop_key} "
            "typically needs — consider drip irrigation, mulching, or a shorter-duration "
            "variety to reduce water stress."
        )

    return guidance
