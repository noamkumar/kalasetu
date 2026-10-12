import time
import base64
import hashlib
import hmac
import json
import logging
from typing import Optional, Dict, Any
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.session import get_db
from app.models.db_models import Artisan

logger = logging.getLogger("kalasetu.auth")
settings = get_settings()
security = HTTPBearer(auto_error=False)

# In-memory OTP store for development/demo: { phone: {"otp": "123456", "expires_at": timestamp} }
_otp_store: Dict[str, Dict] = {}

DEMO_PHONE_NUMBERS = {
    "+919876543210",
    "+919876543211",
    "+919876543212",
    "+919876543220",
    "+919876543221",
}

def normalize_phone(phone: str) -> str:
    """Normalize phone number to E.164 (+91) format for Indian mobile numbers."""
    clean = phone.strip().replace(" ", "").replace("-", "")
    if clean.startswith("+91") and len(clean) == 13:
        return clean
    if clean.startswith("+"):
        return clean
    if clean.startswith("0") and len(clean) == 11:
        return "+91" + clean[1:]
    if clean.startswith("91") and len(clean) == 12:
        return "+" + clean
    if len(clean) == 10 and clean.isdigit():
        return "+91" + clean
    return clean

def is_demo_phone(phone: str) -> bool:
    norm = normalize_phone(phone)
    raw_10 = norm[3:] if norm.startswith("+91") else norm
    return norm in DEMO_PHONE_NUMBERS or raw_10 in {p.replace("+91", "") for p in DEMO_PHONE_NUMBERS}

def send_otp(phone: str) -> str:
    """Generate and store OTP. In dev or for demo accounts, uses 123456. In prod for real accounts, generates random OTP."""
    import secrets
    norm = normalize_phone(phone)
    clean = phone.strip().replace(" ", "").replace("-", "")
    if is_demo_phone(norm) or settings.APP_ENV == "development":
        otp = "123456"
    else:
        otp = f"{secrets.randbelow(900000) + 100000}"

    record = {
        "otp": otp,
        "expires_at": time.time() + 600  # 10 minutes
    }
    _otp_store[norm] = record
    if clean != norm:
        _otp_store[clean] = record

    logger.info(f"[OTP] Phone: {norm} => OTP issued (demo: {is_demo_phone(norm)})")
    if settings.APP_ENV == "development" or is_demo_phone(norm):
        print(f"\n=======================================================\n[AUTH OTP] Phone: {norm} => OTP: {otp}\n=======================================================\n")
    return otp

def verify_otp(phone: str, otp: str) -> bool:
    """Verify phone and OTP match. Fixed OTP 123456 is accepted ONLY for demo numbers."""
    norm = normalize_phone(phone)
    clean = phone.strip().replace(" ", "").replace("-", "")

    # Fixed OTP 123456 is accepted ONLY for demo accounts
    if is_demo_phone(norm) and otp == "123456":
        return True

    # Real numbers must match the dynamically issued OTP
    record = _otp_store.get(norm) or _otp_store.get(clean)
    if not record:
        return False
    if time.time() > record["expires_at"]:
        _otp_store.pop(norm, None)
        _otp_store.pop(clean, None)
        return False
    if record["otp"] == otp:
        _otp_store.pop(norm, None)
        _otp_store.pop(clean, None)
        return True
    return False

def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")

def _b64url_decode(s: str) -> bytes:
    pad = s + "=" * ((4 - len(s) % 4) % 4)
    return base64.urlsafe_b64decode(pad)

def create_access_token(data: dict, expires_seconds: Optional[int] = None) -> str:
    now = int(time.time())
    exp = now + (expires_seconds or (settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60))
    header = {"alg": "HS256", "typ": "JWT"}
    payload = data.copy()
    payload.update({"iat": now, "exp": exp, "type": "access"})

    h_enc = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    p_enc = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{h_enc}.{p_enc}".encode("utf-8")
    sig = hmac.new(settings.JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
    s_enc = _b64url_encode(sig)
    return f"{h_enc}.{p_enc}.{s_enc}"

def create_refresh_token(data: dict) -> str:
    now = int(time.time())
    exp = now + (settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400)
    header = {"alg": "HS256", "typ": "JWT"}
    payload = data.copy()
    payload.update({"iat": now, "exp": exp, "type": "refresh"})

    h_enc = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    p_enc = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{h_enc}.{p_enc}".encode("utf-8")
    sig = hmac.new(settings.JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
    s_enc = _b64url_encode(sig)
    return f"{h_enc}.{p_enc}.{s_enc}"

def decode_token(token: str) -> dict:
    parts = token.strip().split(".")
    if len(parts) != 3:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    h_enc, p_enc, s_enc = parts
    signing_input = f"{h_enc}.{p_enc}".encode("utf-8")
    expected_sig = hmac.new(settings.JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
    try:
        raw_sig = _b64url_decode(s_enc)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token signature format")

    if not hmac.compare_digest(raw_sig, expected_sig):
        raise HTTPException(status_code=401, detail="Invalid token signature")

    try:
        payload = json.loads(_b64url_decode(p_enc).decode("utf-8"))
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    if payload.get("exp", 0) < int(time.time()):
        raise HTTPException(status_code=401, detail="Token has expired")

    return payload

def get_current_artisan(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Artisan:
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_token(credentials.credentials)
    artisan_id = payload.get("sub")
    if not artisan_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing user identity",
        )
    artisan = db.query(Artisan).filter(Artisan.id == artisan_id).first()
    if not artisan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User account not found",
        )
    return artisan

def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Artisan:
    return get_current_artisan(credentials, db)

def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[Artisan]:
    if not credentials:
        return None
    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        if not user_id:
            return None
        return db.query(Artisan).filter(Artisan.id == user_id).first()
    except Exception:
        return None
