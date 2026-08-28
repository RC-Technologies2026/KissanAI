"""
Pesticide rules engine — maps disease names to pesticide recommendations.

Golden Rule: All chemical/dosage output comes ONLY from this Rules Engine.
AI model output → passed here → this engine writes the recommendation.
"""
from typing import Optional

# Disease → pesticide recommendation mapping
# Each entry: product_name, dosage, application_method, guidance, safety
PESTICIDE_RULES: dict[str, dict] = {
    "powdery_mildew": {
        "product_name": "Sulfur 80WP",
        "dosage": "2-3 g/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at first sign of disease. Repeat every 7-10 days. Cover both leaf surfaces thoroughly.",
        "safety_precautions": "Do not apply when temperature exceeds 35°C. Wait 7 days before harvest. Wear protective gloves and mask.",
    },
    "leaf_rust": {
        "product_name": "Propiconazole 25EC",
        "dosage": "1 mL/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at early rust pustule stage. Repeat after 14 days if needed. Ensure full leaf coverage.",
        "safety_precautions": "Toxic to aquatic organisms. Do not contaminate water sources. Wear PPE during application.",
    },
    "blight": {
        "product_name": "Mancozeb 75WP",
        "dosage": "2.5 g/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Apply preventively or at first symptom. Repeat every 7-10 days during wet weather.",
        "safety_precautions": "Avoid inhalation of spray mist. Wash hands after use. 14-day pre-harvest interval.",
    },
    "anthracnose": {
        "product_name": "Carbendazim 50WP",
        "dosage": "1 g/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Apply at flowering and fruit set stage. Repeat every 10-14 days during humid conditions.",
        "safety_precautions": "Do not mix with alkaline products. Wear gloves and eye protection.",
    },
    "fusarium_wilt": {
        "product_name": "Carbendazim 50WP",
        "dosage": "1.5 g/L water",
        "application_method": "Soil drench",
        "application_guidance": "Apply around root zone. Repeat after 15 days. Ensure soil is moist before application.",
        "safety_precautions": "Avoid contact with skin. Do not contaminate irrigation water sources.",
    },
    "mosaic_virus": {
        "product_name": "Imidacloprid 17.8SL",
        "dosage": "0.3 mL/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Target vector insects (aphids/whiteflies) that spread the virus. Apply at first vector sighting.",
        "safety_precautions": "Toxic to bees — do not spray during flowering. Wear protective clothing.",
    },
    "black_rot": {
        "product_name": "Mancozeb 75WP",
        "dosage": "2.5 g/L water",
        "application_method": "Foliar spray",
        "application_guidance": "Apply from fruit set through harvest. Repeat every 7-14 days. Remove mummified fruit first.",
        "safety_precautions": "Do not apply in extreme heat. Wait 14 days before harvest. Wear PPE.",
    },
}

DEFAULT_PESTICIDE_RULE = {
    "product_name": "Broad-spectrum fungicide",
    "dosage": "As per product label",
    "application_method": "Foliar spray",
    "application_guidance": "Consult local agronomist for specific application guidance.",
    "safety_precautions": "Follow product label instructions. Wear appropriate PPE.",
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
