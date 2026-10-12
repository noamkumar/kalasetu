from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    APP_NAME: str = "KalaSetu Backend"
    APP_ENV: str = "development"
    API_BASE_PATH: str = "/api/v1"
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # AI Mode & Gemini Configuration
    AI_MODE: str = "real"
    GEMINI_API_KEY: str = ""
    GEMINI_TEXT_MODEL: str = "gemini-3.8-flash"
    GEMINI_FALLBACK_MODEL: str = "gemini-3.1-flash-lite"
    GEMINI_IMAGE_MODEL: str = ""
    GEMINI_TTS_MODEL: str = "gemini-2.5-flash-preview-tts"
    GEMINI_TTS_VOICE: str = "Kore"
    REQUEST_TIMEOUT_SECONDS: int = 60
    
    STT_PROVIDER: str = "gemini"
    IMAGE_EDIT_PROVIDER: str = "local"
    ENABLE_LOCAL_FALLBACK: bool = False
    # Demo & Authentication Mode Configuration
    # When DEMO_MODE or ENABLE_UNIVERSAL_DEMO_OTP is True (or APP_ENV == "development"),
    # any valid 10-digit Indian mobile number can log in with demo OTP 123456.
    # Universal demo OTP verification is intended for demonstrations and development,
    # and does not verify real phone ownership.
    DEMO_MODE: bool = False
    ENABLE_UNIVERSAL_DEMO_OTP: bool = True

    # Database & Storage
    DATABASE_URL: str = "sqlite:///./kalasetu.db"
    STORAGE_BACKEND: str = "local" # local | s3 | supabase
    STORAGE_BUCKET: str = "kalasetu-storage"
    STORAGE_LOCAL_PATH: str = "./uploads"
    STORAGE_ENDPOINT_URL: str = ""
    STORAGE_ACCESS_KEY: str = ""
    STORAGE_SECRET_KEY: str = ""
    STORAGE_REGION: str = "us-east-1"
    STORAGE_PUBLIC_URL_BASE: str = ""
    VOICE_CACHE_PATH: str = "./uploads/voice_cache"
    
    # Auth
    JWT_SECRET: str = "kalasetu_secret_jwt_key"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    
    # CORS
    ALLOWED_ORIGINS: str = "*"
    CORS_ORIGINS: list[str] = ["*"]

    # Gemini Cost & Quota Protection
    GEMINI_DAILY_USER_CAP: int = 50
    GEMINI_DAILY_IP_CAP: int = 100
    GEMINI_DAILY_DEMO_CAP: int = 15

    model_config = SettingsConfigDict(
        env_file=(".env", "../.env", "backend/.env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()
