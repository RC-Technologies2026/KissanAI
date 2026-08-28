"""
Insecticide rules engine — maps pest names to insecticide recommendations.

Golden Rule: All chemical/dosage output comes ONLY from this Rules Engine.
AI model output → passed here → this engine writes the recommendation.
"""
from typing import Optional

# Pest → insecticide recommendation mapping
INSECTICIDE_RULES: dict[str, dict] = {
    "aphids": {
        "product_name": "Imidacloprid 17.8SL",
        "dosage": "0.3 mL/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first sign of aphid colony. Target undersides of leaves. Repeat after 14 days if infestation persists.",
        "safety_precautions": "Toxic to bees — do not spray during flowering. Wear gloves and mask during application.",
    },
    "whitefly": {
        "product_name": "Thiamethoxam 25WG",
        "dosage": "0.5 g/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply early morning or late evening when whiteflies are active. Cover leaf undersides thoroughly.",
        "safety_precautions": "Toxic to bees and beneficial insects. Avoid spraying during bloom. Wear PPE.",
    },
    "armyworm": {
        "product_name": "Chlorantraniliprole 18.5SC",
        "dosage": "0.5 mL/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at early larval stage (small caterpillars). Spray in evening when larvae feed on leaf surface.",
        "safety_precautions": "Relatively safe for beneficial insects. Still wear gloves and avoid skin contact.",
    },
    "bollworm": {
        "product_name": "Emamectin Benzoate 5SG",
        "dosage": "0.4 g/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at egg hatching stage. Target fruiting bodies and growing tips. Repeat after 10-14 days.",
        "safety_precautions": "Toxic to fish and aquatic organisms. Do not contaminate water bodies. Wear full PPE.",
    },
    "fruit_fly": {
        "product_name": "Spinosad 45SC",
        "dosage": "0.3 mL/L water",
        "application_method": "Bait spray / Foliar spray",
        "usage_guidance": "Mix with protein bait. Apply as spot treatment on foliage. Repeat weekly during fruiting season.",
        "safety_precautions": "Low mammalian toxicity. Still avoid contact with eyes. Safe for most beneficial insects.",
    },
    "thrips": {
        "product_name": "Spinetoram 11.7SC",
        "dosage": "0.5 mL/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first thrips damage. Target flower buds and young leaves. Repeat after 7-10 days.",
        "safety_precautions": "Moderately toxic to bees. Apply in evening. Wear gloves and eye protection.",
    },
    "spider_mites": {
        "product_name": "Abamectin 1.8EC",
        "dosage": "0.5 mL/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply when mite population is building. Thorough coverage of leaf undersides is critical. Repeat after 7 days.",
        "safety_precautions": "Toxic to fish. Do not spray directly on water. Wear gloves and mask.",
    },
    "cotton_bug": {
        "product_name": "Acetamiprid 20SP",
        "dosage": "0.5 g/L water",
        "application_method": "Foliar spray",
        "usage_guidance": "Apply at first sighting of bugs. Target stems and leaf joints. Repeat after 10-14 days if needed.",
        "safety_precautions": "Toxic to bees. Do not apply during flowering. Avoid inhalation of spray mist.",
    },
}

DEFAULT_INSECTICIDE_RULE = {
    "product_name": "Broad-spectrum insecticide",
    "dosage": "As per product label",
    "application_method": "Foliar spray",
    "usage_guidance": "Consult local agronomist for specific usage guidance.",
    "safety_precautions": "Follow product label instructions. Wear appropriate PPE.",
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
