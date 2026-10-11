# KalaSetu Deployment Guide (docs/DEPLOY.md)

This document provides complete instructions for deploying the KalaSetu platform to production:
- **Backend API**: Render (Web Service + Managed PostgreSQL)
- **Object Storage**: S3-compatible bucket (Supabase Storage or AWS S3 / Cloudflare R2)
- **Web Frontend**: Vercel (Flutter Web SPA)
- **Android APK**: GitHub Releases

---

## 1. Production Architecture Overview

```
                      +-----------------------------+
                      |       Flutter Client        |
                      |   (Web on Vercel / Android) |
                      +--------------+--------------+
                                     |
                                HTTPS| (REST / WebSocket)
                                     v
                      +-----------------------------+
                      |     FastAPI on Render       |
                      |  (uvicorn app.main:app)     |
                      +-------+-------------+-------+
                              |             |
                 SQLAlchemy 2 |             | boto3 S3 API
                              v             v
             +--------------------+    +--------------------+
             |  Hosted PostgreSQL |    | S3 / Supabase      |
             |  (Render Postgres) |    | Object Storage     |
             +--------------------+    +--------------------+
```

---

## 2. Backend Environment Variables Reference

Every environment variable supported by `backend/app/config.py`:

| Variable | Required in Prod | Default | Description |
| :--- | :--- | :--- | :--- |
| `APP_ENV` | Yes | `development` | Set to `production` in production. |
| `HOST` | No | `0.0.0.0` | Bind host. Render sets this automatically. |
| `PORT` | No | `8000` | Port passed by Render via `$PORT`. |
| `API_BASE_PATH` | No | `/api/v1` | Base API prefix route. |
| `DATABASE_URL` | **Yes** | `sqlite:///./kalasetu.db` | PostgreSQL connection string (`postgresql+psycopg2://...`). |
| `JWT_SECRET` | **Yes** | — | High-entropy secret key for HMAC-SHA256 JWT tokens. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `15` | JWT access token lifespan in minutes. |
| `REFRESH_TOKEN_EXPIRE_DAYS` | No | `30` | Refresh token lifespan in days. |
| `ALLOWED_ORIGINS` | Yes | `*` | Comma-separated allowed frontend origins (e.g. `https://kalasetu.vercel.app`). |
| `STORAGE_BACKEND` | **Yes** | `local` | Set to `s3` or `supabase` in production. |
| `STORAGE_BUCKET` | **Yes** | `kalasetu-storage` | S3 bucket name. |
| `STORAGE_ENDPOINT_URL` | If S3/Supabase | `""` | S3 endpoint URL (e.g., `https://<ref>.supabase.co/storage/v1/s3`). |
| `STORAGE_ACCESS_KEY` | If S3/Supabase | `""` | AWS S3 or Supabase Storage Access Key. |
| `STORAGE_SECRET_KEY` | If S3/Supabase | `""` | AWS S3 or Supabase Storage Secret Key. |
| `STORAGE_REGION` | If S3 | `us-east-1` | AWS / S3 Region. |
| `STORAGE_PUBLIC_URL_BASE` | Recommended | `""` | Public CDN/storage base URL for serving images. |
| `AI_MODE` | Yes | `real` | `real` for live Gemini API calls; `mock` for zero-key test mode. |
| `GEMINI_API_KEY` | **Yes** | `""` | Google Gemini API key. |
| `GEMINI_TEXT_MODEL` | No | `gemini-3.8-flash` | Text generation and catalog model. |
| `GEMINI_FALLBACK_MODEL` | No | `gemini-3.1-flash-lite` | Fallback language model. |
| `GEMINI_IMAGE_MODEL` | No | `gemini-3.1-flash-image` | Generative image editing model. |
| `GEMINI_TTS_MODEL` | No | `gemini-2.5-flash-preview-tts` | Audio synthesis model. |
| `GEMINI_TTS_VOICE` | No | `Kore` | Default Indic voice tone. |
| `DEMO_MODE` | No | `false` | `true` seeds 3 demo artisans & 2 buyers and accepts fixed OTP `123456` for demo accounts. |
| `GEMINI_DAILY_USER_CAP` | No | `50` | Maximum daily AI requests per artisan account. |
| `GEMINI_DAILY_IP_CAP` | No | `100` | Maximum daily AI requests per client IP address. |
| `GEMINI_DAILY_DEMO_CAP` | No | `15` | Maximum daily AI requests for demo accounts. |

---

## 3. Step-by-Step Render Deployment

### 3.1 Using `render.yaml` Blueprint (Recommended)
1. Fork or push this repository to GitHub.
2. In the Render Dashboard, click **New +** > **Blueprint**.
3. Select your repository. Render reads `render.yaml` and provisions:
   - Web Service: `kalasetu-backend` (Python 3.11)
   - PostgreSQL Database: `kalasetu-db`
4. Set the secret environment variables in the Render dashboard:
   - `GEMINI_API_KEY`: Your Google Gemini API key.
   - `STORAGE_ACCESS_KEY` & `STORAGE_SECRET_KEY`: Your S3/Supabase credentials.
   - `STORAGE_ENDPOINT_URL`: Your S3/Supabase endpoint.
   - `STORAGE_PUBLIC_URL_BASE`: Your bucket's public URL prefix.
5. Click **Apply**.

### 3.2 Manual Render Configuration
- **Runtime**: Python 3.11
- **Root Directory**: `backend`
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- **Health Check Path**: `/health`

---

## 4. Object Storage Setup (Supabase Storage / S3)

To ensure no photo upload depends on ephemeral local disk in production:

### Option A: Supabase Storage (Free tier included)
1. Create a project at [supabase.com](https://supabase.com).
2. Go to **Storage** > **New Bucket** > Name it `kalasetu-storage`. Mark it **Public**.
3. Go to **Project Settings** > **Storage** > **S3 Access Keys**. Generate an Access Key and Secret Key.
4. Set the following environment variables in Render:
   ```env
   STORAGE_BACKEND=s3
   STORAGE_BUCKET=kalasetu-storage
   STORAGE_ENDPOINT_URL=https://<your-project-id>.supabase.co/storage/v1/s3
   STORAGE_ACCESS_KEY=<generated-access-key>
   STORAGE_SECRET_KEY=<generated-secret-key>
   STORAGE_REGION=us-east-1
   STORAGE_PUBLIC_URL_BASE=https://<your-project-id>.supabase.co/storage/v1/object/public/kalasetu-storage
   ```

---

## 5. Flutter Web Deployment to Vercel

1. Build the web app locally or via CI:
   ```powershell
   ./scripts/build_web.ps1 -ApiBaseUrl "https://kalasetu-backend.onrender.com/api/v1"
   ```
2. In the Vercel Dashboard, import the repository:
   - **Framework Preset**: Other
   - **Root Directory**: `frontend`
   - **Build Command**: `flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=https://<your-backend>.onrender.com/api/v1`
   - **Output Directory**: `build/web`
3. `vercel.json` provides automatic SPA routing (`/*` -> `/index.html`).

---

## 6. Verification and Health Checks

After deployment, verify the services:
1. `GET https://<your-render-url>/health`
   Expected response:
   ```json
   {
     "status": "ok",
     "app": "KalaSetu",
     "version": "1.0.0",
     "environment": "production",
     "ai_mode": "real",
     "demo_mode": true,
     "storage_backend": "s3",
     "key_configured": true
   }
   ```
2. Verify interactive API docs at `https://<your-render-url>/docs`.
3. Open your Vercel web URL in Chrome, edge, or mobile browser and test camera, voice, and catalogue features.
