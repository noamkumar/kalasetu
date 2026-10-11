import re
from datetime import datetime
from typing import Optional, List, Dict, Any, Tuple
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.session import get_db
from app.models.schemas import AssistantChatRequest, AssistantChatResponse
from app.providers.gemini_client import GeminiClient
from app.services.weather import WeatherService
from app.providers.image_editor_provider import (
    parse_rule_based_voice_command,
    RealImageEditor,
    MockImageEditor,
)
from app.services.kalamitra_knowledge import (
    classify_query,
    get_relevant_context,
    generate_mock_reply,
    INTENT_CREATOR,
    INTENT_ACTION,
    CATEGORY_A,
    CATEGORY_B,
    CATEGORY_C,
    FAQ_APP_SPECIAL,
    FAQ_WHO_MADE,
    FAQ_ECOMMERCE_DIFF,
)

router = APIRouter(prefix="/assistant", tags=["Assistant"])
settings = get_settings()

LANGUAGE_NAMES = {
    "en": "English",
    "hi": "हिन्दी (Hindi)",
    "ta": "தமிழ் (Tamil)",
    "te": "తెలుగు (Telugu)",
    "kn": "ಕನ್ನಡ (Kannada)",
    "ml": "മലയാളം (Malayalam)",
}

SCREEN_EXPLANATIONS = {
    "en": {
        "home": "This is your home catalogue. Here you can see all your handcrafted products, search them, and filter by craft category.",
        "catalogue": "This is your catalogue where all your listed crafts are displayed. Tap any item to inspect details or tap + to add a craft.",
        "orders": "This is your Orders screen. Here you can track incoming customer orders and update their status from New to Packed, Shipped, or Delivered.",
        "studio": "This is the AI Image Studio. Capture or upload a craft photo, and AI will clean up the background and enhance lighting.",
        "pricing": "This is the Fair Pricing Assistant. It calculates your minimum cost floor to protect your wages, and suggests attractive market prices.",
        "profile": "This is your artisan profile and settings screen. You can change your language, check verified status, or configure developer options.",
    },
    "hi": {
        "home": "यह आपका मुख्य कैटलॉग है। यहाँ आप अपने सभी हस्तशिल्प उत्पाद देख सकते हैं, खोज सकते हैं और श्रेणी अनुसार फ़िल्टर कर सकते हैं।",
        "catalogue": "यह आपका कैटलॉग है जहाँ आपके शिल्प उत्पाद प्रदर्शित होते हैं। विवरण देखने के लिए किसी उत्पाद पर टैप करें।",
        "orders": "यह आपका ऑर्डर स्क्रीन है। यहाँ आप ग्राहकों के ऑर्डर देख सकते हैं और स्थिति को नया, पैक, भेजा गया या डिलीवर में बदल सकते हैं।",
        "studio": "यह एआई इमेज स्टूडियो है। अपने शिल्प की तस्वीर लें और एआई वर्कशॉप का बैकग्राउंड हटाकर लाइटिंग संतुलित करेगा।",
        "pricing": "यह उचित मूल्य सहायक है। यह आपकी मजदूरी और सामग्री लागत की सुरक्षा हेतु न्यूनतम मूल्य और बाजार दर सुझाता है।",
        "profile": "यह आपका प्रोफाइल और सेटिंग्स स्क्रीन है। यहाँ से आप भाषा बदल सकते हैं या सेटिंग्स प्रबंधित कर सकते हैं।",
    },
    "ta": {
        "home": "இது உங்கள் பிரதான பட்டியல். உங்கள் கைவினைப் பொருட்கள் அனைத்தையும் இங்கே காணலாம் மற்றும் வகையின்படி வடிகட்டலாம்.",
        "catalogue": "இது உங்கள் தயாரிப்பு பட்டியல். விவரங்களைக் காண ஏதேனும் ஒரு கைவினைப் பொருளைத் தொடவும்.",
        "orders": "இது உங்கள் ஆர்டர்கள் திரை. வாடிக்கையாளர் ஆர்டர்களைக் கண்காணிக்கவும், நிலையைப் புதுப்பிக்கவும் இங்கே முடியும்.",
        "studio": "இது AI பட ஸ்டுடியோ. உங்கள் கைவினைப் பொருளைப் புகைப்படம் எடுத்துப் பின்னணியை நீக்கி ஒளியை மேம்படுத்தலாம்.",
        "pricing": "இது நியாயமான விலை உதவியாளர். உங்கள் உழைப்புக்கான குறைந்தபட்ச விலையை இது பாதுகாக்கிறது.",
        "profile": "இது உங்கள் சுயவிவரம் மற்றும் அமைப்புகள் திரை. மொழியை மாற்றவும் அமைப்புகளை நிர்வகிக்கவும் இங்கே முடியும்.",
    },
    "te": {
        "home": "ఇది మీ ప్రధాన కేటలాగ్. ఇక్కడ మీ హస్తకళల ఉత్పత్తులన్నింటినీ చూడవచ్చు మరియు శోధించవచ్చు.",
        "catalogue": "ఇది మీ కేటలాగ్ తెర. వివరాలను చూడటానికి ఏదైనా ఉత్పత్తిపై నొక్కండి.",
        "orders": "ఇది మీ ఆర్డర్ల తెర. కొత్త ఆర్డర్లను చూడటానికి మరియు స్థితిని మార్చడానికి ఇక్కడ వీలవుతుంది.",
        "studio": "ఇది AI ఇమేజ్ స్టూడియో. క్రాఫ్ట్ ఫోటో తీసి లైటింగ్ మరియు బ్యాక్‌గ్రౌండ్ మెరుగుపరచండి.",
        "pricing": "ఇది న్యాయమైన ధరల సహాయకుడు. మీ శ్రమ విలువను కాపాడే కనీస ధరను లెక్కిస్తుంది.",
        "profile": "ఇది మీ ప్రొఫైల్ మరియు సెట్టింగ్‌ల స్క్రీన్. ఇక్కడ మీరు భాషను మార్చవచ్చు.",
    },
    "kn": {
        "home": "ಇದು ನಿಮ್ಮ ಮುಖ್ಯ ಕ್ಯಾಟಲಾಗ್. ನಿಮ್ಮ ಎಲ್ಲಾ ಕರಕುಶಲ ಉತ್ಪನ್ನಗಳನ್ನು ಇಲ್ಲಿ ವೀಕ್ಷಿಸಬಹುದು.",
        "catalogue": "ಇದು ನಿಮ್ಮ ಕರಕುಶಲ ಕ್ಯಾಟಲಾಗ್. ವಿವರಗಳನ್ನು ನೋಡಲು ಯಾವುದೇ ಉತ್ಪನ್ನವನ್ನು ಟ್ಯಾಪ್ ಮಾಡಿ.",
        "orders": "ಇದು ನಿಮ್ಮ ಆರ್ಡರ್‌ಗಳ ಸ್ಕ್ರೀನ್. ಗ್ರಾಹಕರ ಹೊಸ ಆರ್ಡರ್‌ಗಳನ್ನು ಇಲ್ಲಿ ನಿರ್ವಹಿಸಬಹುದು.",
        "studio": "ಇದು AI ಇಮೇಜ್ ಸ್ಟುಡಿಯೋ. ಕ್ರಾಫ್ಟ್ ಫೋಟೋ ತೆಗೆದು ಹಿನ್ನೆಲೆ ಸ್ವಚ್ಛಗೊಳಿಸಿ ಲೈಟಿಂಗ್ ಸರಿಪಡಿಸಿ.",
        "pricing": "ಇದು ನ್ಯಾಯಯುತ ಬೆಲೆ ಸಹಾಯಕ. ನಿಮ್ಮ ಕನಿಷ್ಠ ವೆಚ್ಚ ಮತ್ತು ಮಾರುಕಟ್ಟೆ ಬೆಲೆಯನ್ನು ಸೂಚಿಸುತ್ತದೆ.",
        "profile": "ಇದು ನಿಮ್ಮ ಪ್ರೊಫೈಲ್ ಮತ್ತು ಸೆಟ್ಟಿಂಗ್ಸ್ ಸ್ಕ್ರೀನ್. ಭಾಷೆ ಬದಲಾಯಿಸಲು ಇಲ್ಲಿ ಸಾಧ್ಯ.",
    },
    "ml": {
        "home": "ഇത് നിങ്ങളുടെ പ്രധാന കാറ്റലോഗ് ആണ്. നിങ്ങളുടെ കരകൗശല ഉൽപ്പന്നങ്ങൾ ഇവിടെ കാണാം.",
        "catalogue": "ഇത് നിങ്ങളുടെ ഉൽപ്പന്ന കാറ്റലോഗ് ആണ്. വിശദാംശങ്ങൾക്ക് ഏതെങ്കിലും ഉൽപ്പന്നത്തിൽ തൊടുക.",
        "orders": "ഇത് നിങ്ങളുടെ ഓർഡറുകൾ ആണ്. ഉപഭോക്താക്കളുടെ ഓർഡറുകൾ ഇവിടെ ട്രാക്ക് ചെയ്യാം.",
        "studio": "ഇത് AI ഇമേജ് സ്റ്റുഡിയോ ആണ്. ഫോട്ടോ എടുത്ത് പശ്ചാത്തലം മാറ്റാനും മിനുക്കാനും സഹായിക്കുന്നു.",
        "pricing": "ഇത് ന്യായവില സഹായിയാണ്. നിങ്ങളുടെ അധ്വാനത്തിന്റെ കുറഞ്ഞ നിരക്ക് സംരക്ഷിക്കുന്നു.",
        "profile": "ഇത് നിങ്ങളുടെ പ്രൊഫൈലും ക്രമീകരണങ്ങളും ആണ്. ഭാഷ മാറ്റാൻ ഇവിടെ സാധിക്കും.",
    },
}


def _check_faq(message: str, lang: str) -> Optional[AssistantChatResponse]:
    text_lower = message.lower().strip()
    norm_lang = lang if lang in LANGUAGE_NAMES else "en"

    # 1. Creator identity check: who made / invented / created you or this app
    creator_keywords = [
        "who made", "who created", "who invented", "creator", "maker", "inventor", "built you",
        "developed you", "who developed", "developed this", "developer", "who designed", "made you", "created you", "invented you",
        "made this app", "created this app", "invented this app", "noam",
        "किसने बनाया", "कौन बनाया", "निर्माता कौन", "किसने आविष्कार", "बनाने वाला",
        "யார் உருவாக்கியது", "யார் படைத்தது", "யார் கண்டுபிடித்தது", "உருவாக்கியவர் யார்",
        "ఎవరు తయారు చేశారు", "ఎవరు సృష్టించారు", "ఎవరు కనిపెట్టారు", "సృష్టికర్త ఎవరు",
        "ಯಾರು ಮಾಡಿದ್ದು", "ಯಾರು ಸೃಷ್ಟಿಸಿದರು", "ಯಾರು ರಚಿಸಿದರು", "ಯಾರು ಕಂಡುಹಿಡಿದರು",
        "ആരാണ് ഉണ്ടാക്കിയത്", "ആരാണ് സൃഷ്ടിച്ചത്", "ആരാണ് നിർമ്മിച്ചത്",
    ]
    if any(k in text_lower for k in creator_keywords):
        return AssistantChatResponse(
            reply=FAQ_WHO_MADE.get(norm_lang, FAQ_WHO_MADE["en"]),
            action="none",
            suggestions=["What is special about this app?", "Add Product", "Check Orders"],
        )

    # 2. Ecommerce difference (Amazon / Flipkart)
    ecommerce_keywords = [
        "different from amazon", "different from flipkart", "why not amazon", "why not flipkart",
        "how are you different from amazon", "how different from amazon", "instead of amazon",
        "amazon", "flipkart",
        "अमेज़न से कैसे अलग", "அமேசானிலிருந்து எவ்வாறு வேறுபடுகிறது", "అమెజాన్ నుండి ఎలా భిన్నమైనది",
        "ಅಮೆಜಾನ್‌ಗಿಂತ ಹೇಗೆ ಭಿನ್ನ", "ആമസോണിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തമാണ്",
    ]
    if any(k in text_lower for k in ecommerce_keywords):
        return AssistantChatResponse(
            reply=FAQ_ECOMMERCE_DIFF.get(norm_lang, FAQ_ECOMMERCE_DIFF["en"]),
            action="none",
            suggestions=["What is special about KalaSetu?", "Take craft photo", "Check fair pricing"],
        )

    # 3. What is special about this app / how it helps
    special_keywords = [
        "what is special", "special about", "why this app", "why artisan ai", "what makes this app special",
        "how does this app help", "what does this app do", "special feature", "why should i use",
        "why kalasetu", "what is kalasetu", "about this app",
        "क्या खास है", "क्या खासियत", "यह ऐप क्या करता है", "विशेषता क्या", "क्यों इस्तेमाल", "खास", "खासियत",
        "என்ன சிறப்பு", "சிறப்பம்சம்", "இந்த ஆப் என்ன செய்கிறது", "எப்படி உதவுகிறது",
        "ఈ యాప్‌లో ప్రత్యేకత ఏమిటి", "ఏమిటి ప్రత్యేకత", "ప్రత్యేకతలు", "ప్రత్యేకత", "ఈ యాప్ ఏమి చేస్తుంది", "ఎలా సహాయపడుతుంది",
        "ಏನು ವಿಶೇಷ", "ವಿಶೇಷತೆ ಏನು", "ಈ ಆ್ಯಪ್ ಏನು ಮಾಡುತ್ತದೆ",
        "എന്താണ് പ്രത്യേകത", "പ്രത്യേകത എന്താണ്", "ഈ ആപ്പ് എന്താണ് ചെയ്യുന്നത്",
    ]
    if any(k in text_lower for k in special_keywords):
        return AssistantChatResponse(
            reply=FAQ_APP_SPECIAL.get(norm_lang, FAQ_APP_SPECIAL["en"]),
            action="none",
            suggestions=["Take craft photo", "Check fair pricing", "Who created you?"],
        )

    return None


def _rule_based_fallback(
    message: str,
    current_screen: str,
    lang: str,
    history: Optional[List[Dict[str, Any]]] = None,
) -> AssistantChatResponse:
    norm_lang = lang if lang in LANGUAGE_NAMES else "en"

    # 1. Check FAQ match for standardized core questions
    faq_match = _check_faq(message, norm_lang)
    if faq_match:
        return faq_match

    category = classify_query(message, history)

    # 1. Creator identity check
    if category == INTENT_CREATOR:
        return AssistantChatResponse(
            reply=FAQ_WHO_MADE.get(norm_lang, FAQ_WHO_MADE["en"]),
            action="none",
            suggestions=["What is special about KalaSetu?", "Add Product", "Check Orders"],
        )

    # 2. If not an action intent, route directly to knowledge / general mock generator
    if category != INTENT_ACTION:
        return generate_mock_reply(message, category, norm_lang, current_screen)

    text_lower = message.lower().strip()

    # Intent 1: Add product
    add_keywords = [
        "add product", "new product", "create product", "list product", "photo", "studio", "camera", "upload",
        "add a", "add new", "add craft", "new craft", "new item", "sell item", "list craft",
        "नया उत्पाद", "उत्पाद जोड़ें", "जोड़ें", "फोटो", "फोटो खींचो",
        "புதிய தயாரிப்பு", "சேர்க்க", "படம்",
        "కొత్త ఉత్పత్తి", "జోడించు", "ఫోటో",
        "ಹೊಸ ಉತ್ಪನ್ನ", "ಫೋಟೋ",
        "ಪುതിയ ഉൽപ്പന്നം", "ഫോട്ടോ"
    ]
    if any(k in text_lower for k in add_keywords):
        replies = {
            "en": "Opening the AI Image Studio so you can capture and list your craft!",
            "hi": "एआई इमेज स्टूडियो खोला जा रहा है ताकि आप अपने शिल्प की फोटो ले सकें!",
            "ta": "AI இமேஜ் ஸ்டுடியோ திறக்கப்படுகிறது, உங்கள் தயாரிப்பைச் சேர்க்கலாம்!",
            "te": "మీ హస్తకళను జోడించడానికి AI இமேஜ் ஸ்டுడియో తెరవబడుతోంది!",
            "kn": "ನಿಮ್ಮ ಕರಕುಶಲ ಉತ್ಪನ್ನವನ್ನು ಸೇರಿಸಲು AI ಇಮೇಜ್ ಸ್ಟುಡಿಯೋ ತೆರೆಯಲಾಗುತ್ತಿದೆ!",
            "ml": "നിങ്ങളുടെ കരകൗശലം ചേർക്കാൻ AI ഇമേജ് സ്റ്റുഡിയോ തുറക്കുന്നു!",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/studio",
            suggestions=["Take craft photo", "Check fair pricing", "Explain this screen"],
        )

    # Intent 2: Show pending orders
    order_keywords = [
        "order", "orders", "pending", "sales", "buyer", "customer", "deliver", "ship",
        "ऑर्डर", "बिक्री", "पेंडिंग", "ग्राहक",
        "ஆர்டர்", "ஆர்டர்கள்", "விற்பனை",
        "ఆర్డర్", "ఆర్డర్లు", "అమ్మకాలు",
        "ಆರ್ಡರ್", "ಆರ್ಡರ್‌ಗಳು",
        "ഓർഡർ", "ഓർഡറുകൾ"
    ]
    if any(k in text_lower for k in order_keywords):
        replies = {
            "en": "Opening your Orders screen to view new and pending customer orders.",
            "hi": "ग्राहकों के नए और लंबित ऑर्डर देखने के लिए ऑर्डर स्क्रीन खोली जा रही है।",
            "ta": "புதிய மற்றும் நிலுவையில் உள்ள ஆர்டர்களைக் காண ஆர்டர்கள் திரை திறக்கப்படுகிறது.",
            "te": "కొత్త ఆర్డర్‌లను వీక్షించడానికి ఆర్డర్‌ల స్క్రీన్‌ను తెరుస్తున్నాము.",
            "kn": "ಬಾಕಿ ಇರುವ ಆರ್ಡರ್‌ಗಳನ್ನು ನೋಡಲು ಆರ್ಡರ್ ಸ್ಕ್ರೀನ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "ഉപഭോക്താക്കളുടെ പുതിയ ഓർഡറുകൾ കാണാൻ ഓർഡർ സ്ക്രീൻ തുറക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/orders?filter=new",
            suggestions=["Mark as Packed", "View All Orders", "Back to Home"],
        )

    # Intent 3: Change language
    lang_patterns = [
        ("hi", ["hindi", "हिन्दी", "हिंदी", "hindi me"]),
        ("ta", ["tamil", "தமிழ்", "tamilil"]),
        ("te", ["telugu", "తెలుగు"]),
        ("kn", ["kannada", "ಕನ್ನಡ"]),
        ("ml", ["malayalam", "മലയാളം"]),
        ("en", ["english", "अंग्रेजी", "ஆங்கிலம்"]),
    ]
    if "language" in text_lower or "भाषा" in text_lower or "மொழி" in text_lower or "ಭಾಷೆ" in text_lower:
        for code, patterns in lang_patterns:
            if any(p in text_lower for p in patterns):
                replies = {
                    "en": f"Switching app language to {LANGUAGE_NAMES.get(code, code)}.",
                    "hi": f"ऐप की भाषा {LANGUAGE_NAMES.get(code, code)} में बदली जा रही है।",
                    "ta": f"பயன்பாட்டின் மொழி {LANGUAGE_NAMES.get(code, code)}க்கு மாற்றப்படுகிறது.",
                    "te": f"యాప్ భాష {LANGUAGE_NAMES.get(code, code)}కి మార్చబడుతోంది.",
                    "kn": f"ಆ್ಯಪ್ ಭಾಷೆಯನ್ನು {LANGUAGE_NAMES.get(code, code)}ಗೆ ಬದಲಾಯಿಸಲಾಗುತ್ತಿದೆ.",
                    "ml": f"ആപ്പ് ഭാഷ {LANGUAGE_NAMES.get(code, code)}ലേക്ക് മാറ്റുന്നു.",
                }
                return AssistantChatResponse(
                    reply=replies.get(norm_lang, replies["en"]),
                    action="change_language",
                    target_lang=code,
                    suggestions=["Add Product", "Pending Orders", "Explain Screen"],
                )

    # Intent 4: Explain screen
    explain_keywords = [
        "explain", "what is this", "help", "where am i", "guide", "how does this work",
        "समझाओ", "यह क्या है", "मदद", "यह पेज",
        "விளக்கு", "இது என்ன", "உதவி",
        "వివరించు", "ఇది ఏమిటి", "సహాయం",
        "ವಿವರಿಸಿ", "ಇದು ಏನು", "ಸಹಾಯ",
        "വിശദീകരിക്കുക", "ഇതെന്താണ്", "സഹായം"
    ]
    if any(k in text_lower for k in explain_keywords):
        screen_key = current_screen.lower().strip()
        screen_dict = SCREEN_EXPLANATIONS.get(norm_lang, SCREEN_EXPLANATIONS["en"])
        explanation = screen_dict.get(screen_key, screen_dict.get("home", ""))
        return AssistantChatResponse(
            reply=explanation,
            action="explain",
            suggestions=["Add Product", "Pending Orders", "Change Language"],
        )

    # Intent 5: My Earnings / Income
    earnings_keywords = [
        "earnings", "my earning", "my earnings", "income", "how much did i make", "revenue", "money earned",
        "कमाई", "मेरी कमाई", "आय", "कितना कमाया",
        "வருமானம்", "என் வருமானம்", "ஈட்டிய பணம்",
        "ఆదాయం", "నా సంపాదన",
        "ಗಳಿಕೆ", "ಆದಾಯ",
        "വരുമാനം", "എന്റെ വരുമാനം"
    ]
    if any(k in text_lower for k in earnings_keywords):
        replies = {
            "en": "Opening your Earnings screen to check this month's income and completed orders.",
            "hi": "आपकी कमाई स्क्रीन खोली जा रही है ताकि आप इस महीने की आय देख सकें।",
            "ta": "உங்கள் வருமானத் திரை திறக்கப்படுகிறது.",
            "te": "మీ ఆదాయం స్క్రీన్ తెరవబడుతోంది.",
            "kn": "ನಿಮ್ಮ ಗಳಿಕೆ ಸ್ಕ್ರೀನ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "നിങ്ങളുടെ വരുമാന സ്ക്രീൻ തുറക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/earnings",
            suggestions=["Check Orders", "Add Product", "Fair Price"],
        )

    # Intent 6: Fair Price / Pricing
    pricing_keywords = [
        "my price", "fair price", "pricing", "cost floor", "suggest price", "price check",
        "कीमत", "उचित मूल्य", "दाम", "भाव",
        "விலை", "நியாயமான விலை",
        "ధర", "సమంజసమైన ధర",
        "ಬೆಲೆ", "ನ್ಯಾಯಯುತ ಬೆಲೆ",
        "വില", "ന്യായവില"
    ]
    if any(k in text_lower for k in pricing_keywords):
        replies = {
            "en": "Opening the Fair Pricing Assistant to calculate competitive prices that protect your wages.",
            "hi": "उचित मूल्य सहायक खोला जा रहा है ताकि आपकी मजदूरी सुरक्षित रहे।",
            "ta": "நியாயமான விலை உதவியாளர் திறக்கப்படுகிறது.",
            "te": "సమంజసమైన ధర సహాయకుడు తెరవబడుతోంది.",
            "kn": "ನ್ಯಾಯಯುತ ಬೆಲೆ ಸಹಾಯಕ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "ന്യായവില സഹായി തുറക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/pricing",
            suggestions=["Add Product", "Check Earnings", "My Orders"],
        )

    # Intent 7: Business / Bulk Orders
    biz_keywords = [
        "business order", "business orders", "bulk order", "bulk orders", "wholesale", "b2b",
        "व्यापारिक ऑर्डर", "थोक ऑर्डर", "बल्क",
        "மொத்த ஆர்டர்", "வணிக ஆர்டர்",
        "బల్క్ ఆర్డర్లు", "వ్యాపార ఆర్డర్లు",
        "ಸಗಟು ಆರ್ಡರ್",
        "ബൾക്ക് ഓർഡർ"
    ]
    if any(k in text_lower for k in biz_keywords):
        replies = {
            "en": "Opening your Business Orders inbox for bulk buyer inquiries.",
            "hi": "थोक खरीदारों के व्यापारिक ऑर्डर देखने के लिए इनबॉक्स खोला जा रहा है।",
            "ta": "மொத்த வாங்குபவர்களின் வணிக ஆர்டர்கள் திரை திறக்கப்படுகிறது.",
            "te": "బల్క్ కొనుగోలుదారుల వ్యాపార ఆర్డర్లు తెరవబడుతున్నాయి.",
            "kn": "ಸಗಟು ವ್ಯಾಪಾರ ಆರ್ಡರ್‌ಗಳ ಇನ್‌ಬಾಕ್ಸ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "ബൾക്ക് ഓർഡറുകൾ ഇൻബോക്സ് തുറക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/orders/business",
            suggestions=["Accept Offer", "All Orders", "My Earnings"],
        )

    # Intent 8: Fair / Exhibition Mode
    fair_keywords = [
        "fair mode", "exhibition", "exhibition mode", "mela", "surajkund", "dilli haat", "shilp samagam",
        "मेला", "प्रदर्शनी", "मेला मोड",
        "கண்காட்சி", "மேளா",
        "మేళా", "ఎగ్జిబిషన్",
        "ಮೇಳ", "ಪ್ರದರ್ಶನ",
        "മേള", "പ്രദർശനം"
    ]
    if any(k in text_lower for k in fair_keywords):
        replies = {
            "en": "Activating Fair & Exhibition Mode for quick offline listing and whole shop QR code.",
            "hi": "मेला और प्रदर्शनी मोड खोला जा रहा है ताकि आप तेजी से उत्पाद जोड़ सकें।",
            "ta": "கண்காட்சி பயன்முறை இயக்கப்படுகிறது.",
            "te": "ఎగ్జిబిషన్ మోడ్ ప్రారంభించబడుతోంది.",
            "kn": "ಪ್ರದರ್ಶನ ಮೋಡ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "മേള മോഡ് സജീവമാക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/fair-mode",
            suggestions=["Scan Shop QR", "Fast Add Product", "Back to Shop"],
        )

    # Intent 9: Marketplaces (GeM & ONDC)
    marketplace_keywords = [
        "marketplace", "marketplaces", "gem", "ondc", "government market", "online market",
        "मार्केटप्लेस", "सरकारी बाजार", "ओएनडीसी", "जेम",
        "சந்தை", "அரசு சந்தை",
        "మార్కెట్ ప్లేస్",
        "ಮಾರುಕಟ್ಟೆ",
        "വിപണി"
    ]
    if any(k in text_lower for k in marketplace_keywords):
        replies = {
            "en": "Opening the government and marketplace connection screen.",
            "hi": "सरकारी और ऑनलाइन मार्केटप्लेस कनेक्शन स्क्रीन खोली जा रही है।",
            "ta": "அரசு மற்றும் ஆன்லைன் சந்தை இணைப்பு திரை திறக்கப்படுகிறது.",
            "te": "ప్రభుత్వ మార్కెట్‌ప్లేస్ కనెక్షన్ స్క్రీన్ తెరవబడుతోంది.",
            "kn": "ಸರ್ಕಾರಿ ಮಾರುಕಟ್ಟೆ ಸಂಪರ್ಕ ಸ್ಕ್ರೀನ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.",
            "ml": "മാർക്കറ്റ് പ്ലേസ് കണക്ഷൻ സ്ക്രീൻ തുറക്കുന്നു.",
        }
        return AssistantChatResponse(
            reply=replies.get(norm_lang, replies["en"]),
            action="navigate",
            route="/marketplaces",
            suggestions=["Export for GeM", "Export for ONDC", "Back to Home"],
        )

    # Fallback to knowledge/general mock generator
    return generate_mock_reply(message, category, norm_lang, current_screen)


def _detect_image_edit(message: str, lang: str) -> Tuple[bool, Dict[str, Any]]:
    """Detects whether message is an image editing command."""
    msg_low = message.lower()
    if any(k in msg_low for k in ["add product", "new product", "add a", "new craft", "list product", "नया उत्पाद", "उत्पाद जोड़ें", "புதிய தயாரிப்பு", "కొత్త ఉత్పత్తి"]):
        return False, {}

    parsed = parse_rule_based_voice_command(message, lang=lang)
    if parsed.get("operations") or parsed.get("action") in ["undo", "redo", "reset"]:
        return True, parsed

    edit_phrases = [
        "remove background", "cutout", "make background white", "pure white",
        "wooden table", "wood table", "studio background", "marble background",
        "make it brighter", "more brightness", "enhance photo", "auto enhance",
        "బ్యాక్ గ్రౌండ్", "బ్యాక్‌గ్రౌండ్", "తెల్లగా మార్చు",
        "பின்னணி", "வெள்ளையாக மாற்று",
        "बैकग्राउंड", "सफेद कर दो", "सफ़ेद कर दो",
        "ಹಿನ್ನೆಲೆ", "ಬಿಳಿ ಬಣ್ಣಕ್ಕೆ ಬದಲಾಯಿಸು",
        "പശ്ചാത്തലം", "വെള്ളയാക്കൂ"
    ]
    if any(k in msg_low for k in edit_phrases):
        return True, parsed
    return False, parsed


def _detect_weather_query(message: str) -> Tuple[bool, Optional[str]]:
    """Detects whether message is inquiring about weather/temperature and extracts city if mentioned."""
    msg_low = message.lower()
    weather_keywords = [
        "weather", "temperature", "forecast", "how hot", "how cold", "rain", "barish",
        "mausam", "मौसम", "వాతావరణం", "வானிலை", "ಹವಾಮಾನ", "കാലാവസ്ഥ"
    ]
    if not any(k in msg_low for k in weather_keywords):
        return False, None

    city_match = re.search(r'\b(?:in|at|for|near|of)\s+([a-zA-Z\u0900-\u0D7F]+)', message, re.IGNORECASE)
    extracted_city = city_match.group(1).strip() if city_match else None
    return True, extracted_city


@router.post("/chat", response_model=AssistantChatResponse)
async def assistant_chat(
    req: AssistantChatRequest,
    db: Session = Depends(get_db)
):
    norm_lang = req.language if req.language in LANGUAGE_NAMES else "en"
    screen = req.current_screen or "home"
    history = req.history or []

    # 1. Check FAQ match first (Creator, Amazon / Ecommerce difference, What is special)
    faq_match = _check_faq(req.message, norm_lang)
    if faq_match:
        return faq_match

    category = classify_query(req.message, history)
    if category == INTENT_CREATOR or any(k in req.message.lower() for k in ["who made you", "who created you", "who is your creator", "noam"]):
        return AssistantChatResponse(
            reply="I was created by Noam." if norm_lang == "en" else FAQ_WHO_MADE.get(norm_lang, "I was created by Noam."),
            action="none",
            suggestions=["What is special about KalaSetu?", "Why use KalaSetu instead of Amazon?", "Add Product"],
        )

    # 2. Check Conversational Image Editing
    is_img_edit, parsed_img = _detect_image_edit(req.message, norm_lang)
    if is_img_edit:
        if req.image_id:
            editor = RealImageEditor() if (settings.AI_MODE == "real" and settings.GEMINI_API_KEY) else MockImageEditor()
            edit_res = await editor.edit_image(
                image_id=req.image_id,
                prompt=req.message,
                lang=norm_lang,
            )
            if edit_res.get("status") == "success":
                return AssistantChatResponse(
                    reply=edit_res.get("confirmation", "Changes applied successfully."),
                    action="none",
                    image_id=req.image_id,
                    image_url=edit_res.get("image_url"),
                    can_undo=edit_res.get("can_undo"),
                    can_redo=edit_res.get("can_redo"),
                    suggestions=["Pure White", "Wooden Table", "Make Brighter", "Save Image"],
                )
            elif edit_res.get("clarification_needed"):
                return AssistantChatResponse(
                    reply=edit_res.get("confirmation") or edit_res.get("clarifying_question", "What would you like to change?"),
                    action="none",
                    image_id=req.image_id,
                    suggestions=["White Background", "Wooden Table", "Brighter", "Remove Background"],
                )
            else:
                return AssistantChatResponse(
                    reply=edit_res.get("confirmation", "Could not complete the image edit."),
                    action="none",
                    image_id=req.image_id,
                    suggestions=["White Background", "Wooden Table", "Explain Studio"],
                )
        else:
            select_image_replies = {
                "en": "Please select or capture a craft photo first using the camera or attachment button so I can edit it for you!",
                "hi": "कृपया पहले कैमरा या गैलरी से अपने शिल्प की तस्वीर चुनें, ताकि मैं उसे संपादित कर सकूं!",
                "ta": "தயவுசெய்து முதலில் கேமரா அல்லது கேலரி மூலம் கைவினைப் புகைப்படத்தைத் தேர்ந்தெடுக்கவும், பிறகு நான் அதை மாற்றியமைக்கிறேன்!",
                "te": "దయచేసి మొదట కెమెరా లేదా గ్యాలరీ ద్వారా మీ హస్తకళ ఫోటోను ఎంచుకోండి, అప్పుడు నేను దానిని ఎడిట్ చేయగలను!",
                "kn": "ದಯವಿಟ್ಟು ಮೊದಲು ಕ್ಯಾಮೆರಾ ಅಥವಾ ಗ್ಯಾಲರಿಯಿಂದ ಕರಕುಶಲ ಫೋಟೋವನ್ನು ಆಯ್ಕೆಮಾಡಿ, ನಂತರ ನಾನು ಅದನ್ನು ಎಡಿಟ್ ಮಾಡುತ್ತೇನೆ!",
                "ml": "ദയവായി ആദ്യം ക്യാമറ അല്ലെങ്കിൽ ഗാലറി വഴി ഒരു ക്രാഫ്റ്റ് ഫോട്ടോ തിരഞ്ഞെടുക്കുക, അപ്പോൾ എനിക്ക് അത് എഡിറ്റ് ചെയ്യാം!",
            }
            return AssistantChatResponse(
                reply=select_image_replies.get(norm_lang, select_image_replies["en"]),
                action="navigate",
                route="/studio",
                suggestions=["Take craft photo", "Upload photo", "What can you do with photos?"],
            )

    # 3. Check Live Weather Query
    is_weather, city_name = _detect_weather_query(req.message)
    weather_fact_block = ""
    weather_data = None
    if is_weather and settings.AI_MODE == "real":
        target_city = city_name or "Hyderabad"
        weather_data = await WeatherService.get_weather_for_location(city_name=target_city)
        if weather_data and weather_data.get("status") == "success":
            weather_fact_block = (
                f"\nVERIFIED LIVE WEATHER OBSERVATION (Real sensor data):\n"
                f"- City: {weather_data['city']}\n"
                f"- Temperature: {weather_data['temperature_c']}°C (Feels like: {weather_data['feels_like_c']}°C)\n"
                f"- Weather Condition: {weather_data['condition']}\n"
                f"- Relative Humidity: {weather_data['humidity_pct']}%\n"
                f"- Wind Speed: {weather_data['wind_kmh']} km/h\n"
            )
        else:
            weather_fact_block = f"\nLIVE WEATHER STATUS: Live weather data is currently unavailable for {target_city}.\n"

    # 4. If AI mode is real and Gemini client is configured, call Gemini
    if settings.AI_MODE == "real":
        client = GeminiClient()
        if client.is_configured:
            history_lines = []
            if history:
                for h in history[-6:]:
                    role_tag = "User" if h.get("role") == "user" else "KalaMitra"
                    history_lines.append(f"{role_tag}: {h.get('content', '')}")
            history_str = "\n".join(history_lines) if history_lines else "(No prior conversation)"

            current_dt_str = datetime.now().strftime("%A, %d %B %Y, %I:%M %p")
            relevant_context = get_relevant_context(category, req.message)
            context_block = f"\nRELEVANT KNOWLEDGE CONTEXT:\n{relevant_context}\n" if relevant_context else ""

            prompt = f"""You are KalaMitra (कलामित्र), a warm, supportive, and intelligent conversational assistant for traditional Indian artisans and KalaSetu users.
You are a GENERAL-PURPOSE conversational assistant with deep, authentic knowledge about KalaSetu.

USER MESSAGE: "{req.message}"
CURRENT APP SCREEN: {screen}
USER APP LANGUAGE: {norm_lang}
CURRENT LOCAL DATE & TIME: {current_dt_str}
DETECTED INTENT/CATEGORY: {category}

RECENT CONVERSATION HISTORY:
{history_str}
{context_block}
{weather_fact_block}
BEHAVIOR RULES (Strict):
1. QUESTION CATEGORIES:
   - CATEGORY A (KalaSetu / Project questions, e.g. features, pricing, why use KalaSetu vs Amazon, photo studio, how it helps, what problem it solves):
     Use the provided project context naturally. Do NOT copy-paste the whole text. For simple questions, give 2-4 sentences. For detailed comparisons (e.g. why choose KalaSetu over Amazon/e-commerce), give a clear structured explanation: normal e-commerce platforms are marketplaces assuming technical skills, while KalaSetu is an AI virtual business manager assisting artisans before and during digital selling (AI photo enhancement, regional voice cataloging, cost-floor pricing). Never attack or insult other platforms. Never claim unverified features.
   - CATEGORY B (General questions, e.g. Python, machine learning, capital of India, jokes, math, technology):
     Answer normally, accurately, and helpfully using your general knowledge. Do NOT force KalaSetu or artisan context into general questions.
   - CATEGORY C (Current / Live information, e.g. today's weather, temperature, date/time):
     If verified live weather data is provided above, explain the temperature, condition, and city clearly and warmly in {norm_lang}. If it says unavailable, clearly state that live weather data is currently unavailable. Never invent current weather.
   - CREATOR QUESTION: If asked who created or made you, reply exactly: "I was created by Noam."

2. CONVERSATION CONTEXT & FOLLOW-UPS:
   - If the user uses pronouns like "it", "this", or asks follow-up questions, use the conversation history to understand what they are referring to. Do not answer every message in isolation.

3. APP ACTION INTENTS:
   - If the user wants to list/photograph/add a product or craft: "action": "navigate", "route": "/studio"
   - If the user wants to see pending orders or sales: "action": "navigate", "route": "/orders?filter=new"
   - If the user wants to change/switch app language: "action": "change_language", "target_lang": detected code (en, hi, ta, te, kn, ml)
   - If the user asks to explain the current screen: "action": "explain", "route": null
   - Otherwise: "action": "none"

4. RESPONSE STYLE:
   - Warm, respectful, clear, and easy to understand.
   - Speak in the user's requested language ({norm_lang}).
   - Never output markdown code fences in the reply string.

Return strictly valid JSON:
{{
  "reply": "<warm, helpful response in {norm_lang} script>",
  "action": "navigate" | "change_language" | "explain" | "none",
  "route": "/studio" | "/orders?filter=new" | null,
  "target_lang": "en" | "hi" | "ta" | "te" | "kn" | "ml" | null,
  "suggestions": ["<short follow-up 1>", "<short follow-up 2>", "<short follow-up 3>"]
}}"""
            try:
                result = await client.generate_json(prompt, system_instruction="You are KalaMitra, the helpful artisan AI.")
                if isinstance(result, dict) and "reply" in result:
                    return AssistantChatResponse(
                        reply=str(result["reply"]),
                        action=str(result.get("action", "none")),
                        route=result.get("route"),
                        target_lang=result.get("target_lang"),
                        suggestions=result.get("suggestions", ["Add Product", "Pending Orders", "Explain Screen"]),
                    )
            except Exception:
                pass

    # 5. Rule-based / Mock fallback
    if is_weather:
        if weather_data and weather_data.get("status") == "success":
            weather_replies = {
                "en": f"Today in {weather_data['city']}, the weather is {weather_data['condition']} with a temperature of {weather_data['temperature_c']}°C (feels like {weather_data['feels_like_c']}°C) and humidity of {weather_data['humidity_pct']}%.",
                "hi": f"आज {weather_data['city']} में मौसम {weather_data['condition']} है और तापमान {weather_data['temperature_c']}°C है।",
                "te": f"ఈరోజు {weather_data['city']}లో వాతావరణం {weather_data['condition']}తో {weather_data['temperature_c']}°C ఉష్ణోగ్రతగా ఉంది.",
                "ta": f"இன்று {weather_data['city']} இல் வானிலை {weather_data['condition']} ஆகவும் வெப்பநிலை {weather_data['temperature_c']}°C ஆகவும் உள்ளது.",
                "kn": f"ಇಂದು {weather_data['city']}ನಲ್ಲಿ ಹವಾಮಾನ {weather_data['condition']} ಆಗಿದ್ದು, ತಾಪಮಾನ {weather_data['temperature_c']}°C ಇದೆ.",
                "ml": f"ഇന്ന് {weather_data['city']}ൽ കാലാവസ്ഥ {weather_data['condition']} ആണ്, താപനില {weather_data['temperature_c']}°C ആണ്.",
            }
            return AssistantChatResponse(
                reply=weather_replies.get(norm_lang, weather_replies["en"]),
                action="none",
                suggestions=["Check Orders", "Add Product", "Explain Screen"],
            )
        else:
            unavailable_replies = {
                "en": "Currently live weather data is unavailable.",
                "hi": "वर्तमान में लाइव मौसम डेटा उपलब्ध नहीं है।",
                "te": "ప్రస్తుతం ప్రత్యక్ష వాతావరణ సమాచారం అందుబాటులో లేదు.",
                "ta": "தற்போது நேரலை வானிலை தகவல் கிடைக்கவில்லை.",
                "kn": "ಪ್ರಸ್ತುತ ಲೈವ್ ಹವಾಮಾನ ಮಾಹಿತಿ ಲಭ್ಯವಿಲ್ಲ.",
                "ml": "നിലവിൽ തത്സമയ കാലാവസ്ഥാ വിവരങ്ങൾ ലഭ്യമല്ല.",
            }
            return AssistantChatResponse(
                reply=unavailable_replies.get(norm_lang, unavailable_replies["en"]),
                action="none",
                suggestions=["Check Orders", "Add Product", "Explain Screen"],
            )

    return _rule_based_fallback(req.message, screen, norm_lang, history)
