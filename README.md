# KalaSetu (कलासेतु) — Artisan AI

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.142+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11.9-3776AB?logo=python)](https://www.python.org)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-3.8%20Flash-8E75C2?logo=google)](https://ai.google.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)

> **Bridging Indian Artisans to the World**  
> An offline-first, voice-first mobile and desktop application that transforms a phone photo and a spoken sentence in any regional Indian language into a marketplace-ready e-commerce listing with studio photography, 6-language SEO cataloging, dynamic fair pricing, and order tracking.

---

## 🏛️ Visual Design System: Linen and Olive

KalaSetu adopts a **Soft Luxury Minimalist** design language celebrating Indian handicraft traditions:

- **Travertine Off-White Background** (`#FAF6F0`): Clean, natural gallery canvas.
- **Sage Olive** (`#606C56`): Earthy primary brand accent for actions and active states.
- **Linen Sand / Ochre** (`#C7A379`): Warm artisan accent for secondary actions.
- **Espresso Charcoal Ink** (`#2B2E2A`): High-contrast readable typography meeting WCAG AA accessibility standards.
- **KalaMitra Assistant Blue** (`#4A6572`): Distinctive floating voice assistant capsule.
- **Warli Motifs & Tanka Stitching**: Cultural Indian line-art illustrations and progress steppers.

---

## 📸 Screenshots & Previews

| Mobile Home & Catalog | AI Photo Studio | 6-Language Review | Dynamic Pricing |
| :---: | :---: | :---: | :---: |
| ![Mobile Catalog](docs/artifacts/screenshot_home.png) | ![AI Studio](docs/artifacts/screenshot_studio.png) | ![Catalog Review](docs/artifacts/screenshot_catalog.png) | ![Pricing Assistant](docs/artifacts/screenshot_pricing.png) |

| Responsive Desktop Portal | Orders & Timeline | KalaMitra Assistant |
| :---: | :---: | :---: |
| ![Desktop Dashboard](docs/artifacts/screenshot_desktop.png) | ![Orders Timeline](docs/artifacts/screenshot_orders.png) | ![KalaMitra Assistant](docs/artifacts/screenshot_kalamitra.png) |

*(Screenshot placeholders located in `docs/artifacts/`)*

---

## 🚀 Key Features

### 1. 📸 AI Image Studio & Dual-Mode Enhancer
- **Automatic Background Removal**: Free local cut-out powered by `rembg` (U2-Net) or generative cloud isolation.
- **Studio Lighting Correction**: Automatic white balance, CLAHE exposure equalization, and subtle sharpening.
- **Artisan Canvas Centering**: Centered with soft contact shadow on pure white or `#FAF6F0` linen background.
- **Multi-Resolution Export**: 2000×2000 hero WebP, 1080×1350 portrait/social format, and 600px thumbnail.
- **Quality Score & Tips**: Sharpness, lighting, and framing quality metrics with localized tips.

### 2. 🎙️ Multilingual Voice-to-Listing Auto-Cataloger
- **Voice Recording**: 16 kHz audio capture with live visual waveform and timer.
- **Multilingual STT**: Transcribes English, Hindi (हिन्दी), Tamil (தமிழ்), Telugu (తెలుగు), Kannada (ಕನ್ನಡ), and Malayalam (മലയാളം).
- **6-Language Catalog Generation**: Gemini synthesizes a structured master listing (title, short & long description, bullet points, care instructions, SEO tags, hashtags) and automatically localizes into all 6 languages.
- **Artisan Review & Edit**: Tabbed review screen allowing real-time edits, TTS audio playback ("Tap to hear"), and one-tap publishing.

### 3. ⚖️ Dynamic Fair Pricing Assistant
- **Statutory Cost Floor**: Strictly prevents underpricing:
  $$\text{Floor} = \text{Material Cost} + (\text{Labour Hours} \times ₹80/\text{hr}) + \text{Other Costs} + 10\% \text{ Overhead}$$
- **Gradient Boosted Tree Model**: LightGBM machine learning regressor trained on 320 handcrafted items ($R^2 = 0.987$).
- **Market Comparables & Psychological Rounding**: 25th, 50th, and 75th percentile market distribution with retail price points (₹449, ₹599, ₹1,299).
- **Spoken Explanation**: Spoken breakdown of costs and margins in the artisan's language.

### 4. 📦 Complete Order Flows & Tracking Timeline
- **Order Milestones**: Tracks transitions through `New`, `Packed`, `Shipped`, and `Delivered`.
- **Vertical Tracking Timeline**: Displays timestamps, courier name, and tracking ID.
- **Notification Bell**: Live unread badge count updating artisans on customer purchases.

### 5. 🤖 KalaMitra Multilingual Voice Assistant
- **Voice-First FAB**: Bottom sheet assistant callable from any screen.
- **Gemini Intent Routing**: Recognizes commands like *"Add product"*, *"Show pending orders"*, *"Change language to Tamil"*, or *"How should I price clay pots?"*.
- **Offline Fallback**: High-speed rule-based engine operates even without internet connectivity.
- **TTS Speech Feedback**: Answers back aloud in the artisan's preferred app language.

### 6. 📊 Responsive Desktop / Web Dashboard
- **Sidebar Shell**: Desktop navigation rail (breakpoint $\ge 900$px).
- **KPI Metrics**: Total Revenue, Total Orders, Pending Orders, Active Products.
- **30-Day Revenue Trend Chart**: Smooth interactive curve with gradient fill powered by `fl_chart`.
- **Popular Crafts Breakdown**: Visual category distribution with order and revenue statistics.

---

## 🏗️ Production Architecture

```
                    +-----------------------------+
                    |       Flutter Client        |
                    |  (Web on Vercel / Android)  |
                    +--------------+--------------+
                                   |
                             HTTPS | (REST / JSON)
                                   v
                    +-----------------------------+
                    |      FastAPI on Render      |
                    |   (uvicorn app.main:app)    |
                    +-------+-------------+-------+
                            |             |
               SQLAlchemy 2 |             | S3 API (boto3)
                            v             v
           +--------------------+    +--------------------+
           |  Hosted PostgreSQL |    | S3 / Supabase      |
           |  (Render Postgres) |    | Object Storage     |
           +--------------------+    +--------------------+
```

---

## 🔑 Demo Mode Credentials

When `DEMO_MODE=true`, the backend seeds demo accounts with realistic products, translations, and orders.
The fixed OTP **`123456`** is accepted **ONLY** for these 5 numbers:

| Role | Name | Phone Number | Fixed OTP | Craft / Specialization | State | Preferred Language |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Artisan** | Rameshwar Prajapati | `+919876543210` | `123456` | Pottery (Terracotta) | Uttar Pradesh | हिन्दी (`hi`) |
| **Artisan** | Devi Meenakshi | `+919876543211` | `123456` | Handloom Silk Weaving | Tamil Nadu | தமிழ் (`ta`) |
| **Artisan** | Somnath Soren | `+919876543212` | `123456` | Tribal Woodcraft | West Bengal | English (`en`) |
| **Buyer** | Priya Sharma | `+919876543220` | `123456` | Craft Collector / Retail | Delhi | English (`en`) |
| **Buyer** | Vikram Singhania | `+919876543221` | `123456` | Boutique Store Owner | Karnataka | ಕನ್ನಡ (`kn`) |

> 🔒 **Security Note**: Real phone numbers keep the live dynamic OTP verification interface and reject `123456`.

---

## 🛡️ Gemini Cost Protection & Quotas

To safeguard production Gemini API budgets against unexpected spikes or scraping:
- **Per-User Daily Cap**: 50 AI requests/day per authenticated user (configured via `GEMINI_DAILY_USER_CAP`).
- **Per-IP Daily Cap**: 100 AI requests/day per client IP (configured via `GEMINI_DAILY_IP_CAP`).
- **Demo Account Daily Cap**: 15 AI requests/day for demo accounts (configured via `GEMINI_DAILY_DEMO_CAP`).
- **Friendly Localized Feedback**: When a limit is reached, returns HTTP 429 with a kind spoken message in all 6 languages explaining that the quota resets at midnight and that local drafts and catalog browsing remain fully functional.

---

## ⚡ Quick Start & Setup

### 1. Backend Setup (Local Development)

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate.ps1       # On Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt

# Start backend server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
- Health Check: [http://localhost:8000/health](http://localhost:8000/health)
- Swagger Docs: [http://localhost:8000/docs](http://localhost:8000/docs)

### 2. Frontend Web Build & Launch

```bash
cd frontend
flutter pub get

# Run on Chrome
flutter run -d chrome

# Build for Web production (Vercel):
.\scripts\build_web.ps1 -ApiBaseUrl "https://kalasetu-backend.onrender.com/api/v1"
```

### 3. Android Release Build

```bash
# Build signed production release APK:
.\scripts\build_release.ps1 -ApiBaseUrl "https://kalasetu-backend.onrender.com/api/v1"
```
The output APK is generated at `frontend/build/app/outputs/flutter-apk/app-release.apk` and copied to `KalaSetu-release.apk`.

---

## 🚀 Deployment Guides

For step-by-step production setup:
- **Cloud Backend & Storage**: See [docs/DEPLOY.md](docs/DEPLOY.md) (Render, PostgreSQL, Supabase/S3, environment variables).
- **Android Release & Keystore**: See [docs/RELEASE.md](docs/RELEASE.md) (Keystore backup, signing, GitHub Releases).
- **Architectural Log**: See [docs/DECISIONS.md](docs/DECISIONS.md).

---

## 🧪 Automated Test Suites

```bash
# Backend pytest suite (in backend/)
pytest tests/

# Frontend test suite & static analysis (in frontend/)
flutter analyze
flutter test
```

---

## 📄 License
MIT License. Handcrafted with pride for Indian artisans.
