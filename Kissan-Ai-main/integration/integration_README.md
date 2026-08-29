# Integration, AI & Logic — Track 3

**Owner:** Track 3 · Folder: `integration/`  
**Sprint:** Aug 24 – Sep 4, 2025 · Regional Rounds: Sep 5–7

---

## Stack
- **Pydantic v2** — strict schema validation, shared with backend
- **Rules Engine** — custom Python logic for all chemical/dosage recommendations
- **EfficientNet-B0** — vision model (disease + pest detection)
- **Alibaba Qwen** via DashScope API — Kisan AI chat (Urdu / Roman Urdu / English)
- **SQLite / Hive** — local offline queue

---

## Folder Structure
```
integration/
├── schemas/              # Pydantic schemas shared across tracks
│   ├── user.py
│   ├── image.py
│   ├── disease.py
│   ├── pest.py
│   ├── recommendation.py
│   └── weather.py
├── rules_engine/
│   ├── pesticide_rules.py
│   ├── insecticide_rules.py
│   ├── weather_gate.py   # blocks advice if rain/wind unsafe
│   └── crop_rules.py
├── ai/
│   ├── efficientnet.py   # EfficientNet-B0 inference wrapper
│   └── qwen_chat.py      # DashScope API wrapper
├── mocks/                # Dummy JSON endpoints for Day 1 UI binding
│   ├── disease_mock.json
│   ├── pest_mock.json
│   ├── crop_mock.json
│   └── weather_mock.json
├── offline_queue/
│   └── queue.py          # SQLite/Hive queue, auto-retry on reconnect
└── requirements.txt
```

---

## Setup
```bash
cd integration
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
```

---

## Non-Negotiable Rules

### Golden Rule — AI never gives chemical dosage
- All chemical/dosage output comes **only** from the Rules Engine
- Qwen/EfficientNet output → passed to Rules Engine → Rules Engine writes recommendation
- AI model cannot write directly to `PESTICIDE_RECOMMENDATIONS` or `INSECTICIDE_RECOMMENDATIONS`

### Confidence Threshold
- Confidence ≥ 0.70 → proceed to Rules Engine
- Confidence < 0.70 → return fallback card: **"Consult an agronomist"** + top-2 candidate guesses

### Result Screen Contract
Every result screen (Disease, Pest, Pesticide, Insecticide) must answer in this order:
1. **What is the problem?** — identified crop/pest + confidence score
2. **Why did it happen?** — causes/conditions (`possible_causes`, `damage_description`)
3. **What should I do now?** — treatment/recommendation (`application_guidance`, `usage_guidance`)
4. **What should I avoid?** — warnings (`safety_precautions`)

### Auditability
- Every chemical recommendation must trace back to its exact Rules Engine entry (rule ID / rule name logged)
- `weather_blocked = true` must be set whenever rain_probability > threshold or wind_speed > threshold

### Credit Discipline
- End-to-end AI tests: max 2–3 sample images per session
- Mock endpoints must stay active until Day 5 so frontend never blocks on AI

---

## Weather Gate Logic
```python
# weather_gate.py — block chemical advice if conditions unsafe
def is_weather_safe(weather: WeatherCache) -> bool:
    if weather.rain_probability > 40:   # >40% chance of rain
        return False
    if weather.wind_speed > 20:         # >20 km/h wind
        return False
    return True
```
If `is_weather_safe()` returns `False` → set `weather_blocked = True` in recommendation row, show warning to farmer.

---

## Schemas (match ERD — Pydantic v2)

Key schemas Track 3 owns and shares:
| Schema | Maps to ERD Table |
|---|---|
| `DiseaseDetectionOut` | DISEASE_DETECTIONS |
| `PestDetectionOut` | PEST_DETECTIONS |
| `PesticideRecommendationOut` | PESTICIDE_RECOMMENDATIONS |
| `InsecticideRecommendationOut` | INSECTICIDE_RECOMMENDATIONS |
| `WeatherCacheOut` | WEATHER_CACHE |
| `CropRecommendationOut` | CROP_RECOMMENDATIONS |
| `ChatMessageIn/Out` | CHAT_HISTORY |

---

## 12-Day Sprint Plan

| Day | Date   | Task |
|-----|--------|------|
| 1   | Aug 24 | All Pydantic schemas (match ERD), dummy mock JSON endpoints — UI can bind immediately |
| 2   | Aug 25 | Offline queue (SQLite/Hive), auto-retry logic on reconnect |
| 3   | Aug 26 | Rules Engine core — pesticide_rules.py, insecticide_rules.py |
| 4   | Aug 27 | Weather Gate — rain/wind threshold logic, weather_blocked flag |
| 5   | Aug 28 | EfficientNet-B0 inference wrapper, confidence threshold gate (0.70) |
| 6   | Aug 29 | Wire EfficientNet → Rules Engine → recommendation write (full disease pipeline) |
| 7   | Aug 30 | Full pest pipeline — Pest Detection → Insecticide Recommendation |
| 8   | Aug 31 | Qwen DashScope chat wrapper — Urdu/Roman Urdu/English support |
| 9   | Sep 1  | Crop Recommendation logic, Irrigation Guide rules |
| 10  | Sep 2  | End-to-end test with 2–3 real images — disease + pest + chat |
| 11  | Sep 3  | Inference speed validation (< 3s), auditability check on all rule entries |
| 12  | Sep 4  | Golden Rule audit — every result screen passes 4-question contract, final QA sign-off |

**Regional Rounds: Sep 5–7**
