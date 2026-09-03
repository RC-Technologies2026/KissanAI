"""
Pesticide rules engine — maps disease names to pesticide recommendations.

Golden Rule: All chemical/dosage output comes ONLY from this Rules Engine.
AI model output → passed here → this engine writes the recommendation.
"""
from typing import Optional

# Disease → pesticide recommendation mapping
# Each entry: product_name (Pakistani brand), dosage, application_method, guidance, safety
# Brands: Syngenta, Bayer, FMC, Engro, FFC, Fatima, Nova, ICI/Lucky Core, Tara Crop
PESTICIDE_RULES: dict[str, dict] = {
    "powdery_mildew": {
        "product_name": "Syngenta - Amistar Top (Azoxystrobin + Difenoconazole)",
        "dosage": "0.5 mL/L water (or 200 mL/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at first sign of white powdery growth on leaves. Repeat every 7-10 days. Cover both leaf surfaces thoroughly. Best results in early morning.",
        "safety_precautions": "Do not apply when temperature exceeds 35°C. Wait 7 days before harvest. Wear protective gloves and mask.",
    },
    "leaf_rust": {
        "product_name": "Syngenta - Tilt 250EC (Propiconazole)",
        "dosage": "1 mL/L water (or 400 mL/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at early rust pustule stage (orange-brown spots on leaves). Repeat after 14 days if needed. Ensure full leaf coverage. Best for wheat rust.",
        "safety_precautions": "Toxic to aquatic organisms. Do not contaminate water sources. Wear PPE during application.",
    },
    "blight": {
        "product_name": "Syngenta - Ridomil Gold MZ 68WG (Metalaxyl + Mancozeb)",
        "dosage": "2.5 g/L water (or 1 kg/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply preventively or at first symptom (dark water-soaked lesions). Repeat every 7-10 days during wet weather. Critical for potato/tomato blight.",
        "safety_precautions": "Avoid inhalation of spray mist. Wash hands after use. 14-day pre-harvest interval.",
    },
    "anthracnose": {
        "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
        "dosage": "1 g/L water (or 400 g/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at flowering and fruit set stage. Repeat every 10-14 days during humid conditions. Effective on mango, citrus, chili.",
        "safety_precautions": "Do not mix with alkaline products. Wear gloves and eye protection.",
    },
    "fusarium_wilt": {
        "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
        "dosage": "1.5 g/L water (or 600 g/acre)",
        "application_method": "Soil drench",
        "application_guidance": "Apply around root zone (200-300 mL per plant). Repeat after 15 days. Ensure soil is moist before application. Works on banana, tomato, chili wilt.",
        "safety_precautions": "Avoid contact with skin. Do not contaminate irrigation water sources.",
    },
    "mosaic_virus": {
        "product_name": "Syngenta - Confidor 200SL (Imidacloprid) — targets virus-spreading aphids/whiteflies",
        "dosage": "0.3 mL/L water (or 120 mL/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Target vector insects (aphids/whiteflies) that spread the virus. Apply at first vector sighting. No cure for virus itself — control the insects.",
        "safety_precautions": "Toxic to bees — do not spray during flowering. Wear protective clothing.",
    },
    "black_rot": {
        "product_name": "Syngenta - Dithane M-45 (Mancozeb 75WP)",
        "dosage": "2.5 g/L water (or 1 kg/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply from fruit set through harvest. Repeat every 7-14 days. Remove mummified/rotten fruit first. Works on grapes, citrus, mango.",
        "safety_precautions": "Do not apply in extreme heat. Wait 14 days before harvest. Wear PPE.",
    },
    "stem_rot": {
        "product_name": "Bayer - Rovral 50WP (Iprodione)",
        "dosage": "1.5 g/L water (or 600 g/acre)",
        "application_method": "Soil drench / Foliar spray",
        "application_guidance": "Apply at base of stem and surrounding soil. Repeat every 10-14 days. Effective on groundnut, sunflower, mustard stem rot.",
        "safety_precautions": "Wear gloves and mask. Do not contaminate water bodies.",
    },
    "downy_mildew": {
        "product_name": "Syngenta - Ridomil Gold 25WG (Metalaxyl + Mancozeb)",
        "dosage": "2 g/L water (or 800 g/acre)",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at first sign of yellow patches on upper leaf surface with white growth underneath. Repeat every 7 days. Critical for cucumber, onion, sunflower.",
        "safety_precautions": "Apply in cool hours (morning/evening). 10-day pre-harvest interval.",
    },
    "root_rot": {
        "product_name": "ICI Lucky Core - Aliette 80WP (Fosetyl-Aluminium)",
        "dosage": "2 g/L water (or 800 g/acre)",
        "application_method": "Soil drench",
        "application_guidance": "Apply around root zone thoroughly. Repeat after 15 days. Works on citrus, mango, vegetable root rot.",
        "safety_precautions": "Do not mix with copper-based products. Wear PPE.",
    },
}

DEFAULT_PESTICIDE_RULE = {
    "product_name": "Syngenta - Dithane M-45 (Mancozeb 75WP) — broad-spectrum fungicide",
    "dosage": "2.5 g/L water (or 1 kg/acre)",
    "application_method": "Foliar spray",
    "application_guidance": "Apply as preventive spray. Repeat every 7-10 days. Consult local agronomist for crop-specific guidance. Available at all agriculture input stores in Pakistan.",
    "safety_precautions": "Follow product label instructions. Wear appropriate PPE (gloves, mask, full sleeves).",
}


def get_pesticide_recommendation(disease_name: str) -> Optional[dict]:
    """
    Look up pesticide recommendation for a given disease.
    Returns rule dict if found, None if no matching rule.
    """
    return PESTICIDE_RULES.get(disease_name)


def get_default_pesticide() -> dict:
    """Return fallback pesticide recommendation when no rule matches."""
    return DEFAULT_PESTICIDE_RULE.copy()
