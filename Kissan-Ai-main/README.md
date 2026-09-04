# Kisan AI — Your AI Agricultural Assistant

**Empowering Pakistani farmers with artificial intelligence.** Detect crop diseases, identify pests, get irrigation guidance, check live weather, and chat with an AI agronomist — all in your language, all in one app.

<p align="center">
  <a href="https://kissan-ai-landing.vercel.app/"><strong>🌐 Landing Page & APK Download</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi" alt="FastAPI" />
  <img src="https://img.shields.io/badge/PostgreSQL-Supabase-336791?logo=postgresql" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## The Problem

Pakistan's 70+ million farmers lose up to **40% of crop yields** annually to diseases and pests they cannot identify in time. Most lack access to agronomists, rely on guesswork for chemical application, and receive no localized weather-aware advice. Misuse of pesticides harms both their health and the land.

## The Solution

**Kisan AI** puts world-class agricultural expertise into every farmer's pocket. Snap a photo of a diseased leaf or pest — the AI identifies it instantly and recommends the right treatment. Ask questions in Urdu, Punjabi, Sindhi, Pashto, or Balochi. Get irrigation schedules and crop suggestions tailored to your soil, season, and location.

## Impact

| Metric | Target |
|---|---|
| Crop yield loss reduction | Up to 30% through early detection |
| Pesticide misuse reduction | Weather-gated recommendations prevent unsafe application |
| Language accessibility | 6 regional languages — no literacy barrier |
| Response time | AI diagnosis in under 3 seconds |
| Cost to farmer | Free |

---

## Features

### Disease Detection
Snap a photo of any affected leaf and the AI identifies the disease instantly, with confidence scores and recommended next steps. Powered by **EfficientNet-B0**.

### Pest Detection
Identify pest infestations early by capturing a photo. The AI analyses the image and flags the pest type so you can act before damage spreads.

### Ask Kisan AI (Chat)
A multilingual chatbot that answers farming questions in your own language — English, Urdu, Punjabi, Sindhi, Pashto, or Balochi. Powered by **Google Gemini**.

### Weather Intelligence
Live temperature, humidity, wind speed, and a 3-day forecast for your exact GPS location, shown right on the home dashboard. Cached via **Redis** with 15-minute TTL.

### Crop Recommendation
Get AI-driven crop suggestions based on your soil type, available water, and the current season — so you plant what works best for your land.

### Irrigation Guide
Enter your plot details, crop type, and water availability to receive a personalised irrigation schedule tailored to your field.

---

## Technology Stack

### Frontend — Flutter (Dart)
- **State management:** Riverpod
- **Networking:** Dio
- **Local storage:** Hive + flutter_secure_storage (JWT)
- **Routing:** go_router
- **Image capture:** image_picker (camera + gallery)
- **Location:** geolocator + geocoding

### Backend — FastAPI (Python)
- **API framework:** FastAPI with async support
- **Database:** Supabase (PostgreSQL) with 15 tables
- **Migrations:** Alembic
- **Cache:** Redis Cloud (weather data, 15-min TTL)
- **Image storage:** Cloudinary
- **Vision model:** EfficientNet-B0 (PyTorch)
- **AI chat:** Google Gemini API
- **Weather:** OpenWeatherMap API
- **Rate limiting:** slowapi
- **Auth:** JWT (python-jose + bcrypt)

### Deployment
- **Backend:** Render (Docker container)
- **Database:** Supabase Cloud
- **Cache:** Redis Cloud
- **Landing page:** Vercel

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                        │
│  (Riverpod · Dio · Hive · go_router · image_picker)         │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS / JWT
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Backend (Render)                    │
│                                                             │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Auth   │  │   Routers    │  │   Vision Pipeline    │  │
│  │  (JWT)   │  │  (12 modules)│  │  (EfficientNet-B0)   │  │
│  └──────────┘  └──────────────┘  └──────────────────────┘  │
│                                                             │
│  ┌──────────────┐  ┌────────────┐  ┌────────────────────┐  │
│  │ Rules Engine │  │ Rate Limit │  │   Gemini Chat AI   │  │
│  │ (chemical    │  │ (slowapi)  │  │   (multilingual)   │  │
│  │  dosage)     │  │            │  │                    │  │
│  └──────────────┘  └────────────┘  └────────────────────┘  │
└──────┬──────────────┬───────────────┬───────────────────────┘
       │              │               │
       ▼              ▼               ▼
 ┌───────────┐  ┌───────────┐  ┌─────────────┐
 │ Supabase  │  │   Redis   │  │ Cloudinary  │
 │ (Postgres)│  │  (Cache)  │  │  (Images)   │
 └───────────┘  └───────────┘  └─────────────┘
```

### Database Schema (15 tables)
The ERD covers: USERS, PLOTS, PLOT_CROPS, PLOT_LIVESTOCK, IMAGES, DISEASE_DETECTIONS, PEST_DETECTIONS, PESTICIDE_RECOMMENDATIONS, INSECTICIDE_RECOMMENDATIONS, WEATHER_CACHE, IRRIGATION_GUIDANCE, CROP_RECOMMENDATIONS, CHAT_HISTORY, ANALYSIS_HISTORY, and PLANTS.

See the full ERD in [`.qoder/rules/Kisan_AI_Database_ERD.mermaid`](.qoder/rules/Kisan_AI_Database_ERD.mermaid).

---

## Project Structure

```
Kissan-Ai-main/
├── backend/                    # FastAPI REST API
│   ├── routers/                # API route handlers (12 modules)
│   │   ├── auth.py             #   Register, login, JWT
│   │   ├── disease.py          #   Disease detection
│   │   ├── pests.py            #   Pest detection
│   │   ├── pesticides.py       #   Pesticide recommendations
│   │   ├── insecticides.py     #   Insecticide recommendations
│   │   ├── weather.py          #   Live weather (cached)
│   │   ├── irrigation.py       #   Irrigation guidance
│   │   ├── chat.py             #   AI chatbot
│   │   ├── plots.py            #   Farm plot management
│   │   ├── plants.py           #   Plant tracking
│   │   ├── images.py           #   Image upload (Cloudinary)
│   │   └── history.py          #   Analysis history
│   ├── models/                 # SQLAlchemy ORM models
│   ├── schemas/                # Pydantic request/response schemas
│   ├── rules_engine/           # Chemical dosage & weather-gate logic
│   ├── vision/                 # EfficientNet-B0 inference
│   ├── services/               # Gemini AI chat service
│   ├── auth/                   # JWT & password hashing utilities
│   ├── alembic/                # Database migrations
│   ├── main.py                 # App entry point
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example            # Environment variable template
│
├── frontend/                   # Flutter mobile app
│   ├── lib/
│   │   ├── core/               # API client, theme, translations, storage
│   │   ├── providers/          # Riverpod state management
│   │   ├── router/             # go_router navigation
│   │   ├── screens/            # UI screens (18 screens)
│   │   ├── widgets/            # Reusable UI components
│   │   └── main.dart           # App entry point
│   ├── android/                # Android build config
│   ├── assets/images/          # App images & icons
│   └── pubspec.yaml            # Flutter dependencies
│
├── .env.example                # Root environment variable template
└── README.md                   # This file
```

---

## Getting Started

### Prerequisites
- **Python 3.11+**
- **Flutter 3.12+** (with Android SDK for APK build)
- **Docker** (optional, for containerised backend)

### Backend Setup

```bash
cd Kissan-Ai-main/backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your real API keys

# Run database migrations
alembic upgrade head

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### Frontend Setup

```bash
cd Kissan-Ai-main/frontend

# Get Flutter dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build release APK
flutter build apk --release
```

### Docker (Backend)

```bash
cd Kissan-Ai-main/backend
docker-compose up --build
```

---

## API Endpoints

| Module | Method | Endpoint | Description |
|---|---|---|---|
| Auth | POST | `/api/auth/register` | Create user account |
| Auth | POST | `/api/auth/login` | Issue JWT token |
| Auth | GET | `/api/auth/profile` | Get user profile |
| Images | POST | `/api/images/upload` | Upload image to Cloudinary |
| Disease | POST | `/api/disease/detect` | AI disease detection |
| Pests | POST | `/api/pests/detect` | AI pest detection |
| Pesticides | GET | `/api/pesticides/{id}` | Get pesticide recommendation |
| Insecticides | GET | `/api/insecticides/{id}` | Get insecticide recommendation |
| Weather | GET | `/api/weather/current` | Live weather (Redis-cached) |
| Irrigation | POST | `/api/irrigation/recommend` | Crop + irrigation recommendation |
| Irrigation | GET | `/api/irrigation/guide/{id}` | Irrigation schedule |
| Chat | POST | `/api/chat/message` | AI chatbot message |
| History | GET | `/api/history` | User analysis history |
| Plots | CRUD | `/api/plots` | Farm plot management |
| Health | GET | `/health` | Service health check |

---

## Security & Design Principles

- **No raw SQL** — SQLAlchemy ORM only, all queries parameterized
- **Zero API keys in frontend** — all third-party calls routed through backend
- **Chemical dosage from Rules Engine only** — AI models never prescribe treatments directly
- **Weather-gated recommendations** — chemical application blocked when rain/wind is unsafe
- **Confidence threshold (0.70)** — low-confidence results show "Consult an agronomist" fallback
- **bcrypt password hashing** — passwords never stored in plaintext
- **Rate limiting** — slowapi protects against abuse
- **JWT authentication** — secure token-based auth with refresh tokens

---

## Team

Built at the **Alibaba Hackathon** by:

| Name | Role |
|---|---|
| Hafiz Muhammad Abubakar | Founder & Developer |
| Rana Adnan | Founder & Developer |
| Rana Ali Turab | Founder & Developer |

---

## Links

- **Landing Page & APK:** [kissan-ai-landing.vercel.app](https://kissan-ai-landing.vercel.app/)
- **Live API:** [kissanai-pkzn.onrender.com](https://kissanai-pkzn.onrender.com/health)
- **API Documentation:** [kissanai-pkzn.onrender.com/docs](https://kissanai-pkzn.onrender.com/docs)

---

## License

This project is proprietary. All rights reserved.
