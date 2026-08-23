# Kisan AI — App Flow Reference
*Keep this file in `.qoder/rules/` so Qoder has full context on every request.*

---

## 1. Screen Map

```
────────────────────────────────────────────────
 AUTH FLOW
────────────────────────────────────────────────
Welcome
  ├─ Get Started ──▶ Register
  └─ Skip demo ────▶ Dashboard (mock/demo data, no account)

Register (name, phone, email, password)
  └─ Submit ──▶ POST /api/auth/register ──▶ Onboarding Step 1
  └─ Already have account? ──▶ Login

Login (email, password)
  └─ Submit ──▶ POST /api/auth/login ──▶ Dashboard
  └─ New here? ──▶ Register

────────────────────────────────────────────────
 ONBOARDING FLOW  (6 steps → 6-segment StepProgressBar)
────────────────────────────────────────────────
Step 1 — Farm Location (Province → District → City)
  └─ Continue ──▶ Step 2
  └─ Back ──────▶ Register

Step 2 — Language Selection
         (Urdu / Punjabi / Sindhi / Pashto / Balochi — single select)
  └─ Continue ──▶ Step 3
  └─ Back ──────▶ Step 1

Step 3 — Farmer Type
         (New Farmer / Experienced Farmer — single select)
  └─ Continue ──▶ Step 4
  └─ Back ──────▶ Step 2

Step 4 — Crops (multi-select grid)
  └─ Continue ──▶ Step 5
  └─ Back ──────▶ Step 3

Step 5 — Livestock (multi-select grid)
  └─ Continue ──▶ Step 6
  └─ Back ──────▶ Step 4

Step 6 — Farm Size (stepper + unit: acres / marla / hectare)
  └─ Continue ──▶ POST /api/onboarding/submit ──▶ Dashboard
  └─ Back ──────▶ Step 5

────────────────────────────────────────────────
 MAIN APP
────────────────────────────────────────────────
Dashboard (home)
  ├─ Weather Card ──▶ GET /api/weather/current (Redis-cached, 15-min TTL)
  │
  ├─ Crop Disease Detection
  │     └─▶ Camera / Gallery
  │           └─▶ Preview (retake option)
  │                 └─▶ Analyzing... (POST /api/disease/detect)
  │                       ├─ confidence ≥ 0.70 ──▶ Disease Result ──▶ Pesticide Recommendation
  │                       └─ confidence < 0.70 ──▶ Low Confidence Card ("Consult an agronomist" + top-2 guesses)
  │
  ├─ Pest & Insect Detection
  │     └─▶ Camera / Gallery
  │           └─▶ Preview (retake option)
  │                 └─▶ Analyzing... (POST /api/pests/detect)
  │                       ├─ confidence ≥ 0.70 ──▶ Pest Result ──▶ Insecticide Recommendation
  │                       └─ confidence < 0.70 ──▶ Low Confidence Card ("Consult an agronomist" + top-2 guesses)
  │
  ├─ Crop Recommendation
  │     └─▶ Input Form (season, soil type, water availability)
  │           └─▶ POST /api/crop-recommendation/get ──▶ Result List
  │
  ├─ Irrigation Guide
  │     └─▶ POST /api/irrigation/get ──▶ Result Card
  │
  ├─ Ask Kisan AI (chat)
  │     └─▶ Chat Screen (Urdu / Roman Urdu / English)
  │           └─▶ POST /api/chat/message ──▶ Qwen reply (language auto-detected, logged to CHAT_HISTORY)
  │
  └─ Hamburger Menu
        ├─ Profile ──▶ GET /api/auth/profile (view name, phone, language)
        ├─ History ──▶ GET /api/history/list ──▶ ANALYSIS_HISTORY list
        ├─ Settings ──▶ language / notification preferences
        └─ Logout ──▶ clear JWT ──▶ Welcome
```

---

## 2. Design System
- **Background:** `#F5F0E4` (cream)
- **Primary:** `#1F7A3D` (forest green)
- **Heading text:** `#0F1B0F`
- **Body text:** `#6B7568`
- **Component style:** large radius (16–20px), pill buttons, green border + tint on selected state
- **Shared shell:** `OnboardingScaffold` with **6-segment** `StepProgressBar` + fixed `Back` / `Continue` row
- **One widget per file**, PascalCase filename (`onboarding_scaffold.dart`)

---

## 3. Result Screen Contract
Applies to: **Disease Result, Pest Result, Pesticide Recommendation, Insecticide Recommendation**

Every result screen must answer in this exact order:

| # | Question | ERD Field |
|---|---|---|
| 1 | **What is the problem?** — crop/pest name + confidence % | `disease_name` / `pest_name` + `confidence` |
| 2 | **Why did it happen?** — causes and conditions | `possible_causes` / `damage_description` |
| 3 | **What should I do now?** — treatment / recommendation | `application_guidance` / `usage_guidance` |
| 4 | **What should I avoid?** — warnings and precautions | `safety_precautions` |

**Low confidence fallback (< 0.70):**
Show fallback card — "Consult an agronomist" + top-2 candidate guesses. Never force a single answer.

**Weather blocked:**
If `weather_blocked = true` on recommendation → show banner: "Chemical application not safe right now due to weather conditions."

---

## 4. Data Flow (tied to ERD)

### Auth
```
Register → USERS row created (name, phone, email, password_hash, language, farmer_type)
Login    → JWT issued → stored in Flutter secure storage
```

### Onboarding
```
POST /api/onboarding/submit
  → USERS updated (language, farmer_type)
  → PLOTS row created (province, district, city, farm_size, size_unit, lat/lng)
  → PLOT_CROPS rows created (one per selected crop)
  → PLOT_LIVESTOCK rows created (one per selected livestock)
```

### Image Upload & AI
```
Camera/Gallery
  → POST /api/images/upload
  → IMAGES row created (oss_url, upload_type = "disease" | "pest")
  → EfficientNet-B0 inference runs
  → confidence ≥ 0.70:
      disease → DISEASE_DETECTIONS row created
              → Rules Engine checks WEATHER_CACHE
              → PESTICIDE_RECOMMENDATIONS row written (weather_blocked flag set if unsafe)
      pest    → PEST_DETECTIONS row created
              → Rules Engine checks WEATHER_CACHE
              → INSECTICIDE_RECOMMENDATIONS row written (weather_blocked flag set if unsafe)
  → confidence < 0.70:
      → no DB write for recommendations
      → return top-2 candidates to frontend only
  → ANALYSIS_HISTORY row logged (analysis_type = "disease" | "pest", reference_id = detection row id)
```

### Crop Recommendation
```
Frontend sends: season, soil_type, water_availability (not stored in PLOTS — sent per request)
POST /api/crop-recommendation/get
  → reads PLOTS (province, district, farm_size, PLOT_CROPS for context)
  → CROP_RECOMMENDATIONS row written (season, soil_type, water_availability, suggested_crops, reasoning)
  → ANALYSIS_HISTORY row logged (analysis_type = "crop_recommendation")
```

### Irrigation
```
POST /api/irrigation/get
  → reads PLOTS + PLOT_CROPS (crop_name, growth_stage)
  → IRRIGATION_GUIDANCE row written
  → ANALYSIS_HISTORY row logged (analysis_type = "irrigation")
```

### Chat
```
POST /api/chat/message
  → language auto-detected from message (Urdu / Roman Urdu / English)
  → Qwen (DashScope) called — chemical dosage never returned directly
  → CHAT_HISTORY row written (sender, message, language)
```

### History Screen
```
GET /api/history/list
  → reads ANALYSIS_HISTORY for current user
  → joins to referenced table (disease_detections / pest_detections / crop_recommendations / irrigation_guidance)
  → returns summary cards for each past analysis
```

---

## 5. Database Security Rules (mandatory — every endpoint)
- **No raw SQL from user input.** SQLAlchemy ORM only (`.filter()`, `.where()` — parameterized automatically).
- **If raw SQL is ever unavoidable**, bound params only:
  ```python
  # Correct
  db.execute(text("SELECT * FROM users WHERE email = :email"), {"email": user_email})
  # Never
  db.execute(f"SELECT * FROM users WHERE email = '{user_email}'")
  ```
- **Every request body passes through a Pydantic schema first** — type-check + length-validate before DB.
- **RDS user — least privilege** — no `DROP` / `ALTER` on the app connection.
- **Passwords** — bcrypt/argon2 hash only, `password_hash` column, never plaintext.
- **Chemical/dosage output — Rules Engine only.** AI model never writes recommendations directly.
- **All third-party API keys in backend `.env`** — zero exposure to frontend.

---

## 6. API Route Reference

| Module | Method | Route | Action |
|---|---|---|---|
| auth | POST | `/api/auth/register` | Create user |
| auth | POST | `/api/auth/login` | Issue JWT |
| auth | GET | `/api/auth/profile` | Get user profile |
| onboarding | POST | `/api/onboarding/submit` | Save plots + crops + livestock |
| images | POST | `/api/images/upload` | Upload to OSS, create IMAGES row |
| disease | POST | `/api/disease/detect` | Run EfficientNet, write DISEASE_DETECTIONS |
| pests | POST | `/api/pests/detect` | Run EfficientNet, write PEST_DETECTIONS |
| pesticides | GET | `/api/pesticides/{disease_detection_id}` | Get pesticide recommendation |
| insecticides | GET | `/api/insecticides/{pest_detection_id}` | Get insecticide recommendation |
| weather | GET | `/api/weather/current` | Get cached weather (15-min TTL) |
| crop-recommendation | POST | `/api/crop-recommendation/get` | Get crop suggestions |
| irrigation | POST | `/api/irrigation/get` | Get irrigation guidance |
| chat | POST | `/api/chat/message` | Send message to Qwen, log to CHAT_HISTORY |
| history | GET | `/api/history/list` | List ANALYSIS_HISTORY for user |

---

## 7. Naming Conventions (Qoder must follow)
- **Flutter widgets:** PascalCase, one widget per file (`disease_result_screen.dart`)
- **API routes:** `/api/{module}/{action}` pattern — see table above
- **Backend modules:** `auth`, `onboarding`, `images`, `disease`, `pests`, `pesticides`, `insecticides`, `weather`, `crop-recommendation`, `irrigation`, `chat`, `history`
- **ERD column names** used as-is in Pydantic schemas — no renaming
