"""
Insecticide rules engine — maps pest names to insecticide recommendations.

Golden Rule: All chemical/dosage output comes ONLY from this Rules Engine.
AI model output → passed here → this engine writes the recommendation.
"""
from typing import Optional

# Pest → insecticide recommendation mapping
# Brands: Syngenta, Bayer, FMC, Engro, Nova, ICI/Lucky Core, Tara Crop, Jaffer Agro
INSECTICIDE_RULES: dict[str, dict] = {
    "aphids": {
        "product_name": "Syngenta - Confidor 200SL (Imidacloprid)",
        "dosage": "0.3 mL/L water (or 120 mL/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first sign of aphid colony (clusters on leaf undersides and growing tips). Target undersides of leaves. Repeat after 14 days if infestation persists. Also controls whitefly.",
        "safety_precautions": "Toxic to bees — do not spray during flowering. Wear gloves and mask during application.",
    },
    "whitefly": {
        "product_name": "Syngenta - Actara 25WG (Thiamethoxam)",
        "dosage": "0.5 g/L water (or 200 g/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply early morning or late evening when whiteflies are active. Cover leaf undersides thoroughly. Critical for cotton, tomato, chili. Repeat after 10-14 days.",
        "safety_precautions": "Toxic to bees and beneficial insects. Avoid spraying during bloom. Wear PPE.",
    },
    "armyworm": {
        "product_name": "FMC - Coragen 18.5SC (Chlorantraniliprole)",
        "dosage": "0.5 mL/L water (or 200 mL/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at early larval stage (small caterpillars visible). Spray in evening when larvae feed on leaf surface. Very effective on maize, sugarcane, rice armyworm.",
        "safety_precautions": "Relatively safe for beneficial insects. Still wear gloves and avoid skin contact.",
    },
    "bollworm": {
        "product_name": "Syngenta - Proclaim 5SG (Emamectin Benzoate)",
        "dosage": "0.4 g/L water (or 160 g/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at egg hatching stage (tiny caterpillars on flowers/bolls). Target fruiting bodies and growing tips. Repeat after 10-14 days. Best for cotton/tomato bollworm.",
        "safety_precautions": "Toxic to fish and aquatic organisms. Do not contaminate water bodies. Wear full PPE.",
    },
    "fruit_fly": {
        "product_name": "Dow - Success 45SC (Spinosad)",
        "dosage": "0.3 mL/L water (or 120 mL/acre)",
        "application_method": "Bait spray / Foliar spray",
        "usage_guidance": "Mix with protein bait (gur/jaggery solution). Apply as spot treatment on foliage. Repeat weekly during fruiting season. Works on mango, citrus, guava fruit fly.",
        "safety_precautions": "Low mammalian toxicity. Still avoid contact with eyes. Safe for most beneficial insects.",
    },
    "thrips": {
        "product_name": "Syngenta - Radiant 11.7SC (Spinetoram)",
        "dosage": "0.5 mL/L water (or 200 mL/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first thrips damage (silver streaks on leaves). Target flower buds and young leaves. Repeat after 7-10 days. Critical for onion, chili, cotton thrips.",
        "safety_precautions": "Moderately toxic to bees. Apply in evening. Wear gloves and eye protection.",
    },
    "spider_mites": {
        "product_name": "Syngenta - Vertimec 1.8EC (Abamectin)",
        "dosage": "0.5 mL/L water (or 200 mL/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply when mite population is building (fine webbing on leaf undersides). Thorough coverage of leaf undersides is critical. Repeat after 7 days. Works on cotton, citrus, vegetable mites.",
        "safety_precautions": "Toxic to fish. Do not spray directly on water. Wear gloves and mask.",
    },
    "cotton_bug": {
        "product_name": "Bayer - Mospilan 20SP (Acetamiprid)",
        "dosage": "0.5 g/L water (or 200 g/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first sighting of bugs (red/black bugs on stems). Target stems and leaf joints. Repeat after 10-14 days if needed. Also effective on jassids.",
        "safety_precautions": "Toxic to bees. Do not apply during flowering. Avoid inhalation of spray mist.",
    },
    "stem_borer": {
        "product_name": "FMC - Coragen 18.5SC (Chlorantraniliprole)",
        "dosage": "0.5 mL/L water (or 200 mL/acre)",
        "application_method": "Foliar spray / Granular application",
        "usage_guidance": "Apply at tillering stage for rice/sugarcane. Spray on lower stem area or apply granules in irrigation water. Repeat after 15 days. Very effective on rice stem borer.",
        "safety_precautions": "Wear gloves and mask. Do not contaminate drinking water sources.",
    },
    "leaf_hopper": {
        "product_name": "Syngenta - Confidor 200SL (Imidacloprid)",
        "dosage": "0.3 mL/L water (or 120 mL/acre)",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first sign of hopper damage (yellowing leaf tips, hopper burn). Spray thoroughly on leaf undersides. Critical for rice leaf hopper.",
        "safety_precautions": "Toxic to bees. Apply in evening. Wear PPE.",
    },
    "cutworm": {
        "product_name": "Syngenta - Karate Zeon 2.5CS (Lambda-cyhalothrin)",
        "dosage": "0.4 mL/L water (or 150 mL/acre)",
        "application_method": "Soil spray / Foliar spray",
        "usage_guidance": "Apply in evening when cutworms emerge to feed. Spray on soil surface around plant base. Also effective on armyworm and tobacco caterpillar.",
        "safety_precautions": "Highly toxic to bees and fish. Do not spray near water bodies. Wear full PPE.",
    },
}

DEFAULT_INSECTICIDE_RULE = {
    "product_name": "Syngenta - Karate Zeon 2.5CS (Lambda-cyhalothrin) — broad-spectrum insecticide",
    "dosage": "0.4 mL/L water (or 150 mL/acre)",
    "application_method": "Foliar spray",
    "usage_guidance": "Apply as preventive spray on affected crop. Repeat every 10-14 days. Consult local agronomist for crop-specific guidance. Available at all agriculture input stores in Pakistan.",
    "safety_precautions": "Follow product label instructions. Wear appropriate PPE (gloves, mask, full sleeves). Toxic to bees — avoid spraying during flowering.",
}


def get_insecticide_recommendation(pest_name: str) -> Optional[dict]:
    """
    Look up insecticide recommendation for a given pest.
    Returns rule dict if found, None if no matching rule.
    """
    return INSECTICIDE_RULES.get(pest_name)


def get_default_insecticide() -> dict:
    """Return fallback insecticide recommendation when no rule matches."""
    return DEFAULT_INSECTICIDE_RULE.copy()
