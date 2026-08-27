# Kisan AI 🌾
**AI-Powered Agricultural Intelligence Platform for Pakistani Smallholder Farmers**  
Team R-Cube · Alibaba Cloud AI Hackathon Pakistan 2026

---

## 📁 Project Structure

```
kisan-ai/
├── frontend/        # Flutter app (Track 1)
├── backend/         # FastAPI + PostgreSQL (Track 2)
├── integration/     # Pydantic schemas, Rules Engine, AI models (Track 3)
└── .qoder/
    └── rules/       # Shared context for Qoder — app flow, DB schema, security rules
        ├── Kisan_AI_App_Flow.md
        └── Kisan_AI_Database_ERD.mermaid
```

---

## 👥 Team & Tracks

| Track | Folder | Responsibility |
|---|---|---|
| 1. Frontend & UX | `frontend/` | Flutter UI, camera/gallery, state management |
| 2. Backend & Cloud | `backend/` | FastAPI, ApsaraDB RDS, OSS, API Gateway |
| 3. Integration, AI & Logic | `integration/` | Pydantic schemas, Rules Engine, EfficientNet/Qwen |

---

## 🚀 Getting Started

**1. Clone the repo**
```bash
git clone <repo-url>
cd kisan-ai
```

**2. Create your own branch — never push directly to main**
```bash
git checkout -b frontend-dev   # or backend-dev / integration-dev
```

**3. Work only inside your track's folder**
- Frontend → everything inside `frontend/`
- Backend → everything inside `backend/`
- Integration → everything inside `integration/`

**4. Commit and push your work at the end of each session**
```bash
git add .
git commit -m "Short description of what you did"
git push -u origin <your-branch-name>
```

**5. Before starting a new day, sync with main**
```bash
git checkout main
git pull
git checkout <your-branch-name>
git merge main
```

**6. When a feature is ready, open a Pull Request on GitHub**  
Compare & pull request → review → Merge pull request

---

## 🧠 Using Qoder

Qoder automatically reads `.qoder/rules/` for context on every request. Before asking Qoder to build something, make sure your prompt lines up with:

- **`Kisan_AI_App_Flow.md`** — screen map, auth flow, design system, result-screen contract, data flow, API routes, security rules, naming conventions
- **`Kisan_AI_Database_ERD.mermaid`** — full database schema (15 tables)

If you're building a new feature that isn't covered in these files, **add it there first** so the whole team (and Qoder) stays in sync.

---

## 🔒 Non-Negotiable Rules

- **No raw SQL from user input** — use the ORM or parameterized queries only (see `.qoder/rules` Section 5)
- **No API keys or credentials in the frontend** — all third-party calls go through the backend
- **Chemical/dosage advice comes only from the Rules Engine** — never directly from the AI model
- **Every result screen answers 4 questions:** What is the problem? Why did it happen? What should I do now? What should I avoid?

---

## 📅 Build Timeline

| Day | Date | Focus |
|-----|------|-------|
| 1 | Aug 24 | Foundation — Flutter scaffold, RDS schema (15 tables), Auth APIs, mock endpoints |
| 2 | Aug 25 | Auth flow (Register/Login/JWT), Onboarding submit, PLOTS + PLOT_CROPS + PLOT_LIVESTOCK |
| 3 | Aug 26 | Image upload, OSS storage, offline queue (SQLite/Hive) |
| 4 | Aug 27 | Rules Engine, Weather integration, Weather Gate |
| 5 | Aug 28 | Live AI integration (EfficientNet-B0, Qwen chat via DashScope) |
| 6 | Aug 29 | Crop Recommendation, Irrigation Guide, History screen |
| 7 | Aug 30 | Cloud deployment (ACK), API Gateway, security pass |
| 8 | Aug 31 | Speed tests (< 3s), end-to-end test with real images |
| 9 | Sep 1 | UI polish — accessibility, sunlight readability, low-confidence fallback cards |
| 10 | Sep 2 | Full integration QA — all 3 tracks connected end-to-end |
| 11 | Sep 3 | Golden Rule audit — every result screen passes 4-question contract |
| 12 | Sep 4 | Final APK build, live FastAPI URL confirmed, demo device ready |
| — | Sep 5–7 | 🏆 Regional Rounds (in-person) |

---

*Built for the Alibaba Cloud AI Hackathon Pakistan 2026 — Alkhidmat Foundation Pakistan, Bano Qabil Platform.*
