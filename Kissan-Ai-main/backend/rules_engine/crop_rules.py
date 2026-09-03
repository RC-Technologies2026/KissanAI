"""
Crop recommendation rules engine — Pakistan-optimized.

Scores crops against soil type, season (Rabi/Kharif), water availability
and optional location cues so recommendations actually change when the
farmer changes inputs. Covers Punjab, Sindh, KPK and Balochistan conditions.

New in this version:
  • Expanded crop database (35+ crops) including cash crops, orchards,
    vegetables and pulses common in Pakistan.
  • Fertilizer guidance per crop.
  • Pest / disease risk alerts per crop.
  • More granular irrigation schedules (seedling, vegetative, reproductive).
  • Optional area/latitude/longitude hints for regional adaptation.
"""
from typing import Optional

# ── Crop metadata ────────────────────────────────────────────────────────
# soils: soil types the crop grows well in
# seasons: cropping season(s) the crop belongs to ("rabi" and/or "kharif")
# water_need: relative irrigation requirement (low/medium/high)
# duration_days: typical days to maturity (for calendar hints)
# fertilizer: concise fertilizer recommendation
# risks: common pest/disease problems to watch
CROPS: dict[str, dict] = {
    # Rabi (winter) crops
    # Fertilizer brands: FFC (Sona Urea), Engro (DAP, Urea), Fatima (Urea, SOP), Pakarab (DAP), ICI (Zaiton SOP)
    "wheat":      {"soils": ["alluvial", "clay", "loamy"],         "seasons": ["rabi"],           "water_need": "medium", "duration_days": 140,
                    "fertilizer": "At sowing: 2 bags FFC/Engro DAP + 1 bag FFC Sona Urea per acre. At tillering (21-25 days after sowing): 1 bag FFC Sona Urea. For best results use Engro Zinc Urea if zinc-deficient.",
                    "risks": "Rust, aphid, powdery mildew."},
    "chickpea":   {"soils": ["clay", "loamy", "sandy"],            "seasons": ["rabi"],           "water_need": "low",    "duration_days": 120,
                    "fertilizer": "1 bag FFC/Engro DAP per acre at sowing. Avoid excess nitrogen — chickpea fixes its own. Inoculate seed with rhizobium culture for better yield.",
                    "risks": "Pod borer, wilt, blight."},
    "potato":     {"soils": ["sandy", "red", "loamy"],             "seasons": ["rabi"],           "water_need": "medium", "duration_days": 100,
                    "fertilizer": "2 bags FFC DAP + 1.5 bags FFC Sona Urea + 1 bag Fatima SOP (potash) at tuber initiation (30-35 days after planting). Use Engro Boron if soil is deficient.",
                    "risks": "Late blight, aphid, white grub."},
    "tobacco":    {"soils": ["red", "loamy"],                      "seasons": ["rabi"],           "water_need": "medium", "duration_days": 120,
                    "fertilizer": "2 bags FFC DAP + 2 bags FFC Sona Urea per acre. Split urea in 3 applications. High NPK needed for leaf quality.",
                    "risks": "Aphid, whitefly, mosaic virus."},
    "barley":     {"soils": ["loamy", "sandy", "clay"],            "seasons": ["rabi"],           "water_need": "low",    "duration_days": 115,
                    "fertilizer": "1 bag FFC DAP + 1 bag FFC Sona Urea per acre at sowing.",
                    "risks": "Rust, smut, aphid."},
    "mustard":    {"soils": ["loamy", "sandy", "clay"],            "seasons": ["rabi"],           "water_need": "low",    "duration_days": 110,
                    "fertilizer": "1 bag FFC DAP + 1 bag FFC Sona Urea per acre. Sulphur application (Engro Sulphur) beneficial for oil content.",
                    "risks": "Aphid, white rust, alternaria."},
    "canola":     {"soils": ["loamy", "clay", "alluvial"],         "seasons": ["rabi"],           "water_need": "medium", "duration_days": 140,
                    "fertilizer": "2 bags FFC/Engro DAP + 1.5 bags FFC Sona Urea per acre. Apply Engro Boron (1 kg/acre) if boron deficient. Split urea at sowing and rosette stage.",
                    "risks": "Aphid, white rust, sclerotinia."},
    "sunflower":  {"soils": ["loamy", "clay", "black"],            "seasons": ["rabi", "kharif"], "water_need": "medium", "duration_days": 100,
                    "fertilizer": "1.5 bags FFC DAP + 1.5 bags FFC Sona Urea per acre. Apply at sowing and 30 days after sowing.",
                    "risks": "Head rot, whitefly, downy mildew."},
    "lentil":     {"soils": ["loamy", "clay"],                     "seasons": ["rabi"],           "water_need": "low",    "duration_days": 130,
                    "fertilizer": "1 bag FFC DAP per acre. No extra nitrogen needed — inoculate rhizobium at sowing.",
                    "risks": "Root rot, rust, pod borer."},
    "garlic":     {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["rabi"],           "water_need": "medium", "duration_days": 130,
                    "fertilizer": "2 bags FYM + 1.5 bags FFC Sona Urea + 1 bag Fatima SOP per acre. Apply potash at bulb initiation (60 days).",
                    "risks": "Thrips, purple blotch, nematode."},
    "onion":      {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["rabi"],           "water_need": "medium", "duration_days": 120,
                    "fertilizer": "2 bags FFC DAP + 1.5 bags FFC Sona Urea + 1 bag ICI Zaiton SOP per acre. Split urea in 2-3 doses. Potash at bulb formation.",
                    "risks": "Thrips, purple blotch, downy mildew."},
    "tomato":     {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["rabi", "kharif"], "water_need": "medium", "duration_days": 100,
                    "fertilizer": "2 bags FFC DAP + 2 bags FFC Sona Urea + 1 bag Fatima SOP at flowering. Use Engro Cal-Nitrate for calcium. Foliar spray Engro Multi-K at fruit set.",
                    "risks": "Leaf curl virus, fruit borer, early blight."},
    "pea":        {"soils": ["loamy", "clay"],                     "seasons": ["rabi"],           "water_need": "low",    "duration_days": 95,
                    "fertilizer": "1 bag FFC DAP per acre. No extra nitrogen — pea fixes its own. Inoculate seed with rhizobium.",
                    "risks": "Powdery mildew, aphid, root rot."},

    # Kharif (summer/monsoon) crops
    "rice":       {"soils": ["alluvial", "clay"],                  "seasons": ["kharif"],         "water_need": "high",   "duration_days": 130,
                    "fertilizer": "2 bags FFC/Engro DAP + 2 bags FFC Sona Urea per acre. First urea at tillering (20-25 DAS), second at panicle initiation (55-60 DAS). Use Engro Zinc Urea for basmati rice.",
                    "risks": "Bacterial leaf blight, stem borer, blast."},
    "cotton":     {"soils": ["alluvial", "loamy", "black"],        "seasons": ["kharif"],         "water_need": "medium", "duration_days": 170,
                    "fertilizer": "2 bags FFC DAP + 2 bags FFC Sona Urea + 1 bag Fatima SOP per acre. First urea at 30 DAS, second at flowering. Potash at boll formation.",
                    "risks": "Whitefly, bollworm, leaf curl virus."},
    "groundnut":  {"soils": ["sandy", "red"],                      "seasons": ["kharif"],         "water_need": "low",    "duration_days": 120,
                    "fertilizer": "1 bag FFC DAP + gypsum (50 kg/acre) at flowering. Inoculate rhizobium at sowing for better pod fill.",
                    "risks": "Leaf spot, stem rot, thrips."},
    "watermelon": {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "medium", "duration_days": 90,
                    "fertilizer": "2 bags FYM + 1 bag FFC DAP + 1 bag FFC Sona Urea per acre. Apply potash (Fatima SOP) at fruit set for sweeter fruit.",
                    "risks": "Aphid, red pumpkin beetle, powdery mildew."},
    "millet":     {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "low",    "duration_days": 80,
                    "fertilizer": "1 bag FFC DAP + 0.5 bag FFC Sona Urea per acre.",
                    "risks": "Downy mildew, stem borer, shoot fly."},
    "sesame":     {"soils": ["sandy"],                             "seasons": ["kharif"],         "water_need": "low",    "duration_days": 95,
                    "fertilizer": "1 bag FFC DAP + 0.5 bag FFC Sona Urea per acre. Avoid excess water and nitrogen.",
                    "risks": "Phyllody, leaf curl, capsule borer."},
    "soybean":    {"soils": ["black"],                             "seasons": ["kharif"],         "water_need": "medium", "duration_days": 110,
                    "fertilizer": "1.5 bags FFC DAP per acre + rhizobium inoculation at sowing. Avoid nitrogen-heavy fertilizers.",
                    "risks": "Yellow mosaic, stem fly, pod borer."},
    "jowar":      {"soils": ["black"],                             "seasons": ["kharif"],         "water_need": "low",    "duration_days": 100,
                    "fertilizer": "1 bag FFC DAP + 1 bag FFC Sona Urea per acre.",
                    "risks": "Shoot fly, stem borer, grain mold."},
    "ragi":       {"soils": ["red"],                               "seasons": ["kharif"],         "water_need": "low",    "duration_days": 100,
                    "fertilizer": "1 bag FFC DAP + 0.5 bag FFC Sona Urea per acre.",
                    "risks": "Blast, stem borer, leaf spot."},
    "maize":      {"soils": ["alluvial", "loamy", "black"],        "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 110,
                    "fertilizer": "2 bags FFC DAP + 2 bags FFC Sona Urea + potash at knee-high stage (30 DAS). Split urea: half at sowing, half at knee-high. Engro Zinc Urea recommended.",
                    "risks": "Stem borer, armyworm, leaf blight."},
    "sugarcane":  {"soils": ["alluvial", "clay", "black"],         "seasons": ["kharif", "rabi"], "water_need": "high",   "duration_days": 330,
                    "fertilizer": "2 bags FFC DAP + 3 bags FFC Sona Urea + 2 bags Fatima MOP per acre. Apply in 3 splits: at planting, at tillering (60 DAS), at grand growth (120 DAS). Use Engro Sulphur for sugar content.",
                    "risks": "Top borer, mealybug, red rot."},
    "okra":       {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["kharif"],         "water_need": "medium", "duration_days": 55,
                    "fertilizer": "1.5 bags FFC DAP + 1 bag FFC Sona Urea per acre. Apply at 20-25 days after sowing.",
                    "risks": "Yellow vein mosaic, fruit borer, whitefly."},
    "chili":      {"soils": ["loamy", "sandy", "red"],             "seasons": ["kharif"],         "water_need": "medium", "duration_days": 170,
                    "fertilizer": "2 bags FFC DAP + 2 bags FFC Sona Urea + 1 bag ICI Zaiton SOP per acre. Potash at flowering improves color and pungency.",
                    "risks": "Thrips, mites, anthracnose, leaf curl."},
    "brinjal":    {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["kharif"],         "water_need": "medium", "duration_days": 130,
                    "fertilizer": "2 bags FYM + 1.5 bags FFC Sona Urea + 1 bag FFC DAP per acre.",
                    "risks": "Fruit borer, shoot borer, wilt."},
    "cucumber":   {"soils": ["loamy", "sandy"],                    "seasons": ["kharif"],         "water_need": "medium", "duration_days": 60,
                    "fertilizer": "1.5 bags FFC DAP + 1 bag FFC Sona Urea per acre. Foliar Engro Multi-K at flowering.",
                    "risks": "Downy mildew, aphid, fruit fly."},

    # Year-round / perennial options
    "vegetables": {"soils": ["loamy", "sandy", "red", "alluvial"], "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 70,
                    "fertilizer": "Balance NPK with FFC DAP + Sona Urea + Fatima SOP based on vegetable type. Compost base recommended. Foliar Engro Multi-K for leafy vegetables.",
                    "risks": "Varies by vegetable — inspect leaves regularly."},
    "fruits":     {"soils": ["loamy", "alluvial"],                 "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 365,
                    "fertilizer": "Farmyard manure annually + FFC NPK split in spring and autumn. Engro micronutrient mix for fruit orchards.",
                    "risks": "Fruit fly, scale insects, fungal spots."},
    "mango":      {"soils": ["loamy", "alluvial", "sandy"],        "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 365,
                    "fertilizer": "10-20 kg FYM per tree + 1 kg FFC/Engro NPK mixture twice yearly (Feb and July). Foliar Engro Calcium at fruit set. Engro Boron spray before flowering.",
                    "risks": "Mango hopper, fruit fly, anthracnose."},
    "citrus":     {"soils": ["loamy", "sandy", "alluvial"],        "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 365,
                    "fertilizer": "FYM + FFC DAP + Sona Urea twice a year (Feb and Sep). Engro Zinc and Engro Boron for micronutrients. ICI Zaiton SOP for fruit quality.",
                    "risks": "Citrus psylla, fruit borer, canker."},
    "banana":     {"soils": ["loamy", "alluvial", "sandy"],        "seasons": ["kharif", "rabi"], "water_need": "high",   "duration_days": 365,
                    "fertilizer": "FFC Sona Urea 200g + FFC DAP 100g + Fatima SOP 100g per plant per month. Split in 2 doses. Engro Boron and Zinc monthly.",
                    "risks": "Bunchy top, nematode, Panama wilt."},
    "date palm":  {"soils": ["sandy", "loamy"],                    "seasons": ["kharif", "rabi"], "water_need": "low",    "duration_days": 365,
                    "fertilizer": "FYM + FFC DAP + Sona Urea annually (1 kg DAP + 1 kg Urea per tree). Engro Sulphur for fruit quality.",
                    "risks": "Red palm weevil, lesser date moth."},
    "fodder":     {"soils": ["alluvial", "loamy", "clay"],        "seasons": ["kharif", "rabi"], "water_need": "medium", "duration_days": 60,
                    "fertilizer": "1-2 bags FFC Sona Urea after each cut. FFC DAP at sowing for root establishment.",
                    "risks": "Stem borer, aphid depending on species."},
}

DEFAULT_CROPS = ["wheat", "maize", "vegetables", "mango"]

_WATER_RANK = {"low": 1, "medium": 2, "high": 3}

# ── Crop → irrigation guidance ───────────────────────────────────────────
IRRIGATION_RULES: dict[str, dict] = {
    "wheat": {
        "schedule": "Crown root: skip if soil moist | Tillering: every 10-15 days | Grain filling: every 7-10 days",
        "water_amount_liters": 5000,
        "method": "Furrow or border irrigation",
    },
    "rice": {
        "schedule": "Keep 5-7 cm standing water from tillering to 2 weeks before harvest; refresh every 5-7 days",
        "water_amount_liters": 8000,
        "method": "Flood / puddled irrigation",
    },
    "cotton": {
        "schedule": "Germination: light frequent | Vegetative: every 12-15 days | Boll formation: every 7-10 days",
        "water_amount_liters": 4500,
        "method": "Furrow or drip irrigation",
    },
    "sugarcane": {
        "schedule": "Germination: every 10-12 days | Grand growth: every 7-10 days | Maturity: reduce irrigation",
        "water_amount_liters": 7000,
        "method": "Furrow irrigation",
    },
    "maize": {
        "schedule": "Seedling: every 8-10 days | Tasseling & grain filling: every 5-7 days (most critical)",
        "water_amount_liters": 4000,
        "method": "Drip or furrow irrigation",
    },
    "groundnut": {
        "schedule": "Vegetative: every 10-15 days | Flowering: reduce | Peg formation: resume every 10-12 days",
        "water_amount_liters": 3500,
        "method": "Furrow irrigation",
    },
    "potato": {
        "schedule": "Germination: every 5-7 days | Tuber initiation: keep moist | Maturation: taper off",
        "water_amount_liters": 4500,
        "method": "Drip or sprinkler irrigation",
    },
    "vegetables": {
        "schedule": "Every 3-5 days depending on crop; keep top soil consistently moist",
        "water_amount_liters": 3000,
        "method": "Drip irrigation",
    },
    "fruits": {
        "schedule": "Growing season: every 7-10 days | Dormant period: reduce to monthly or as needed",
        "water_amount_liters": 5000,
        "method": "Drip irrigation",
    },
    "mango": {
        "schedule": "Flowering/fruit set: every 10-14 days | Hot months: weekly | Winter: reduce",
        "water_amount_liters": 6000,
        "method": "Basin or drip irrigation",
    },
    "citrus": {
        "schedule": "Every 7-14 days depending on season; avoid waterlogging",
        "water_amount_liters": 5000,
        "method": "Drip irrigation",
    },
    "banana": {
        "schedule": "Summer: every 5-7 days | Winter: every 10-14 days; keep soil moist",
        "water_amount_liters": 7000,
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
        "schedule": "Every 12-15 days; avoid waterlogging especially at flowering",
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
    "barley": {
        "schedule": "Every 12-18 days; drought tolerant",
        "water_amount_liters": 2200,
        "method": "Furrow irrigation",
    },
    "mustard": {
        "schedule": "Rain-fed or 1-2 irrigations at flowering and siliqua formation",
        "water_amount_liters": 1800,
        "method": "Furrow irrigation",
    },
    "canola": {
        "schedule": "Every 10-15 days; critical at flowering and pod fill",
        "water_amount_liters": 3500,
        "method": "Furrow irrigation",
    },
    "sunflower": {
        "schedule": "Every 8-12 days; increase at bud and flowering stages",
        "water_amount_liters": 3500,
        "method": "Drip or furrow irrigation",
    },
    "lentil": {
        "schedule": "Rain-fed or 1-2 supplemental irrigations at flowering",
        "water_amount_liters": 1500,
        "method": "Furrow irrigation",
    },
    "garlic": {
        "schedule": "Every 7-10 days; keep soil moist but not waterlogged",
        "water_amount_liters": 3500,
        "method": "Drip irrigation",
    },
    "onion": {
        "schedule": "Every 7-10 days; reduce 2 weeks before harvest",
        "water_amount_liters": 4000,
        "method": "Drip irrigation",
    },
    "tomato": {
        "schedule": "Every 5-7 days; keep evenly moist during fruiting",
        "water_amount_liters": 3500,
        "method": "Drip irrigation",
    },
    "pea": {
        "schedule": "Every 10-15 days; avoid waterlogging",
        "water_amount_liters": 1800,
        "method": "Furrow irrigation",
    },
    "okra": {
        "schedule": "Every 5-7 days; drought during flowering reduces yield",
        "water_amount_liters": 3000,
        "method": "Drip irrigation",
    },
    "chili": {
        "schedule": "Every 5-8 days; avoid overhead irrigation",
        "water_amount_liters": 3500,
        "method": "Drip irrigation",
    },
    "brinjal": {
        "schedule": "Every 5-7 days; steady moisture improves fruit set",
        "water_amount_liters": 3500,
        "method": "Drip irrigation",
    },
    "cucumber": {
        "schedule": "Every 4-6 days; high water demand at fruiting",
        "water_amount_liters": 3500,
        "method": "Drip irrigation",
    },
    "date palm": {
        "schedule": "Every 10-20 days; deep infrequent watering",
        "water_amount_liters": 5000,
        "method": "Basin irrigation",
    },
    "fodder": {
        "schedule": "Every 7-10 days after each cut",
        "water_amount_liters": 3500,
        "method": "Furrow or flood irrigation",
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
    # normalize common variants
    if s in ("loam", "loamy soil"):
        return "loamy"
    if s in ("alluvial soil",):
        return "alluvial"
    if s in ("clayey", "clay soil"):
        return "clay"
    if s in ("sandy soil",):
        return "sandy"
    if s in ("black soil", "regur"):
        return "black"
    if s in ("red soil",):
        return "red"
    if s in ("silty", "silt"):
        return "loamy"  # silt behaves like loamy for our rules
    return s


def _normalize_season(season: Optional[str]) -> Optional[str]:
    if not season:
        return None
    s = season.strip().lower()
    if "rabi" in s or "winter" in s:
        return "rabi"
    if "kharif" in s or "summer" in s or "monsoon" in s:
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
    area_hectares: Optional[float] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
) -> tuple[list[str], str]:
    """
    Score and rank crops for the given soil type, season and water
    availability. Returns (crop_list, reasoning_string).

    - Soil type match is weighted heavily but is not a hard filter.
    - Season is a hard filter: only crops grown in the selected season (or
      grown across both seasons) are ever suggested.
    - Water availability affects ranking: crops whose water needs exceed
      what's available are penalized instead of being ignored.
    - Optional area / lat / lon give regional hints in the reasoning text.
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
            score += 4  # strong soil match
        elif soil_key:
            score -= 0.5  # grows, but not ideally suited

        need_rank = _WATER_RANK[info["water_need"]]
        if need_rank <= avail_rank:
            score += 2  # water needs comfortably met
        elif need_rank - avail_rank == 1:
            score += 0  # borderline, doable with scheduling
        else:
            score -= 2  # needs far more water than is available

        # Small boost for region-fit (southern Sindh → heat/drought tolerant)
        if latitude is not None and longitude is not None:
            # Lower Sindh / Balochistan coastal belts are drier
            if latitude < 28.0 and crop in ("millet", "sesame", "date palm", "groundnut"):
                score += 0.5
            # Northern Punjab/KPK cooler highlands suit rabi cereals
            if latitude > 32.0 and crop in ("wheat", "barley", "potato", "pea"):
                score += 0.5

        scored.append((crop, score))

    if not scored:
        crops = DEFAULT_CROPS
    else:
        scored.sort(key=lambda x: x[1], reverse=True)
        crops = [c for c, _ in scored[:5]]

    reasoning_parts = []
    if soil_key:
        reasoning_parts.append(f"{soil_key.title()} soil")
    if season_key:
        display_season = "Rabi (Winter)" if season_key == "rabi" else "Kharif (Summer)"
        reasoning_parts.append(display_season)
    reasoning_parts.append(f"{water_key.title()} water availability")

    region_hint = ""
    if latitude is not None and longitude is not None:
        if latitude < 28.0:
            region_hint = " Recommendations lean toward heat- and drought-tolerant crops for the southern zone."
        elif latitude > 32.0:
            region_hint = " Recommendations favor cool-season crops suitable for the northern zone."

    area_hint = ""
    if area_hectares is not None and area_hectares > 0:
        if area_hectares < 1:
            area_hint = " Your small plot suits intensive vegetables and high-value crops."
        elif area_hectares > 10:
            area_hint = " For your larger holding, mechanized field crops are prioritized."

    if scored:
        reasoning = (
            f"Top crops ranked for {', '.join(reasoning_parts)}."
            f"{region_hint}{area_hint} Crops best matched to your soil and irrigation capacity are listed first."
        )
    else:
        reasoning = "General crop recommendations based on common regional farming practices."

    return crops, reasoning


def _derive_next_irrigation(crop_key: str, schedule: str) -> str:
    """Derive a concise 'next irrigation' hint from the schedule text."""
    schedule_lower = schedule.lower()
    # Extract the first interval mentioned in the schedule.
    import re
    intervals = re.findall(r"every\s+(\d+)[-\s]*(\d*)\s*days", schedule_lower)
    if intervals:
        first, second = intervals[0]
        days = int(second) if second else int(first)
        if crop_key in ("rice", "sugarcane", "banana"):
            return f"Within {days} days (keep soil consistently moist)"
        return f"Every {days} days or when top soil feels dry"
    if "rain-fed" in schedule_lower:
        return "Only if no rain for 2+ weeks"
    if "standing water" in schedule_lower:
        return "Maintain standing water; check every 5-7 days"
    return "Check soil moisture every 2-3 days"


def get_irrigation_guidance(crop_name: str, water_availability: Optional[str] = None) -> dict:
    """
    Get irrigation guidance for a given crop, with an advisory note when the
    farmer's stated water availability is below what the crop typically needs.
    """
    crop_key = crop_name.lower().strip()
    guidance = dict(IRRIGATION_RULES.get(crop_key, DEFAULT_IRRIGATION))

    # Add a friendly next-irrigation hint if not already present.
    if "next_irrigation" not in guidance:
        guidance["next_irrigation"] = _derive_next_irrigation(crop_key, guidance.get("schedule", ""))

    water_key = _normalize_water(water_availability)
    crop_need = CROPS.get(crop_key, {}).get("water_need", "medium")
    if _WATER_RANK[water_key] < _WATER_RANK[crop_need]:
        guidance["note"] = (
            f"Your reported water availability ({water_key.title()}) is lower than what {crop_key.title()} "
            "typically needs. Use drip irrigation + mulch, or choose a shorter-duration variety to reduce water stress."
        )

    return guidance


def get_fertilizer_guidance(crop_name: str) -> str:
    """Return concise fertilizer guidance for a crop."""
    crop_key = crop_name.lower().strip()
    return CROPS.get(crop_key, {}).get(
        "fertilizer",
        "Apply a balanced NPK fertilizer based on soil test recommendations.",
    )


def get_pest_disease_alerts(crop_name: str) -> str:
    """Return common pest/disease alerts for a crop."""
    crop_key = crop_name.lower().strip()
    return CROPS.get(crop_key, {}).get(
        "risks",
        "Monitor regularly for common pests and diseases in your area.",
    )


def get_crop_metadata(crop_name: str) -> dict:
    """Return a full metadata snapshot for a crop (fertilizer, risks, duration, water need)."""
    crop_key = crop_name.lower().strip()
    info = CROPS.get(crop_key, {})
    return {
        "fertilizer": info.get("fertilizer", get_fertilizer_guidance(crop_name)),
        "risks": info.get("risks", get_pest_disease_alerts(crop_name)),
        "duration_days": info.get("duration_days"),
        "water_need": info.get("water_need", "medium"),
    }
