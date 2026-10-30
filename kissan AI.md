# 🌱 Kissan AI — Your Smart AI-Powered Farming Assistant

**Empowering Farmers with Artificial Intelligence | Smarter Farming, Better Harvests.**

Kissan AI is an intelligent agricultural mobile application designed to help farmers make smarter farming decisions using Artificial Intelligence. It provides AI-powered crop disease detection, pest identification, personalized irrigation guidance, weather intelligence, crop recommendations, and a multilingual AI farming assistant — all in one platform.

<p align="center">
  <a href="https://kissan-ai-landing.vercel.app/">
    <strong>🌐 Visit Website & Download App</strong>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/FastAPI-Backend-009688?logo=fastapi" />
  <img src="https://img.shields.io/badge/Supabase-Database-3ECF8E?logo=supabase" />
  <img src="https://img.shields.io/badge/Python-AI%20Backend-3776AB?logo=python" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue" />
</p>

---

## 🌾 About Kissan AI

Agriculture is the backbone of Pakistan's economy, yet farmers often struggle with crop diseases, pest infestations, unpredictable weather, irrigation management, and limited access to agricultural experts.

Kissan AI bridges this gap by bringing intelligent agricultural assistance directly to farmers' smartphones.

Using AI-powered image analysis, machine learning, weather data, and conversational AI, Kissan AI helps farmers understand crop health, identify potential problems, and make more informed decisions.

Our mission is to make modern agricultural technology accessible, affordable, and easy to use for every farmer.

---

## 🚀 Key Features

### 🌿 1. AI Crop Disease Detection
- Upload or capture crop and leaf images.
- AI-powered disease identification.
- Confidence-based prediction results.
- Recommended next steps and treatment guidance.

### 🐛 2. AI Pest Detection
- Identify agricultural pests through images.
- Analyse potential pest infestations.
- Get guidance to help protect crops.

### 🤖 3. Kissan AI Chat Assistant
- Intelligent AI-powered agricultural chatbot.
- Ask questions about farming, crops, and agriculture.
- Multilingual communication support.
- Supports English, Urdu, Punjabi, Sindhi, Pashto, and Balochi.

### 🌦️ 4. Weather Intelligence
- Current weather information.
- Temperature and humidity monitoring.
- Wind speed information.
- Weather forecasts.
- Location-based weather updates.

### 🌱 5. Smart Crop Recommendations
- AI-assisted crop suggestions.
- Recommendations based on soil type.
- Water availability considerations.
- Seasonal crop guidance.

### 💧 6. Smart Irrigation Guidance
- Personalized irrigation recommendations.
- Crop-based watering guidance.
- Farm and plot-specific information.
- Water management assistance.

### 🧑‍🌾 7. Farm & Plot Management
- Manage agricultural plots.
- Track crop information.
- Organize farm-related data.

### 📊 8. Analysis History
- Access previous crop disease analyses.
- Review pest detection results.
- Keep track of agricultural analysis records.

---

## 🛠️ Technology Stack

### Frontend — Flutter
- Flutter & Dart
- Riverpod — State Management
- Dio — API Communication
- go_router — Navigation
- Hive — Local Storage
- flutter_secure_storage — Secure Token Storage
- image_picker — Camera & Gallery
- geolocator — Location Services

### Backend — Python & FastAPI
- Python
- FastAPI
- SQLAlchemy
- Pydantic
- Alembic
- JWT Authentication
- bcrypt Password Hashing
- slowapi Rate Limiting

### Artificial Intelligence
- PyTorch
- EfficientNet-B0
- Google Gemini API
- AI-powered Image Analysis
- Multilingual AI Chat

### Database & Cloud Services
- Supabase PostgreSQL
- Redis Cloud
- Cloudinary
- OpenWeatherMap API

### Deployment & Infrastructure
- Render
- Docker
- Vercel
- GitHub

---

## 🏗️ System Architecture

```text
                 KISSAN AI MOBILE APP
                         |
                         |
                  Flutter Frontend
                         |
                   HTTPS / REST API
                         |
                         ▼
                  FASTAPI BACKEND
                         |
       ┌─────────────────┼──────────────────┐
       |                 |                  |
       ▼                 ▼                  ▼
 Authentication     AI Services        API Routers
       |                 |                  |
       |           ┌─────┴─────┐            |
       |           |           |            |
       |           ▼           ▼            |
       |       EfficientNet   Gemini AI     |
       |       Image Model    Chat          |
       |           |           |            |
       └───────────┴───────────┴────────────┘
                         |
                         ▼
                 CLOUD SERVICES
                         |
          ┌──────────────┼──────────────┐
          |              |              |
          ▼              ▼              ▼
       Supabase        Redis        Cloudinary
      PostgreSQL       Cache        Image Storage
                         |
                         ▼
                  OpenWeatherMap
```

---

## 📁 Project Structure

```text
KissanAI/
│
├── Kisan_AI_App_Flow.pdf
│
└── Kissan-Ai-main/
    │
    ├── backend/
    │   ├── routers/
    │   ├── models/
    │   ├── schemas/
    │   ├── services/
    │   ├── vision/
    │   ├── rules_engine/
    │   ├── auth/
    │   ├── alembic/
    │   ├── utils/
    │   ├── main.py
    │   ├── requirements.txt
    │   ├── Dockerfile
    │   └── .env.example
    │
    └── frontend/
        ├── lib/
        │   ├── core/
        │   ├── providers/
        │   ├── router/
        │   ├── screens/
        │   ├── widgets/
        │   └── main.dart
        │
        ├── android/
        ├── ios/
        ├── assets/
        ├── test/
        └── pubspec.yaml
```

---

## ⚙️ Installation & Setup

### Prerequisites

Make sure you have installed:

- Python 3.11+
- Flutter SDK
- Dart SDK
- Android Studio / Android SDK
- Git
- PostgreSQL / Supabase Account

### 1. Clone Repository

```bash
git clone https://github.com/RC-Technologies2026/KissanAI.git

cd KissanAI/Kissan-Ai-main
```

### 2. Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Create a virtual environment:

```bash
python -m venv venv
```

Activate virtual environment:

**Windows:**
```bash
venv\Scripts\activate
```

**Linux / macOS:**
```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Configure environment variables:

```bash
copy .env.example .env
```

For Linux / macOS:

```bash
cp .env.example .env
```

Add your required API keys and service credentials to the `.env` file.

Run database migrations:

```bash
alembic upgrade head
```

Start the backend:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend API:

```text
http://localhost:8000
```

Swagger API Documentation:

```text
http://localhost:8000/docs
```

### 3. Frontend Setup

Open another terminal:

```bash
cd KissanAI/Kissan-Ai-main/frontend
```

Install Flutter dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

Build Android APK:

```bash
flutter build apk --release
```

Generated APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔌 API Modules

| Module | Description |
|---|---|
| Authentication | User registration and login |
| Disease Detection | AI-powered crop disease analysis |
| Pest Detection | AI-powered pest identification |
| Weather | Live weather information |
| Irrigation | Smart irrigation recommendations |
| Crop Recommendations | AI-assisted crop suggestions |
| Chat Assistant | Multilingual AI farming chatbot |
| Images | Image upload and storage |
| Farm Plots | Agricultural plot management |
| History | Previous analysis records |

For complete API documentation, run the backend and visit:

**http://localhost:8000/docs**

---

## ☁️ Deployment

Kissan AI uses cloud infrastructure for its backend, database, caching, image storage, and landing page.

| Service | Platform |
|---|---|
| Backend API | Render |
| Database | Supabase |
| Cache | Redis Cloud |
| Image Storage | Cloudinary |
| Landing Page | Vercel |
| Mobile Application | Flutter |

### Live Project Links

- 🌐 **Website & App Download:** https://kissan-ai-landing.vercel.app/
- ⚙️ **Backend API:** https://kissanai-pkzn.onrender.com/
- 💚 **Backend Health:** https://kissanai-pkzn.onrender.com/health
- 📚 **API Documentation:** https://kissanai-pkzn.onrender.com/docs

---

## 🔐 Security & Reliability

- Secure JWT-based authentication.
- Password hashing using bcrypt.
- Environment-based API key management.
- Rate limiting for API protection.
- Secure communication through HTTPS.
- Confidence-based AI prediction handling.
- Weather-aware agricultural recommendations.
- Rules-based safeguards for chemical dosage guidance.

**Important:** AI-generated results are intended as decision-support information. Farmers should verify disease diagnoses and treatment recommendations with qualified agricultural experts and follow official product labels.

---

## 🎯 Our Vision

Our vision is to transform traditional agriculture into smarter, technology-driven farming.

We aim to empower farmers with accessible AI technology, improve agricultural awareness, support better resource management, and contribute to a more productive agricultural ecosystem.

**Kissan AI — Growing a Smarter Agricultural Future. 🌱**

---

## 👨‍💻 Development Team

Built at the **Alibaba Hackathon**.

| Team Member | Role |
|---|---|
| Khadija Ahmad  | Founder & Developer |
| Rana Adnan | Founder & Developer |
| Yashfa Anwar | Founder & Developer |

---

## 📄 License

Please contact the repository maintainers for licensing and permission details.

---

<p align="center">
  <strong>🌱 KISSAN AI</strong>
  <br/>
  <i>Smart Farming. Smarter Future.</i>
  <br/><br/>
