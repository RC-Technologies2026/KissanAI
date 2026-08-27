# Backend & Cloud — Track 2 (Free-Tier Version)

**Owner:** Track 2 · Folder: `backend/`
**Sprint:** Aug 24 – Sep 4, 2025 · Regional Rounds: Sep 5–7

---

## Stack
- **FastAPI** — API framework
- **Supabase** (PostgreSQL) — primary database (15 tables)
- **Upstash Redis** — weather cache (15-min TTL)
- **Cloudinary** or **Cloudflare R2** — image storage *(pick one — see notes below)*
- **Railway** or **Render** — deployment *(pick one — see notes below)*
- **API Gateway** — secure external access *(handled natively in FastAPI — see notes below)*

---

## Folder Structure
```
backend/
├── main.py
├── requirements.txt
├── .env                  # keys here — never commit
├── models/               # SQLAlchemy ORM models (match ERD exactly)
│   ├── user.py
│   ├── plot.py
│   ├── image.py
│   ├── disease.py
│   ├── pest.py
│   ├── weather.py
│   └── ...
├── routers/              # one file per module
│   ├── auth.py           # /api/auth/*
│   ├── plots.py          # /api/plots/*
│   ├── images.py         # /api/images/*
│   ├── disease.py        # /api/disease/detect
│   ├── pests.py          # /api/pests/detect
│   ├── pesticides.py     # /api/pesticides/*
│   ├── insecticides.py   # /api/insecticides/*
│   ├── weather.py        # /api/weather/current
│   ├── irrigation.py     # /api/irrigation/*
│   ├── chat.py           # /api/chat/*
│   └── history.py        # /api/history/*
├── schemas/              # Pydantic models (shared with integration/)
├── db.py                 # DB connection
└── Dockerfile
```

---

## Setup
```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
uvicorn main:app --reload
```

`.env` file (create manually, never commit):
```
DATABASE_URL=postgresql://user:pass@host:5432/postgres   # Supabase connection string
REDIS_URL=<upstash_redis_rest_url>
# --- Image storage: use ONE of the two below ---
CLOUDINARY_URL=<cloudinary_url>
# OR
R2_ACCESS_KEY=...
R2_SECRET_KEY=...
R2_BUCKET=...
R2_ENDPOINT=...
OPENWEATHERMAP_KEY=...
GEMINI_API_KEY=...
```

---

## Free-Tier Service Notes

| Service | Free Tier Limit | Notes |
|---|---|---|
| **Supabase** | 500 MB database, 1 GB file storage, 50K MAUs, 5 GB egress, 2 active projects | Free project auto-pauses after 7 days of no API activity — ping it (cron/GitHub Action) during sprint + before demo so it's warm |
| **Upstash Redis** | 500K commands/month, 256 MB data, 10 GB bandwidth | REST-based, fits the 15-min TTL cache easily |
| **Cloudinary** | 25 credits/month (1 credit = 1 GB storage OR 1 GB bandwidth OR 1K transforms) | Best if you want auto-resize/compression on uploaded crop/pest images |
| **Cloudflare R2** | 10 GB storage, 1M writes, 10M reads/month, zero egress fees | Best if you just need raw storage with no processing — more headroom than Cloudinary |
| **Railway** | Usage-based free credits (no fixed "always-free" tier, but enough for a short sprint) | Deploys straight from GitHub, supports Docker — good if you want to keep the existing Dockerfile |
| **Render** | Free web service (512 MB RAM, 0.1 CPU), 750 instance-hours/month, spins down after 15 min idle | Simple setup, no card needed — spin-up delay (~30–60s) after inactivity, so "wake it up" before your demo slot |
| **Gemini API** | Gemini 2.5 Flash: ~10 RPM, 250 RPD; Flash-Lite: ~15 RPM, 1,000 RPD, 250K TPM | No credit card required; use Flash or Flash-Lite (not Pro) for the free tier — Pro free quota is very limited |
| **OpenWeatherMap** | 60 calls/min, 1,000 calls/day | Unchanged — already free |

**Deployment pick:** Railway if you want Docker-based deploy identical to your current Dockerfile flow; Render if you want the simplest zero-config path and don't mind the cold-start delay. Either is fine for a 12-day sprint — just pick one early so the team isn't maintaining two deploy configs.

**Image storage pick:** Cloudinary if disease/pest images need resizing or compression before storage; R2 if you just need cheap, high-headroom raw storage and will handle any image processing yourself.

**API Gateway:** kept as a concept, but implemented natively in FastAPI instead of a separate paid gateway service — CORS, auth, and rate-limiting (via `slowapi`, free/open-source) live directly in the app. Zero keys exposed to frontend either way.

---

## Non-Negotiable Rules
- **No raw SQL from user input** — SQLAlchemy ORM only. If raw SQL unavoidable, use bound params:
  ```python
  # Correct
  db.execute(text("SELECT * FROM users WHERE email = :email"), {"email": user_email})
  # Never
  db.execute(f"SELECT * FROM users WHERE email = '{user_email}'")
  ```
- **No API keys in frontend** — all third-party calls go through backend
- **Chemical/dosage output only from Rules Engine** — never from this layer directly
- **Passwords** — bcrypt/argon2 hash only, never plaintext
- **DB user** — least privilege, no DROP/ALTER on app connection

---

## API Modules (match ERD table groups)
| Module | Route Prefix | Tables Touched |
|---|---|---|
| auth | `/api/auth` | USERS |
| plots | `/api/plots` | PLOTS, PLOT_CROPS, PLOT_LIVESTOCK |
| images | `/api/images` | IMAGES → Cloudinary/R2 |
| disease | `/api/disease` | DISEASE_DETECTIONS |
| pests | `/api/pests` | PEST_DETECTIONS |
| pesticides | `/api/pesticides` | PESTICIDE_RECOMMENDATIONS, WEATHER_CACHE |
| insecticides | `/api/insecticides` | INSECTICIDE_RECOMMENDATIONS, WEATHER_CACHE |
| weather | `/api/weather` | WEATHER_CACHE |
| irrigation | `/api/irrigation` | IRRIGATION_GUIDANCE |
| chat | `/api/chat` | CHAT_HISTORY |
| history | `/api/history` | ANALYSIS_HISTORY |

---

## 12-Day Sprint Plan

| Day | Date   | Task |
|-----|--------|------|
| 1   | Aug 24 | FastAPI project scaffold, connect Supabase (PostgreSQL), run migrations for all 15 tables |
| 2   | Aug 25 | Auth APIs — register, login, JWT, onboarding endpoint (`POST /api/users/onboarding`) |
| 3   | Aug 26 | Cloudinary/R2 setup, secure image upload endpoints (`POST /api/images/upload`), IMAGES table |
| 4   | Aug 27 | OpenWeatherMap integration, Upstash Redis cache 15-min TTL, `GET /api/weather/current` |
| 5   | Aug 28 | EfficientNet-B0 vision pipeline — disease + pest detect endpoints, confidence gate (0.70) |
| 6   | Aug 29 | Pesticide & Insecticide endpoints — consume Rules Engine output, weather_blocked flag |
| 7   | Aug 30 | Crop Recommendation + Irrigation Guide endpoints, ANALYSIS_HISTORY logging |
| 8   | Aug 31 | Gemini API chat backend (`/api/chat`), CHAT_HISTORY write |
| 9   | Sep 1  | Containerize with Docker, deploy on Railway or Render |
| 10  | Sep 2  | FastAPI-native gateway config (CORS, `slowapi` rate-limiting) — zero keys exposed, all routes secured |
| 11  | Sep 3  | Speed tests — all inference responses < 3s, load test critical routes |
| 12  | Sep 4  | Final live FastAPI URL confirmed, end-to-end smoke test, demo device ready |

**Regional Rounds: Sep 5–7**
