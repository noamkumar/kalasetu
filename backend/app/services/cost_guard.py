import logging
from datetime import datetime, timezone
from typing import Dict, Optional, Tuple
from fastapi import HTTPException, Request, Depends, status

from app.config import get_settings
from app.services.auth_service import get_current_user_optional, is_demo_phone

logger = logging.getLogger("kalasetu.cost_guard")

LOCALIZED_QUOTA_MESSAGES: Dict[str, str] = {
    "en": "Daily AI assistance limit reached. Your quota resets at midnight. You can still save drafts and view your catalogue.",
    "hi": "दैनिक एआई सहायता सीमा समाप्त हो गई है। आपका कोटा आधी रात को रीसेट हो जाएगा। आप अभी भी ड्राफ्ट सहेज सकते हैं और अपनी कैटलॉग देख सकते हैं।",
    "ta": "தினசரி AI உதவி வரம்பு முடிந்தது. உங்கள் ஒதுக்கீடு நள்ளிரவில் புதுப்பிக்கப்படும். நீங்கள் வரைவுகளை சேமிக்கவும் பட்டியலை பார்க்கவும் முடியும்.",
    "te": "రోజువారీ AI సహాయ పరిమితి ముగిసింది. మీ కోటా అర్ధరాత్రి రీసెట్ అవుతుంది. మీరు ఇప్పటికీ డ్రాఫ్ట్‌లను సేవ్ చేయవచ్చు మరియు మీ కేటలాగ్‌ను చూడవచ్చు.",
    "kn": "ದೈನಂದಿನ AI ನೆರವು ಮಿತಿ ತಲುಪಿದೆ. ನಿಮ್ಮ ಕೋಟಾ ಮಧ್ಯರಾತ್ರಿ ಮರುಹೊಂದಿಸಲ್ಪಡುತ್ತದೆ. ನೀವು ಇನ್ನೂ ಕರಡುಗಳನ್ನು ಉಳಿಸಬಹುದು ಮತ್ತು ನಿಮ್ಮ ಕ್ಯಾಟಲಾಗ್ ವೀಕ್ಷಿಸಬಹುದು.",
    "ml": "പ്രതിദിന AI സഹായ പരിധി കഴിഞ്ഞു. നിങ്ങളുടെ ക്വാട്ട അർദ്ധരാത്രിയിൽ പുനഃസജ്ജമാകും. നിങ്ങൾക്ക് ഇപ്പോഴും ഡ്രാഫ്റ്റുകൾ സേവ് ചെയ്യാനും കാറ്റലോഗ് കാണാനും കഴിയും.",
}

# In-memory tracking store:
# _user_usage: { (date_str, user_id): count }
# _ip_usage: { (date_str, ip_address): count }
_user_usage: Dict[Tuple[str, str], int] = {}
_ip_usage: Dict[Tuple[str, str], int] = {}


def _get_today_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def check_and_increment_quota(
    client_ip: str,
    user_id: Optional[str] = None,
    is_demo: bool = False,
    lang: str = "en"
) -> None:
    """Checks daily Gemini caps per IP and per user. Raises HTTP 429 with localized message if exceeded."""
    settings = get_settings()
    today = _get_today_str()
    req_lang = lang if lang in LOCALIZED_QUOTA_MESSAGES else "en"
    friendly_msg = LOCALIZED_QUOTA_MESSAGES.get(req_lang, LOCALIZED_QUOTA_MESSAGES["en"])

    # 1. IP-level Cap
    ip_key = (today, client_ip)
    current_ip_count = _ip_usage.get(ip_key, 0)
    if current_ip_count >= settings.GEMINI_DAILY_IP_CAP:
        logger.warning(f"Cost Guard: Daily IP cap reached for {client_ip} ({current_ip_count}/{settings.GEMINI_DAILY_IP_CAP})")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "code": "QUOTA_EXCEEDED",
                "message": friendly_msg,
                "localized_messages": LOCALIZED_QUOTA_MESSAGES,
                "reset": "midnight_utc",
                "scope": "ip",
            }
        )

    # 2. User-level Cap (with lower cap for demo accounts)
    if user_id:
        user_key = (today, user_id)
        current_user_count = _user_usage.get(user_key, 0)
        cap = settings.GEMINI_DAILY_DEMO_CAP if is_demo else settings.GEMINI_DAILY_USER_CAP

        if current_user_count >= cap:
            logger.warning(
                f"Cost Guard: Daily {'demo' if is_demo else 'user'} cap reached for {user_id} "
                f"({current_user_count}/{cap})"
            )
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "QUOTA_EXCEEDED",
                    "message": friendly_msg,
                    "localized_messages": LOCALIZED_QUOTA_MESSAGES,
                    "reset": "midnight_utc",
                    "scope": "demo" if is_demo else "user",
                }
            )

        # Increment user usage
        _user_usage[user_key] = current_user_count + 1

    # Increment IP usage
    _ip_usage[ip_key] = current_ip_count + 1


def get_client_ip(request: Request) -> str:
    """Extracts client IP, respecting X-Forwarded-For if behind a reverse proxy."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "127.0.0.1"


async def check_gemini_quota_dependency(
    request: Request,
    user = Depends(get_current_user_optional)
) -> None:
    """FastAPI dependency to protect Gemini endpoints with daily user and IP rate limits."""
    client_ip = get_client_ip(request)
    user_id = user.id if user else None
    is_demo = False
    lang = "en"

    if user:
        is_demo = is_demo_phone(user.phone)
        lang = getattr(user, "preferred_language", "en")

    # Check query/header for language preference
    lang_param = request.query_params.get("lang") or request.headers.get("Accept-Language", lang)
    if lang_param:
        lang = lang_param.split(",")[0].split("-")[0].strip()

    check_and_increment_quota(client_ip=client_ip, user_id=user_id, is_demo=is_demo, lang=lang)
