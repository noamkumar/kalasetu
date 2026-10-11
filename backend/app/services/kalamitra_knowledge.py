"""KalaSetu Knowledge Base & KalaMitra Context Routing Engine.

Provides centralized official project knowledge, query category classification
(Category A: KalaSetu, Category B: General, Category C: Live Info, Creator, Action),
and context injection for Gemini & Mock providers.
"""

import re
from typing import Optional, List, Dict, Any
from app.models.schemas import AssistantChatResponse

# ==============================================================================
# OFFICIAL KALASETU PROJECT KNOWLEDGE BASE
# ==============================================================================

KALASETU_PROJECT_CONTEXT = """
BACKGROUND:
KalaSetu actively supports the socio-economic upliftment of marginalized communities, particularly micro-entrepreneurs, artisans, and weavers. Financial assistance is provided to establish small-scale manufacturing and handicraft units. To help these beneficiaries sell their goods, market exposure is facilitated through periodic physical exhibitions, cluster development programs, and trade fairs such as Shilp Samagam, Surajkund Mela, and Dilli Haat.
However, physical exhibitions provide only temporary boosts in sales. Many micro-entrepreneurs still lack continuous, year-round access to broader digital markets. Moving into the digital economy is difficult because of:
- Low digital literacy
- Language barriers
- Lack of technical skills
- Difficulty taking professional product photographs
- Difficulty creating professional product catalogs
- Difficulty understanding market pricing
- Difficulty writing effective product descriptions

THE CHALLENGE:
There is a critical need to bridge the gap between traditional craftsmanship and modern digital commerce. Artisans often struggle to present their products competitively online. Common problems include poor-quality product photographs, difficulty writing compelling product descriptions, creating professional catalogs, dynamic market pricing, technical barriers, and language constraints.
KalaSetu is designed as an AI-driven mobile application that acts as a "virtual business manager" for artisans and micro-entrepreneurs. It helps users:
- Digitize inventory without technical skills
- Improve product presentation
- Create professional listings
- Understand pricing and protect wages
- Communicate in regional languages
- Connect with broader digital markets year-round

EXPECTED SOLUTION:
KalaSetu is an AI-powered cross-platform mobile application supported by a robust backend architecture. The UI/UX is minimalist, intuitive, responsive, accessible, and suitable for users with low digital literacy.

KEY FEATURE 1 — AI IMAGE ENHANCER & STUDIO:
The artisan photographs a product (textiles, pottery, handicrafts, woodwork). KalaSetu helps remove cluttered backgrounds, improve lighting, enhance product presentation, and format images for professional e-commerce use without professional studio equipment.

KEY FEATURE 2 — MULTILINGUAL AUTO-CATALOGER:
Artisans can describe products using natural voice in their regional language (English, Hindi, Tamil, Telugu, Kannada, Malayalam). AI understands the spoken description, translates it, generates professional SEO-friendly product descriptions, and structures the catalog information in English and Hindi.
Workflow: ARTISAN SPEAKS NATURALLY -> AI UNDERSTANDS -> PROFESSIONAL LISTING IS CREATED.

KEY FEATURE 3 — DYNAMIC PRICING ASSISTANT:
An AI/ML-assisted pricing workflow considers raw material costs, labor hours, artisan wages, and market benchmarks.
PRINCIPLE: A fair suggested price must respect the artisan's costs and NEVER encourage selling below the basic cost of production (Cost Floor). Protects artisan wages.

IMPACT GOALS:
1. Continuous, year-round digital sales channel (reducing dependence on periodic fairs like Shilp Samagam, Surajkund, Dilli Haat).
2. Lower the barrier to entering digital commerce.
3. Automate photography cleanup, multilingual cataloging, and fair pricing.
4. Support financial independence and digital literacy for traditional craft communities.

HONESTY & BOUNDARIES:
- Distinguish between implemented features and intended goals.
- Never claim unverified marketplace integrations (e.g. do not say connected directly to Amazon or ONDC unless verified).
- Never invent buyer numbers, sales statistics, or government partnerships.
- Never invent live market prices, live weather data, or real-time news.
"""

CATEGORY_A = "category_a"  # KalaSetu / Project questions
CATEGORY_B = "category_b"  # General questions (Python, ML, jokes, math, etc.)
CATEGORY_C = "category_c"  # Current / Live information (weather, news, real-time prices)
INTENT_CREATOR = "creator"  # "Who created you?" -> "I was created by Noam."
INTENT_ACTION = "action"   # Navigation/Language intents (add product, orders, change language, explain)

FAQ_APP_SPECIAL = {
    "en": "Artisan AI lets artisans sell by simply taking a photo and speaking in their own language; it cleans the photo, writes the listing in six languages, suggests a fair price that never goes below their cost, and helps them get orders and track them.",
    "hi": "आर्टिसन एआई (Artisan AI) कारीगरों को केवल एक फोटो लेकर और अपनी मातृभाषा में बोलकर उत्पाद बेचने की सुविधा देता है; यह फोटो को साफ करता है, छह भाषाओं में लिस्टिंग लिखता है, उचित मूल्य सुझाता है जो कभी आपकी लागत से कम नहीं होता, और नए ऑर्डर प्राप्त कर उन्हें ट्रैक करने में मदद करता है।",
    "ta": "ஆர்ட்டிசன் AI (Artisan AI) கைவினைஞர்கள் ஒரு புகைப்படம் எடுத்துத் தங்கள் தாய்மொழியில் பேசுவதன் மூலமே விற்பனை செய்ய உதவுகிறது; இது புகைப்படத்தைச் சரிசெய்கிறது, ஆறு மொழிகளில் பட்டியலை உருவாக்குகிறது, அடக்க விலையை விடக் குறையாத நியாயமான விலையைப் பரிந்துரைக்கிறது, மேலும் ஆர்டர்களைப் பெற்று அவற்றைக் கண்காணிக்க உதவுகிறது.",
    "te": "ఆర్టిసన్ AI (Artisan AI) చేతివృత్తుల కళాకారులు కేవలం ఫోటో తీసి తమ స్వంత భాషలో మాట్లాడటం ద్వారా విక్రయించడానికి అనుమతిస్తుంది; ఇది ఫోటోను మెరుగుపరుస్తుంది, ఆరు భాషల్లో వివరాలు రాస్తుంది, ఖర్చు కంటే తగ్గని న్యాయమైన ధరను సూచిస్తుంది మరియు ఆర్డర్‌లను పొందడంలో, ట్రాక్ చేయడంలో సహాయపడుతుంది.",
    "kn": "ಆರ್ಟಿಸನ್ AI (Artisan AI) ಕರಕುಶಲಕರ್ಮಿಗಳಿಗೆ ಕೇವಲ ಫೋಟೋ ತೆಗೆದು ತಮ್ಮ ಸ್ವಂತ ಭಾಷೆಯಲ್ಲಿ ಮಾತನಾಡುವ ಮೂಲಕ ಮಾರಾಟ ಮಾಡಲು ಅನುಮತಿಸುತ್ತದೆ; ಇದು ಫೋಟೋವನ್ನು ಸ್ವಚ್ಛಗೊಳಿಸುತ್ತದೆ, ಆರು ಭಾಷೆಗಳಲ್ಲಿ ಪಟ್ಟಿಯನ್ನು ಬರೆಯುತ್ತದೆ, ವೆಚ್ಚಕ್ಕಿಂತ ಕಡಿಮೆಯಾಗದ ನ್ಯಾಯಯುತ ಬೆಲೆಯನ್ನು ಸೂಚಿಸುತ್ತದೆ ಮತ್ತು ಆರ್ಡರ್‌ಗಳನ್ನು ಪಡೆಯಲು ಹಾಗೂ ಟ್ರ್ಯಾಕ್ ಮಾಡಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ.",
    "ml": "ആർട്ടിസാൻ AI (Artisan AI) കരകൗശല വിദഗ്ദ്ധർക്ക് ഒരു ഫോട്ടോ എടുത്ത് സ്വന്തം ഭാഷയിൽ സംസാരിച്ചുകൊണ്ട് എളുപ്പത്തിൽ ഉൽപ്പന്നങ്ങൾ വിൽക്കാൻ അവസരമൊരുക്കുന്നു; ഇത് ഫോട്ടോ വൃത്തിയാക്കുന്നു, ആറ് ഭാഷകളിൽ വിവരങ്ങൾ എഴുതുന്നു, ചെലവിനേക്കാൾ താഴെ പോകാത്ത ന്യായവില നിർദ്ദേശിക്കുന്നു, ഓർഡറുകൾ ലഭിക്കാനും track ചെയ്യാനും സഹായിക്കുന്നു.",
}

FAQ_WHO_MADE = {
    "en": "I was created by Noam.",
    "hi": "मुझे नोम (Noam) ने बनाया है।",
    "ta": "நான் நோம் (Noam) அவர்களால் உருவாக்கப்பட்டேன்.",
    "te": "నేను నోమ్ (Noam) ద్వారా సృష్టించబడ్డాను.",
    "kn": "ನನ್ನನ್ನು ನೋಮ್ (Noam) ರಚಿಸಿದ್ದಾರೆ.",
    "ml": "എന്നെ നോം (Noam) ആണ് സൃഷ്ടിച്ചത്.",
}

FAQ_ECOMMERCE_DIFF = {
    "en": "KalaSetu is not an ordinary marketplace; it is your AI virtual business manager. Unlike regular e-commerce that requires typing, pro cameras, and English, KalaSetu lets you simply snap a photo to polish it, speak in your own language to create listings, guarantees prices never fall below your cost floor, and works completely offline.",
    "hi": "कलासेतु कोई साधारण बाज़ार नहीं, बल्कि कारीगरों का एआई वर्चुअल बिज़नेस मैनेजर है। सामान्य ई-कॉमर्स के विपरीत जहाँ टाइपिंग, अंग्रेज़ी और स्टूडियो कैमरों की ज़रूरत होती है, कलासेतु में आप सिर्फ शिल्प की फोटो लेकर उसे निखार सकते हैं, अपनी भाषा में बोलकर लिस्टिंग बना सकते हैं, लागत से कम न होने वाला उचित मूल्य पा सकते हैं और बिना इंटरनेट भी काम कर सकते हैं।",
    "ta": "கலாசேது ஒரு சாதாரண சந்தை அல்ல; இது கைவினைஞர்களுக்கான AI வணிக மேலாளர். தட்டச்சு, ஆங்கிலம் மற்றும் ஸ்டுடியோ கேமராக்கள் தேவைப்படும் வழக்கமான இ-காமர்ஸ் போலல்லாமல், கலாசேதுவில் ஒரு புகைப்படம் எடுத்து அதை மெருகூட்டலாம், உங்கள் தாய்மொழியில் பேசி விவரக்குறிப்பை உருவாக்கலாம், அடக்க விலைக்குக் குறையாத நியாயமான விலையைப் பெறலாம், மேலும் இணையம் இல்லாமலும் பயன்படுத்தலாம்.",
    "te": "కలాసేతు కేవలం సాధారణ మార్కెట్ కాదు; ఇది చేతివృత్తుల వారి కోసం AI వర్చువల్ బిజినెస్ మేనేజర్. ఇంగ్లీష్, టైపింగ్ మరియు స్టూడియో కెమెరాలు అవసరమయ్యే సాధారణ ఇ-కామర్స్ వలె కాకుండా, కలాసేతులో మీరు కేవలం ఫోటో తీసి దాన్ని మెరుగుపరచవచ్చు, మీ స్వంత భాషలో మాట్లాడి కేటలాగ్ సృష్టించవచ్చు, ఖర్చు కంటే తగ్గని న్యాయమైన ధరను పొందవచ్చు మరియు ఆఫ్‌లైన్‌లోనూ పనిచేయవచ్చు.",
    "kn": "ಕಲಾಸೇತು ಕೇವಲ ಸಾಮಾನ್ಯ ಮಾರುಕಟ್ಟೆಯಲ್ಲ; ಇದು ಕರಕುಶಲಕರ್ಮಿಗಳ AI ವರ್ಚುವಲ್ ವ್ಯವಹಾರ ವ್ಯವಸ್ಥಾಪಕ. ಟೈಪಿಂಗ್, ಇಂಗ್ಲಿಷ್ ಮತ್ತು ಸ್ಟುಡಿಯೋ ಕ್ಯಾಮೆರಾಗಳ ಅಗತ್ಯವಿರುವ ಸಾಮಾನ್ಯ ಇ-ಕಾಮರ್ಸ್‌ಗಿಂತ ಭಿನ್ನವಾಗಿ, ಕಲಾಸೇತುನಲ್ಲಿ ಕೇವಲ ಫೋಟೋ ತೆಗೆದು ಅದನ್ನು ಸುಧಾರಿಸಬಹುದು, ನಿಮ್ಮ ಮಾತೃಭಾಷೆಯಲ್ಲೇ ಮಾತನಾಡಿ ಪಟ್ಟಿಯನ್ನು ರಚಿಸಬಹುದು, ವೆಚ್ಚಕ್ಕಿಂತ ಕಡಿಮೆಯಾಗದ ನ್ಯಾಯಯುತ ಬೆಲೆ ಪಡೆಯಬಹುದು ಮತ್ತು ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಬಳಸಬಹುದು.",
    "ml": "കലാസേതു ഒരു സാധാരണ വിപണിയല്ല; ഇത് കരകൗശല വിദഗ്ദ്ധർക്കായുള്ള ഒരു AI വെർച്വൽ ബിസിനസ്സ് മാനേജറാണ്. ടൈപ്പിംഗും ഇംഗ്ലീഷും സ്റ്റുഡിയോ ക്യാമറകളും ആവശ്യമായ സാധാരണ ഇ-കൊമേഴ്‌സിൽ നിന്ന് വ്യത്യസ്തമായി, കലാസേതുവിൽ ഒരു ഫോട്ടോ എടുത്ത് അത് മെച്ചപ്പെടുത്താനും, സ്വന്തം ഭാഷയിൽ സംസാരിച്ച് ലിസ്റ്റിംഗ് തയ്യാറാക്കാനും, ചെലവിനേക്കാൾ താഴെ പോകാത്ത ന്യായവില ഉറപ്പാക്കാനും, ഇന്റർനെറ്റ് ഇല്ലാതെയും ഉപയോഗിക്കാനും സാധിക്കും.",
}


def classify_query(message: str, history: Optional[List[Dict[str, str]]] = None) -> str:
    """Classifies user message into Creator, Action, Category A, Category B, or Category C."""
    text_lower = message.lower().strip()

    # 1. Creator identity intent
    creator_keywords = [
        "who made you", "who made this app", "who created you", "who created this app",
        "who invented you", "who invented this app", "who developed you", "who developed this app",
        "who built you", "who built this app", "who is your creator", "who designed you",
        "who created kalasetu", "who made kalamitra", "who developed kalamitra",
        "who is behind this app", "made by whom", "created by whom", "noam",
        "तुम्हें किसने बनाया", "यह ऐप किसने बनाया", "किसने आविष्कार किया", "तुम्हारा निर्माता कौन",
        "किसने बनाया आपको", "कलासेतु किसने बनाया", "कलामित्र किसने बनाया", "नोम",
        "உங்களை யார் உருவாக்கியது", "இந்த செயலியை யார் உருவாக்கியது", "யார் கண்டுபிடித்தது",
        "உருவாக்கியவர் யார்", "கலாசேதுவை உருவாக்கியவர் யார்", "நோம்",
        "నిన్ను ఎవరు తయారు చేశారు", "ఈ యాప్‌ను ఎవరు తయారు చేశారు", "ఎవరు సృష్టించారు",
        "సృష్టికర్త ఎవరు", "కలాసేతును ఎవరు సృష్టించారు", "నోమ్",
        "ನಿಮ್ಮನ್ನು ಯಾರು ಮಾಡಿದ್ದು", "ಈ ಆ್ಯಪ್ ಯಾರು ಮಾಡಿದ್ದು", "ಯಾರು ಸೃಷ್ಟಿಸಿದರು",
        "ಸೃಷ್ಟಿಕರ್ತ ಯಾರು", "ಕಲಾಸೇತು ಯಾರು ಮಾಡಿದ್ದು", "ನೋಮ್",
        "നിങ്ങളെ ആരാണ് ഉണ്ടാക്കിയത്", "ഈ ആപ്പ് ആരാണ് ഉണ്ടാക്കിയത്", "ആരാണ് സൃഷ്ടിച്ചത്",
        "ആരാണ് നിർമ്മിച്ചത്", "കലാസേതു ആരാണ് ഉണ്ടാക്കിയത്", "നോം",
    ]
    if any(k in text_lower for k in creator_keywords):
        return INTENT_CREATOR

    # 2. Navigation / App Action intents
    action_keywords = [
        "add product", "new product", "create product", "take photo", "add photo", "open studio",
        "list product", "upload photo", "add craft", "new craft", "add a new", "add a", "add new",
        "नया उत्पाद", "उत्पाद जोड़ें", "फोटो खींचो", "புதிய தயாரிப்பு",
        "show orders", "pending orders", "view orders", "check orders", "pending customer orders",
        "show me my pending", "ऑर्डर देखें", "ஆர்டர்கள்",
        "change language", "switch language", "language to", "भाषा बदलो", "மொழி மாற்று",
        "explain screen", "explain this screen", "what is this screen", "explain this page",
        "इस स्क्रीन को समझाओ", "இந்த திரையை விளக்கு",
    ]
    if any(k in text_lower for k in action_keywords):
        return INTENT_ACTION

    # 3. Category C — Current / Live information
    live_keywords = [
        "weather", "temperature", "is it raining", "will it rain", "forecast", "climate today",
        "today's weather", "weather today", "current weather", "temperature now", "weather now",
        "मौसम", "तापमान", "बारिश", "வானிலை", "மழை", "வெப்பநிலை",
        "వాతావరణం", "వర్షం", "ಹವಾಮಾನ", "ಮಳೆ", "കാലാവസ്ഥ", "മഴ",
        "today's news", "latest news", "breaking news", "what happened today", "current news",
        "आज की खबर", "ताजा खबर", "இன்றைய செய்தி",
        "current price of gold", "current price of silver", "current stock", "live price", "crypto price",
        "what time is it", "what is today's date", "current time",
    ]
    if any(k in text_lower for k in live_keywords):
        return CATEGORY_C

    # 4. Category A — KalaSetu / Project questions
    kalasetu_explicit_keywords = [
        "kalasetu", "kala setu", "kalamitra", "kala mitra", "कलासेतु", "कलामित्र", "கலாசேது", "கலாமித்ரா",
        "కలాసేతు", "ಕಲಾಸೇತು", "കലാസേതു",
        "artisan ai", "this app", "about the app", "why should i use", "why use this",
        "what is special", "special about", "what can you do", "what can this app do",
        "why better than amazon", "why not amazon", "different from amazon", "difference from amazon",
        "why not flipkart", "different from flipkart", "different from other e-commerce",
        "different from ecommerce", "different from normal ecommerce", "ecommerce apps", "shopping app",
        "why do artisans need", "how does it help artisans", "how does kalasetu help",
        "who is kalasetu for", "what problem does kalasetu solve", "what problem does this app solve",
        "calculate price", "how does it calculate price", "how is price calculated", "dynamic pricing",
        "fair price", "cost floor", "image studio", "enhance photo", "voice catalog", "auto-catalog",
        "multilingual catalog", "physical fairs", "surajkund", "dilli haat", "shilp samagam",
        "virtual business manager", "why an artisan should choose", "what makes kalasetu different",
    ]
    if any(k in text_lower for k in kalasetu_explicit_keywords):
        return CATEGORY_A

    # 4b. Follow-up detection for Category A based on recent conversation history
    if history and len(history) > 0:
        recent_context = " ".join([h.get("content", "").lower() for h in history[-3:]])
        is_kalasetu_active = any(k in recent_context for k in [
            "kalasetu", "kala setu", "kalamitra", "कलासेतु", "கலாசேது", "artisan", "craft", "virtual business"
        ])
        followup_pronouns = [
            "it", "this", "the app", "its", "does it", "can it", "why is it", "how does it",
            "what does it", "who is it for", "how do i use it", "यह", "इसे", "இது", "ఇది", "ಇದು", "ഇത്"
        ]
        if is_kalasetu_active and any(re.search(rf"\b{re.escape(p)}\b", text_lower) for p in followup_pronouns):
            return CATEGORY_A

    # 5. Default to Category B (General questions: Python, ML, jokes, math, etc.)
    return CATEGORY_B


def get_relevant_context(category: str, message: str) -> Optional[str]:
    """Retrieves relevant official KalaSetu context sections based on detected query category."""
    if category == CATEGORY_A:
        msg_lower = message.lower()
        sections = [KALASETU_PROJECT_CONTEXT]
        if any(k in msg_lower for k in ["amazon", "ecommerce", "shopping", "different", "market"]):
            sections.append(
                "NOTE ON E-COMMERCE COMPARISON:\n"
                "Explain the difference clearly and respectfully. Normal e-commerce platforms (e.g. Amazon) "
                "are marketplaces that assume sellers already have digital literacy, studio photography, "
                "English descriptions, and pricing acumen. KalaSetu is a virtual business manager designed "
                "to solve the problems BEFORE and DURING selling: removing backgrounds, multilingual voice "
                "cataloging, wage-protecting cost-floor pricing, and year-round digital exposure."
            )
        return "\n\n".join(sections)

    if category == CATEGORY_C:
        return (
            "NOTE ON LIVE/CURRENT INFORMATION:\n"
            "The application does NOT currently have access to live weather sensors, live news feeds, "
            "or real-time external market price APIs.\n"
            "You MUST clearly and honestly state to the user that live weather, current news, or real-time external data "
            "is currently unavailable.\n"
            "NEVER fabricate, guess, or invent today's weather, current temperatures, or breaking news."
        )
    return None


def generate_mock_reply(
    query: str,
    category: str,
    lang: str = "en",
    screen: str = "home"
) -> AssistantChatResponse:
    """Generates rich, rule-grounded mock responses conforming to requirements."""
    q_lower = query.lower().strip()

    # 1. Creator identity
    if category == INTENT_CREATOR or "who made" in q_lower or "who created" in q_lower:
        reply = FAQ_WHO_MADE.get(lang, FAQ_WHO_MADE["en"])
        return AssistantChatResponse(
            reply=reply,
            action="none",
            suggestions=["What is special about KalaSetu?", "Add Product", "Check Orders"],
        )

    # 2. Navigation / Action intents
    if category == INTENT_ACTION:
        if any(k in q_lower for k in ["add", "photo", "studio", "create", "उत्पाद", "படம்"]):
            return AssistantChatResponse(
                reply="Opening the AI Image Studio so you can capture and enhance your craft photo.",
                action="navigate",
                route="/studio",
                suggestions=["Take craft photo", "Check fair pricing", "Explain screen"],
            )
        if any(k in q_lower for k in ["order", "pending", "sales", "ऑर्डर", "ஆர்டர்"]):
            return AssistantChatResponse(
                reply="Opening your Orders screen to view new and pending customer orders.",
                action="navigate",
                route="/orders?filter=new",
                suggestions=["View All Orders", "Back to Home", "Add Product"],
            )
        if any(k in q_lower for k in ["language", "hindi", "tamil", "भाषा", "மொழி"]):
            code = "hi" if "hindi" in q_lower or "हिन्दी" in q_lower else "ta"
            return AssistantChatResponse(
                reply=f"Switching app language to {code}.",
                action="change_language",
                target_lang=code,
                suggestions=["Add Product", "Pending Orders", "Explain Screen"],
            )
        if any(k in q_lower for k in ["explain", "help", "समझाओ", "விளக்கு"]):
            return AssistantChatResponse(
                reply=f"You are currently on the {screen} screen. You can manage products, track orders, or consult KalaMitra.",
                action="explain",
                suggestions=["Add Product", "Pending Orders", "Change Language"],
            )

    # 3. Category C — Current / Live information
    if category == CATEGORY_C:
        if any(k in q_lower for k in ["weather", "temperature", "rain", "मौसम", "வானிலை"]):
            return AssistantChatResponse(
                reply="I currently do not have access to live weather data or external weather sensors, so live weather information is unavailable. Please check your local weather app.",
                action="none",
                suggestions=["What is KalaSetu?", "What is Python?", "Tell me a joke"],
            )
        if any(k in q_lower for k in ["news", "खबर", "செய்தி"]):
            return AssistantChatResponse(
                reply="I do not currently have access to live news feeds or real-time internet searches. Real-time news is unavailable.",
                action="none",
                suggestions=["What is KalaSetu?", "Explain machine learning", "Tell me a joke"],
            )
        return AssistantChatResponse(
            reply="Live real-time external information is currently unavailable as no live data provider is connected.",
            action="none",
            suggestions=["What is KalaSetu?", "What is Python?", "How does KalaSetu help artisans?"],
        )

    # 4. Category A — KalaSetu / Project questions
    if category == CATEGORY_A:
        if any(k in q_lower for k in ["amazon", "flipkart", "ecommerce", "shopping app", "why should i use kalasetu instead"]):
            reply = FAQ_ECOMMERCE_DIFF.get(lang, FAQ_ECOMMERCE_DIFF["en"])
            return AssistantChatResponse(
                reply=reply,
                action="none",
                suggestions=["What is special about KalaSetu?", "How does KalaSetu calculate price?", "Take craft photo"],
            )

        if any(k in q_lower for k in ["special", "what can kalasetu do", "unique", "खासियत", "சிறப்பு", "what is special about this app"]):
            reply = FAQ_APP_SPECIAL.get(lang, FAQ_APP_SPECIAL["en"])
            return AssistantChatResponse(
                reply=reply,
                action="none",
                suggestions=["Why use KalaSetu instead of Amazon?", "How does pricing work?", "Open Studio"],
            )

        if any(k in q_lower for k in ["how does kalasetu help", "how it helps", "help an artisan", "help me sell"]):
            reply = (
                "KalaSetu helps artisans by removing technical and digital barriers. It provides: "
                "1) AI Image Studio to enhance craft photos without expensive equipment, "
                "2) Voice-based auto-cataloging in regional languages, "
                "3) A Dynamic Pricing Assistant that guarantees you never sell below your cost floor, and "
                "4) Year-round digital sales support so you are not dependent only on occasional trade fairs."
            )
            return AssistantChatResponse(
                reply=reply,
                action="none",
                suggestions=["Why use KalaSetu instead of Amazon?", "What problem does KalaSetu solve?", "Add Product"],
            )

        if any(k in q_lower for k in ["problem", "solve", "challenge", "background"]):
            reply = (
                "KalaSetu solves the critical gap between traditional craftsmanship and modern digital commerce. "
                "Artisans often face low digital literacy, language barriers, poor product photos, and difficulty pricing items, "
                "leaving them dependent only on temporary fairs like Shilp Samagam or Surajkund Mela. KalaSetu acts as an AI "
                "virtual business manager to automate photography cleanup, multilingual cataloging, and fair wage calculation."
            )
            return AssistantChatResponse(
                reply=reply,
                action="none",
                suggestions=["How does KalaSetu help artisans?", "How is price calculated?", "Open Studio"],
            )

        if any(k in q_lower for k in ["price", "calculate", "pricing", "cost floor"]):
            reply = (
                "KalaSetu calculates pricing with a strict cost-floor model: "
                "Raw Materials + Labor (Hours × Fair Hourly Wage) + Packaging/Overhead + Profit Margin. "
                "The suggested price guarantees you never sell below basic production costs while recommending competitive market prices."
            )
            return AssistantChatResponse(
                reply=reply,
                action="none",
                suggestions=["Check fair pricing", "Why use KalaSetu instead of Amazon?", "Add Product"],
            )

        return AssistantChatResponse(
            reply="KalaSetu is an AI-powered virtual business manager designed to help traditional artisans take professional photos, describe crafts by voice in regional languages, and ensure fair wages with digital market reach.",
            action="none",
            suggestions=["What is special about KalaSetu?", "Why use KalaSetu instead of Amazon?", "Add Product"],
        )

    # 5. Category B — General / Normal questions
    if any(k in q_lower for k in ["python"]):
        return AssistantChatResponse(
            reply="Python is a popular high-level, interpreted programming language known for its easy-to-read syntax and versatility in web development, data science, artificial intelligence, and automation.",
            action="none",
            suggestions=["What is machine learning?", "What is a database?", "Tell me a joke"],
        )
    if any(k in q_lower for k in ["machine learning", "ml"]):
        return AssistantChatResponse(
            reply="Machine learning is a subset of artificial intelligence focused on building algorithms that learn patterns from data and improve their performance over time without being explicitly programmed.",
            action="none",
            suggestions=["What is Python?", "What is a database?", "Explain something to me"],
        )
    if any(k in q_lower for k in ["president of india", "president"]):
        return AssistantChatResponse(
            reply="The President of India is the head of state of the Republic of India and supreme commander of the Indian Armed Forces. Droupadi Murmu is the current President of India.",
            action="none",
            suggestions=["What is the capital of India?", "What is Python?", "Tell me a joke"],
        )
    if any(k in q_lower for k in ["capital of india"]):
        return AssistantChatResponse(
            reply="The capital of India is New Delhi.",
            action="none",
            suggestions=["Who is the president of India?", "What is Python?", "Tell me a joke"],
        )
    if any(k in q_lower for k in ["database", "sql"]):
        return AssistantChatResponse(
            reply="A database is an organized collection of structured information or data, typically stored electronically in a computer system and managed by a Database Management System (DBMS).",
            action="none",
            suggestions=["What is Python?", "Explain machine learning", "Tell me a joke"],
        )
    if any(k in q_lower for k in ["joke"]):
        return AssistantChatResponse(
            reply="Why do programmers prefer dark mode? Because light attracts bugs!",
            action="none",
            suggestions=["Tell me another joke", "What is Python?", "What is KalaSetu?"],
        )
    if "25" in q_lower and "30" in q_lower:
        return AssistantChatResponse(
            reply="25 × 30 = 750.",
            action="none",
            suggestions=["Explain machine learning", "What is Python?", "Tell me a joke"],
        )

    return AssistantChatResponse(
        reply="I am happy to assist you! Feel free to ask about KalaSetu, traditional crafts, business tips, technology, or any general topic.",
        action="none",
        suggestions=["What is KalaSetu?", "What is special about KalaSetu?", "Tell me a joke"],
    )
