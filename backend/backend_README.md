# Backend & Cloud — Track 2

**Owner:** Track 2 · Folder: `backend/`  
**Sprint:** Aug 24 – Sep 4, 2025 · Regional Rounds: Sep 5–7

---

## Stack
- **FastAPI** — API framework
- **ApsaraDB RDS** (PostgreSQL) — primary database (15 tables)
- **ApsaraDB Redis** — weather cache (15-min TTL)
- **Alibaba OSS** — image storage
- **Alibaba Cloud ACK** (Kubernetes) — deployment
- **API Gateway** — secure external access

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
DATABASE_URL=postgresql://user:pass@host:5432/kisanai
REDIS_URL=redis://host:6379
OSS_ACCESS_KEY=...
OSS_SECRET_KEY=...
OSS_BUCKET=...
OPENWEATHERMAP_KEY=...
DASHSCOPE_API_KEY=...
```

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
- **RDS user** — least privilege, no DROP/ALTER on app connection

---

## API Modules (match ERD table groups)
| Module | Route Prefix | Tables Touched |
|---|---|---|
| auth | `/api/auth` | USERS |
| plots | `/api/plots` | PLOTS, PLOT_CROPS, PLOT_LIVESTOCK |
| images | `/api/images` | IMAGES → OSS |
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
| 1   | Aug 24 | FastAPI project scaffold, connect ApsaraDB RDS, run migrations for all 15 tables |
| 2   | Aug 25 | Auth APIs — register, login, JWT, onboarding endpoint (`POST /api/users/onboarding`) |
| 3   | Aug 26 | OSS setup, secure image upload endpoints (`POST /api/images/upload`), IMAGES table |
| 4   | Aug 27 | OpenWeatherMap integration, Redis cache 15-min TTL, `GET /api/weather/current` |
| 5   | Aug 28 | EfficientNet-B0 vision pipeline — disease + pest detect endpoints, confidence gate (0.70) |
| 6   | Aug 29 | Pesticide & Insecticide endpoints — consume Rules Engine output, weather_blocked flag |
| 7   | Aug 30 | Crop Recommendation + Irrigation Guide endpoints, ANALYSIS_HISTORY logging |
| 8   | Aug 31 | Qwen DashScope chat backend (`/api/chat`), CHAT_HISTORY write |
| 9   | Sep 1  | Containerize with Docker, deploy on Alibaba Cloud ACK |
| 10  | Sep 2  | API Gateway config — zero keys exposed, all routes secured |
| 11  | Sep 3  | Speed tests — all inference responses < 3s, load test critical routes |
| 12  | Sep 4  | Final live FastAPI URL confirmed, end-to-end smoke test, demo device ready |

**Regional Rounds: Sep 5–7**
