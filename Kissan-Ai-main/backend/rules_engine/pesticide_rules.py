"""
Pesticide rules engine — maps disease names to pesticide recommendations.

Golden Rule: All chemical/dosage output comes ONLY from this Rules Engine.
AI model output → passed here → this engine writes the recommendation.
"""
from typing import Optional

# Disease → pesticide recommendation mapping
# Each disease has 2-3 Pakistani product options (primary + alternatives)
# Brands: Syngenta, Bayer, FMC, Engro, FFC, Fatima, Nova, ICI/Lucky Core, Tara Crop
PESTICIDE_RULES: dict[str, dict] = {
    "powdery_mildew": {
        "products": [
            {
                "product_name": "Syngenta - Amistar Top (Azoxystrobin + Difenoconazole)",
                "dosage": "0.5 mL/L water (or 200 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply at first sign of white powdery growth on leaves. Repeat every 7-10 days. Cover both leaf surfaces thoroughly. Best results in early morning.",
                "safety_precautions": "Do not apply when temperature exceeds 35°C. Wait 7 days before harvest. Wear protective gloves and mask.",
            },
            {
                "product_name": "Bayer - Score 250EC (Difenoconazole)",
                "dosage": "0.5 mL/L water (or 200 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Systemic fungicide — absorbed by leaves quickly. Apply at early infection stage. Repeat after 10 days if needed.",
                "safety_precautions": "Do not mix with alkaline products. 7-day pre-harvest interval. Wear PPE.",
            },
            {
                "product_name": "FMC - Topas 100EC (Penconazole)",
                "dosage": "0.3 mL/L water (or 120 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Highly effective on powdery mildew of grapes, cucurbits, roses. Apply preventively or at first symptom.",
                "safety_precautions": "Avoid spray drift to non-target crops. 14-day pre-harvest interval.",
            },
        ],
    },
    "leaf_rust": {
        "products": [
            {
                "product_name": "Syngenta - Tilt 250EC (Propiconazole)",
                "dosage": "1 mL/L water (or 400 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply at early rust pustule stage (orange-brown spots on leaves). Repeat after 14 days if needed. Ensure full leaf coverage. Best for wheat rust.",
                "safety_precautions": "Toxic to aquatic organisms. Do not contaminate water sources. Wear PPE during application.",
            },
            {
                "product_name": "Bayer - Folicur 250EW (Tebuconazole)",
                "dosage": "1 mL/L water (or 400 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Broad-spectrum triazole fungicide. Effective on wheat, barley, and rice rust. Apply at first pustule appearance.",
                "safety_precautions": "Do not apply during flowering if bees are active. 21-day pre-harvest interval.",
            },
            {
                "product_name": "Syngenta - Bumper 250EC (Propiconazole)",
                "dosage": "1 mL/L water (or 400 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Alternative to Tilt — same active ingredient. Mix with sticker/spreader for better leaf adhesion in wheat.",
                "safety_precautions": "Wear gloves and mask. Do not graze livestock on treated fields for 14 days.",
            },
        ],
    },
    "blight": {
        "products": [
            {
                "product_name": "Syngenta - Ridomil Gold MZ 68WG (Metalaxyl + Mancozeb)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply preventively or at first symptom (dark water-soaked lesions). Repeat every 7-10 days during wet weather. Critical for potato/tomato blight.",
                "safety_precautions": "Avoid inhalation of spray mist. Wash hands after use. 14-day pre-harvest interval.",
            },
            {
                "product_name": "DuPont - Curzate M8 (Cymoxanil + Mancozeb)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Curative + protective action. Apply at first blight sign. Excellent for late blight of potato and tomato.",
                "safety_precautions": "Do not apply in strong wind. 10-day pre-harvest interval. Wear full PPE.",
            },
            {
                "product_name": "Bayer - Dithane M-45 (Mancozeb 75WP)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Preventive fungicide — apply before disease appears in humid conditions. Repeat every 7 days. Economical option for large fields.",
                "safety_precautions": "Do not apply in extreme heat. 14-day pre-harvest interval.",
            },
        ],
    },
    "anthracnose": {
        "products": [
            {
                "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
                "dosage": "1 g/L water (or 400 g/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply at flowering and fruit set stage. Repeat every 10-14 days during humid conditions. Effective on mango, citrus, chili.",
                "safety_precautions": "Do not mix with alkaline products. Wear gloves and eye protection.",
            },
            {
                "product_name": "Syngenta - Score 250EC (Difenoconazole)",
                "dosage": "0.5 mL/L water (or 200 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Systemic action — works even after infection starts. Apply at fruit development stage. Best for mango anthracnose.",
                "safety_precautions": "7-day pre-harvest interval. Avoid spray drift.",
            },
            {
                "product_name": "ICI Lucky Core - Dithane M-45 (Mancozeb 75WP)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Broad-spectrum preventive fungicide. Apply before monsoon season on mango and citrus. Cost-effective for large orchards.",
                "safety_precautions": "Wear PPE. Do not contaminate water bodies.",
            },
        ],
    },
    "fusarium_wilt": {
        "products": [
            {
                "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
                "dosage": "1.5 g/L water (or 600 g/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Apply around root zone (200-300 mL per plant). Repeat after 15 days. Ensure soil is moist before application. Works on banana, tomato, chili wilt.",
                "safety_precautions": "Avoid contact with skin. Do not contaminate irrigation water sources.",
            },
            {
                "product_name": "Syngenta - Maxim (Fludioxonil) — seed treatment + soil drench",
                "dosage": "2 mL/kg seed (treatment) or 1.5 g/L (soil drench)",
                "application_method": "Seed treatment / Soil drench",
                "application_guidance": "Treat seeds before sowing to prevent soil-borne infection. For established plants, apply as soil drench around roots.",
                "safety_precautions": "Wear gloves during seed treatment. Do not treat seeds intended for consumption.",
            },
            {
                "product_name": "Engro - Trichoderma viride (Bio-fungicide)",
                "dosage": "4 g/L water (or 1.5 kg/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Organic alternative — Trichoderma colonizes roots and fights Fusarium. Apply at transplanting and repeat monthly. Safe for organic farming.",
                "safety_precautions": "Do not mix with chemical fungicides. Store in cool, dry place.",
            },
        ],
    },
    "mosaic_virus": {
        "products": [
            {
                "product_name": "Syngenta - Confidor 200SL (Imidacloprid) — targets virus-spreading aphids/whiteflies",
                "dosage": "0.3 mL/L water (or 120 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Target vector insects (aphids/whiteflies) that spread the virus. Apply at first vector sighting. No cure for virus itself — control the insects.",
                "safety_precautions": "Toxic to bees — do not spray during flowering. Wear protective clothing.",
            },
            {
                "product_name": "Bayer - Movento 240SC (Spirotetramat) — systemic insecticide",
                "dosage": "0.5 mL/L water (or 200 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Two-way systemic action — moves up and down in plant. Controls whiteflies and aphids for 14-21 days. Best for tomato/cotton mosaic.",
                "safety_precautions": "Do not apply during bloom. 7-day pre-harvest interval.",
            },
            {
                "product_name": "FMC - Actara 25WG (Thiamethoxam)",
                "dosage": "0.25 g/L water (or 100 g/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Fast-acting neonicotinoid. Controls aphids, whiteflies, jassids within 24 hours. Repeat every 10-14 days during vector season.",
                "safety_precautions": "Highly toxic to bees. Apply in evening only. Wear full PPE.",
            },
        ],
    },
    "black_rot": {
        "products": [
            {
                "product_name": "Syngenta - Dithane M-45 (Mancozeb 75WP)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply from fruit set through harvest. Repeat every 7-14 days. Remove mummified/rotten fruit first. Works on grapes, citrus, mango.",
                "safety_precautions": "Do not apply in extreme heat. Wait 14 days before harvest. Wear PPE.",
            },
            {
                "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
                "dosage": "1 g/L water (or 400 g/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Systemic fungicide — absorbed into plant tissue. Apply at fruit development stage. Effective on grape black rot.",
                "safety_precautions": "Do not mix with copper-based products. 14-day pre-harvest interval.",
            },
            {
                "product_name": "Syngenta - Score 250EC (Difenoconazole)",
                "dosage": "0.5 mL/L water (or 200 mL/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Curative action — stops existing infection. Apply at first black spot on fruit. Repeat after 10 days.",
                "safety_precautions": "7-day pre-harvest interval. Avoid spray drift to water bodies.",
            },
        ],
    },
    "stem_rot": {
        "products": [
            {
                "product_name": "Bayer - Rovral 50WP (Iprodione)",
                "dosage": "1.5 g/L water (or 600 g/acre)",
                "application_method": "Soil drench / Foliar spray",
                "application_guidance": "Apply at base of stem and surrounding soil. Repeat every 10-14 days. Effective on groundnut, sunflower, mustard stem rot.",
                "safety_precautions": "Wear gloves and mask. Do not contaminate water bodies.",
            },
            {
                "product_name": "Syngenta - Ridomil Gold MZ 68WG (Metalaxyl + Mancozeb)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Apply around stem base and root zone. Dual action — prevents and treats stem rot. Works on sunflower, groundnut, soybean.",
                "safety_precautions": "14-day pre-harvest interval. Do not apply in waterlogged soil.",
            },
            {
                "product_name": "Bayer - Bavistin DF (Carbendazim 50WP)",
                "dosage": "1.5 g/L water (or 600 g/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Systemic action — absorbed through roots. Apply at early stem rot symptoms. Repeat after 15 days.",
                "safety_precautions": "Do not exceed recommended dosage. Wear PPE during application.",
            },
        ],
    },
    "downy_mildew": {
        "products": [
            {
                "product_name": "Syngenta - Ridomil Gold 25WG (Metalaxyl + Mancozeb)",
                "dosage": "2 g/L water (or 800 g/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Apply at first sign of yellow patches on upper leaf surface with white growth underneath. Repeat every 7 days. Critical for cucumber, onion, sunflower.",
                "safety_precautions": "Apply in cool hours (morning/evening). 10-day pre-harvest interval.",
            },
            {
                "product_name": "DuPont - Curzate M8 (Cymoxanil + Mancozeb)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Curative + protective. Apply at first downy mildew sign. Excellent for grape and cucumber downy mildew.",
                "safety_precautions": "Do not apply in strong wind. 10-day pre-harvest interval.",
            },
            {
                "product_name": "Bayer - Aliette 80WP (Fosetyl-Aluminium)",
                "dosage": "2 g/L water (or 800 g/acre)",
                "application_method": "Foliar spray",
                "application_guidance": "Systemic fungicide — moves within plant tissue. Apply preventively before humid weather. Works on onion, cucumber, grape.",
                "safety_precautions": "Do not mix with copper products. 14-day pre-harvest interval.",
            },
        ],
    },
    "root_rot": {
        "products": [
            {
                "product_name": "ICI Lucky Core - Aliette 80WP (Fosetyl-Aluminium)",
                "dosage": "2 g/L water (or 800 g/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Apply around root zone thoroughly. Repeat after 15 days. Works on citrus, mango, vegetable root rot.",
                "safety_precautions": "Do not mix with copper-based products. Wear PPE.",
            },
            {
                "product_name": "Syngenta - Ridomil Gold MZ 68WG (Metalaxyl + Mancozeb)",
                "dosage": "2.5 g/L water (or 1 kg/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Apply around root zone at first wilt symptom. Dual systemic + contact action. Works on citrus, mango, tomato root rot.",
                "safety_precautions": "Ensure good drainage before application. 14-day pre-harvest interval.",
            },
            {
                "product_name": "Engro - Trichoderma harzianum (Bio-fungicide)",
                "dosage": "4 g/L water (or 1.5 kg/acre)",
                "application_method": "Soil drench",
                "application_guidance": "Organic bio-control agent. Apply at transplanting and repeat monthly. Colonizes roots and fights root rot pathogens. Safe for organic farming.",
                "safety_precautions": "Do not mix with chemical fungicides. Store below 25°C.",
            },
        ],
    },
}

DEFAULT_PESTICIDE_RULE = {
    "products": [
        {
            "product_name": "Syngenta - Dithane M-45 (Mancozeb 75WP) — broad-spectrum fungicide",
            "dosage": "2.5 g/L water (or 1 kg/acre)",
            "application_method": "Foliar spray",
            "application_guidance": "Apply as preventive spray. Repeat every 7-10 days. Consult local agronomist for crop-specific guidance. Available at all agriculture input stores in Pakistan.",
            "safety_precautions": "Follow product label instructions. Wear appropriate PPE (gloves, mask, full sleeves).",
        },
        {
            "product_name": "Bayer - Bavistin DF (Carbendazim 50WP) — systemic fungicide",
            "dosage": "1 g/L water (or 400 g/acre)",
            "application_method": "Foliar spray",
            "application_guidance": "Systemic fungicide effective on a wide range of fungal diseases. Apply at first symptom. Available at all agriculture stores in Pakistan.",
            "safety_precautions": "Do not mix with alkaline products. 14-day pre-harvest interval. Wear PPE.",
        },
    ],
}


def get_pesticide_recommendation(disease_name: str) -> Optional[list]:
    """
    Look up pesticide recommendations for a given disease.
    Returns list of product dicts (2-3 options) if found, None if no matching rule.
    """
    rule = PESTICIDE_RULES.get(disease_name)
    if rule:
        return rule.get("products", [])
    return None


def get_default_pesticide() -> list:
    """Return fallback pesticide recommendations when no rule matches."""
    return DEFAULT_PESTICIDE_RULE.get("products", [])
