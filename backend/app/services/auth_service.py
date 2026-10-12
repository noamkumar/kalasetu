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

def is_demo_mode_active() -> bool:
    """Returns True if demo authentication mode is active (via DEMO_MODE, ENABLE_UNIVERSAL_DEMO_OTP, or APP_ENV=development)."""
    return bool(
        getattr(settings, "DEMO_MODE", False)
        or getattr(settings, "ENABLE_UNIVERSAL_DEMO_OTP", True)
        or settings.APP_ENV == "development"
    )

def validate_and_normalize_phone(phone: str) -> str:
    """
    Validate and normalize Indian mobile phone numbers to E.164 (+91XXXXXXXXXX) format.
    Valid Indian mobile numbers are exactly 10 digits starting with 6, 7, 8, or 9.
    Accepts:
    - 9876543210 (10 digits)
    - +919876543210 (E.164 format)
    - 919876543210 (12 digits with 91 country code)
    - 09876543210 (11 digits with leading 0)
    - Formats with whitespace or hyphens (e.g. '+91 98765-43210')
    
    Raises ValueError with a user-friendly message if invalid.
    """
    if not phone or not str(phone).strip():
        raise ValueError("Phone number is required")

    clean = str(phone).strip().replace(" ", "").replace("-", "")

    # Extract the raw 10 digits
    if clean.startswith("+91") and len(clean) == 13:
        raw_10 = clean[3:]
    elif clean.startswith("91") and len(clean) == 12:
        raw_10 = clean[2:]
    elif clean.startswith("0") and len(clean) == 11:
        raw_10 = clean[1:]
    elif len(clean) == 10:
        raw_10 = clean
    else:
        if not clean.replace("+", "").isdigit():
            raise ValueError("Phone number must contain only digits")
        raise ValueError("Phone number must be a valid 10-digit mobile number")

    if not raw_10.isdigit() or len(raw_10) != 10:
        raise ValueError("Phone number must be a valid 10-digit mobile number")

    if raw_10[0] not in "6789":
        raise ValueError("Invalid Indian mobile number. Mobile numbers must start with 6, 7, 8, or 9")

    return f"+91{raw_10}"

def normalize_phone(phone: str) -> str:
    """Normalize phone number to E.164 (+91) format for Indian mobile numbers."""
    try:
        return validate_and_normalize_phone(phone)
    except ValueError:
        clean = phone.strip().replace(" ", "").replace("-", "")
        if len(clean) == 10 and clean.isdigit():
            return "+91" + clean
        return clean

def is_demo_phone(phone: str) -> bool:
    """Returns True if the phone matches one of the five documented seeded demo accounts."""
    norm = normalize_phone(phone)
    raw_10 = norm[3:] if norm.startswith("+91") else norm
    return norm in DEMO_PHONE_NUMBERS or raw_10 in {p.replace("+91", "") for p in DEMO_PHONE_NUMBERS}

def mask_phone(phone: str) -> str:
    clean = str(phone).strip()
    if len(clean) < 6:
        return "[REDACTED]"
    return f"{clean[:3]}******{clean[-4:]}"

def send_otp(phone: str) -> str:
    """
    Generate and store OTP.
    When demo mode is active or for the five documented demo accounts, uses 123456.
    In strict production mode without demo mode, generates random 6-digit OTP.
    """
    import secrets
    norm = validate_and_normalize_phone(phone)
    clean = phone.strip().replace(" ", "").replace("-", "")

    if is_demo_mode_active() or is_demo_phone(norm):
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

    logger.info(
        f"[OTP SERVICE] Phone: {mask_phone(norm)} => OTP generated "
        f"(is_demo_account: {is_demo_phone(norm)}, demo_mode: {is_demo_mode_active()})"
    )
    return otp

def verify_otp(phone: str, otp: str) -> bool:
    """
    Verify phone and OTP match.
    When demo mode is active or for the five documented demo accounts, accepts OTP 123456.
    In strict production mode, matches against the dynamically issued OTP in _otp_store.
    """
    norm = validate_and_normalize_phone(phone)
    clean = phone.strip().replace(" ", "").replace("-", "")
    is_demo_acc = is_demo_phone(norm)
    demo_mode = is_demo_mode_active()

    # Fixed OTP 123456 is accepted if demo mode is active or for documented demo accounts
    if (demo_mode or is_demo_acc) and otp == "123456":
        logger.info(f"[OTP SERVICE] Demo OTP verified for phone: {mask_phone(norm)} (demo_mode={demo_mode})")
        _otp_store.pop(norm, None)
        _otp_store.pop(clean, None)
        return True

    # Real numbers under strict mode must match the dynamically issued OTP
    record = _otp_store.get(norm) or _otp_store.get(clean)
    if not record:
        logger.warning(f"[OTP SERVICE] No active OTP record found for phone: {mask_phone(norm)}")
        return False
    if time.time() > record["expires_at"]:
        logger.warning(f"[OTP SERVICE] OTP record expired for phone: {mask_phone(norm)}")
        _otp_store.pop(norm, None)
        _otp_store.pop(clean, None)
        return False
    if record["otp"] == otp:
        logger.info(f"[OTP SERVICE] Dynamic OTP matched successfully for phone: {mask_phone(norm)}")
        _otp_store.pop(norm, None)
        _otp_store.pop(clean, None)
        return True
    logger.warning(f"[OTP SERVICE] Code mismatch for phone: {mask_phone(norm)}")
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
