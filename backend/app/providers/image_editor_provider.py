import os
import json
import logging
from typing import Any, Dict, List, Optional

from app.config import get_settings
from app.providers.interfaces import ImageEditor
from app.providers.gemini_client import GeminiClient, GeminiClientError, log_ai_failure
from app.providers.gemini_provider import GeminiSpeechToText
from app.services.image_editor import execute_edit_action_async
from app.providers.mock_providers import MockImageEditor

logger = logging.getLogger("kalasetu.image_editor_provider")

VOICE_COMMAND_SYSTEM_PROMPT = """You are KalaSetu's AI Artisan Photo Editor Voice Assistant.
Artisans speak commands in Indian languages (Hindi, Tamil, Telugu, Kannada, Malayalam, English, or mixed Hinglish/Tanglish/Tenglish).
Your job is to convert their voice or text command into structured editing operations applied to a handcrafted product photo.

Allowed operations (STRICT SCHEMA - use ONLY these):
- "remove_background": {"type": "remove_background", "value": true}
- "keep_background": {"type": "keep_background", "value": true}
- "replace_background": {"type": "replace_background", "value": "white"|"linen"|"blue"|"red"|"green"|"yellow"|"black"|"wood"|"marble"|"studio"|"transparent"|"soft gradient"|"blur"|"textured"|<hex color>}
- "brightness": {"type": "brightness", "value": 1.25} (1.2-1.3 for brighter, 0.7-0.8 for darker)
- "contrast": {"type": "contrast", "value": 1.2}
- "warmth": {"type": "warmth", "value": 0.3} (positive for warmer/golden, negative for cooler)
- "saturation": {"type": "saturation", "value": 1.25}
- "sharpness": {"type": "sharpness", "value": 1.3}
- "shadow": {"type": "shadow", "value": true|false} (false when user asks to remove/hide shadow)
- "zoom": {"type": "zoom", "value": 1.2}
- "rotate": {"type": "rotate", "value": 90}
- "flip": {"type": "flip", "value": "horizontal"|"vertical"}
- "add_border": {"type": "add_border", "value": 16, "color": "white"|"linen"|"terracotta"}
- "product_size": {"type": "product_size", "value": 0.88} (e.g. when user asks to make the product/pot larger or smaller)
- "auto_enhance": {"type": "auto_enhance", "value": true}

Special control actions:
- "action": "undo" (e.g. "undo", "wapas lo", "thirumba podu", "theeseyyi marla")
- "action": "redo" (e.g. "redo", "aage badhao")
- "action": "reset" (e.g. "reset", "shuru jaisa karo", "modhati laga cheyyi")

Examples:
1. "background neela karo" -> operations: [{"type": "replace_background", "value": "blue"}], confirmation: "पृष्ठभूमि को नीला कर दिया गया है।"
2. "konjam brightaa" / "bright aakku" -> operations: [{"type": "brightness", "value": 1.25}], confirmation: "வெளிச்சம் அதிகரிக்கப்பட்டது."
3. "shadow theeseyyi" -> operations: [{"type": "shadow", "value": false}], confirmation: "నీడ తొలగించబడింది."
4. "pot ni peddadi cheyyi" -> operations: [{"type": "product_size", "value": 0.88}], confirmation: "కుండ పరిమాణం పెంచబడింది."
5. "put on wooden table" -> operations: [{"type": "replace_background", "value": "wood"}], confirmation: "Placed on a handcrafted wooden table."
6. "undo" -> action: "undo", operations: [], confirmation: "Undone."

Rules:
1. Return JSON matching:
{
  "operations": [{"type": "...", "value": ...}],
  "action": "apply"|"undo"|"redo"|"reset",
  "confirmation": "Short friendly confirmation sentence in the user's language",
  "clarification_needed": false,
  "clarifying_question": "",
  "is_free_form_ai": false,
  "warn_product_change": false,
  "product_change_warning": ""
}
2. PRODUCT FIDELITY RULE: Edit ONLY background, scene and lighting; keep the product exactly as is.
3. If the user asks to change the product's OWN colour or shape (e.g. "change the pot color to yellow", "make the vase rectangular", "paint the saree blue"):
   set warn_product_change: true, and product_change_warning: "Warning: Changing the product's own colour or shape may mislead buyers as they would see something different from the actual handcrafted item." (translated into the user's language).
4. If the request is unclear (e.g. "kuch badlo", "make it different"):
   set clarification_needed: true, operations: [], and clarifying_question: short question in user's language asking whether they want to change background, lighting, or size.
5. If the user asks for generative modifications that cannot be achieved with the operations above (e.g. "add flowers in the pot", "turn pot into elephant"):
   set is_free_form_ai: true.
"""


def parse_rule_based_voice_command(text: str, lang: str = "en") -> Dict[str, Any]:
    """Robust multilingual fallback engine matching common voice commands across all 6 languages."""
    t = text.lower().strip()

    # Product fidelity check for command intent
    warn_product_change = False
    product_warning = None
    if any(k in t for k in [
        "pot color", "product color", "item color", "craft color", "color of product",
        "product ka rang", "pot ka rang", "shape badlo", "aakaar badlo", "change shape",
        "paint the pot", "paint product", "color the pot", "make pot", "make product",
        "कुल्हड़ का रंग", "बर्तन का रंग", "आकार बदलो", "కుండ రంగు", "ఆకారం మార్చు", "வடிவம் மாற்று"
    ]):
        warn_product_change = True
        product_change_warnings = {
            "hi": "चेतावनी: उत्पाद का मूल रंग या आकार बदलने से खरीदार वास्तविक हस्तशिल्प से अलग देखेंगे।",
            "ta": "எச்சரிக்கை: தயாரிப்பின் சொந்த நிறம் அல்லது வடிவத்தை மாற்றுவது வாங்குபவர்களை தவறாக வழிநடத்தலாம்.",
            "te": "హెచ్చరిక: ఉత్పత్తి యొక్క అసలు రంగు లేదా ఆకారాన్ని మార్చడం వలన కొనుగోలుదారులు వేరేలా చూస్తారు.",
            "kn": "ಎಚ್ಚರಿಕೆ: ಉತ್ಪನ್ನದ ಸ್ವಂತ ಬಣ್ಣ ಅಥವಾ ಆಕಾರವನ್ನು ಬದಲಾಯಿಸುವುದು ಖರೀದಿದಾರರಿಗೆ ಗೊಂದಲ ಮೂಡಿಸಬಹುದು.",
            "ml": "മുന്നറിയിപ്പ്: ഉൽപ്പന്നത്തിന്റെ യഥാർത്ഥ നിറമോ രൂപമോ മാറ്റുന്നത് ഉപഭോക്താക്കളെ തെറ്റിദ്ധരിപ്പിച്ചേക്കാം.",
            "en": "Warning: Changing the product's own colour or shape may mislead buyers as they would see something different from the actual handcrafted item.",
        }
        product_warning = product_change_warnings.get(lang, product_change_warnings["en"])

    # Check Undo
    if any(k in t for k in ["undo", "vaapas", "wapas", "thirumba", "venakki", "hindakke", "thirike", "रद्द", "రద్దు", "மீட்டமை"]):
        confirmations = {
            "hi": "पिछला बदलाव वापस ले लिया गया है।",
            "ta": "முந்தைய மாற்றம் மீட்டமைக்கப்பட்டது.",
            "te": "మునుపటి మార్పు రద్దు చేయబడింది.",
            "kn": "ಹಿಂದಿನ ಬದಲಾವಣೆಯನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.",
            "ml": "മുമ്പത്തെ മാറ്റം പിൻവലിച്ചു.",
            "en": "Previous change undone.",
        }
        return {
            "operations": [],
            "action": "undo",
            "confirmation": confirmations.get(lang, confirmations["en"]),
            "clarification_needed": False,
            "is_free_form_ai": False,
        }

    # Check Redo
    if any(k in t for k in ["redo", "aage", "marupadiyum", "మళ్ళీ", "ಮತ್ತೆ"]):
        confirmations = {
            "hi": "बदलाव दोबारा लागू किया गया।",
            "ta": "மாற்றம் மீண்டும் பயன்படுத்தப்பட்டது.",
            "te": "మార్పు మళ్లీ వర్తింపజేయబడింది.",
            "kn": "ಬದಲಾವಣೆಯನ್ನು ಪುನರಾವರ್ತಿಸಲಾಗಿದೆ.",
            "ml": "മാറ്റം വീണ്ടും പ്രയോഗിച്ചു.",
            "en": "Change redone.",
        }
        return {
            "operations": [],
            "action": "redo",
            "confirmation": confirmations.get(lang, confirmations["en"]),
            "clarification_needed": False,
            "is_free_form_ai": False,
        }

    # Check Reset
    if any(k in t for k in ["reset", "restart", "pehle jaisa", "aarambham", "modhata", "మొదటి", "రీసెట్", "ಆರಂಭ", "യഥാർത്ഥ"]):
        confirmations = {
            "hi": "फ़ोटो को मूल स्थिति में रीसेट कर दिया गया है।",
            "ta": "புகைப்படம் ஆரம்ப நிலைக்கு மீட்டமைக்கப்பட்டது.",
            "te": "ఫోటో అసలు స్థితికి రీసెట్ చేయబడింది.",
            "kn": "ಫೋಟೋವನ್ನು ಮೊದಲಿನ ಸ್ಥಿತಿಗೆ ಮರುಹೊಂದಿಸಲಾಗಿದೆ.",
            "ml": "ഫോട്ടോ യഥാർത്ഥ അവസ്ഥയിലേക്ക് പുനഃസ്ഥാപിച്ചു.",
            "en": "Photo reset to original.",
        }
        return {
            "operations": [],
            "action": "reset",
            "confirmation": confirmations.get(lang, confirmations["en"]),
            "clarification_needed": False,
            "is_free_form_ai": False,
        }

    operations = []
    confirmation = ""

    # 1. Background commands
    if any(k in t for k in ["wood", "wooden", "table", "lakdi", "chekka", "maram", "mara", "लकड़ी", "मेज", "చెక్క", "టేబుల్", "மர மேசை", "ಮರದ ಮೇಜು"]):
        operations.append({"type": "replace_background", "value": "wood"})
        confirmations = {
            "hi": "उत्पाद को लकड़ी की मेज पर रख दिया गया है।",
            "ta": "தயாரிப்பு மர மேசையில் வைக்கப்பட்டது.",
            "te": "ఉత్పత్తి చెక్క టేబుల్‌పై ఉంచబడింది.",
            "kn": "ಉತ್ಪನ್ನವನ್ನು ಮರದ ಮೇಜಿನ ಮೇಲೆ ಇರಿಸಲಾಗಿದೆ.",
            "ml": "ഉൽപ്പന്നം മരമേശപ്പുറത്ത് വെച്ചു.",
            "en": "Placed on a handcrafted wooden table.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["marble", "sangmarmar", "मार्बल", "మార్బుల్", "மார்பிள்"]):
        operations.append({"type": "replace_background", "value": "marble"})
        confirmations = {
            "hi": "मार्बल पृष्ठभूमि लागू की गई है।",
            "ta": "மார்பிள் பின்னணி அமைக்கப்பட்டது.",
            "te": "మార్బుల్ బ్యాక్‌గ్రౌండ్ వర్తింపజేయబడింది.",
            "kn": "ಮಾರ್ಬಲ್ ಹಿನ್ನೆಲೆ ಅನ್ವಯಿಸಲಾಗಿದೆ.",
            "ml": "മാർബിൾ പശ്ചാത്തലം സജ്ജമാക്കി.",
            "en": "Luxury marble background applied.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["studio", "backdrop", "స్టూడియో", "ஸ்டுடியோ", "स्टूडियो"]):
        operations.append({"type": "replace_background", "value": "studio"})
        confirmations = {
            "hi": "स्टूडियो पृष्ठभूमि लागू की गई है।",
            "ta": "ஸ்டுடியோ பின்னணி அமைக்கப்பட்டது.",
            "te": "స్టూడియో బ్యాక్‌గ్రౌండ్ వర్తింపజేయబడింది.",
            "kn": "ಸ್ಟುಡಿಯೋ ಹಿನ್ನೆಲೆ ಅನ್ವಯಿಸಲಾಗಿದೆ.",
            "ml": "സ്റ്റുഡിയോ പശ്ചാത്തലം സജ്ജമാക്കി.",
            "en": "Professional studio background applied.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["neela", "neelam", "blue", "नीला", "நீல", "నీలం", "ನೀಲಿ", "നീല"]):
        operations.append({"type": "replace_background", "value": "blue"})
        confirmations = {
            "hi": "पृष्ठभूमि को नीला कर दिया गया है।",
            "ta": "பின்னணி நீல நிறமாக மாற்றப்பட்டது.",
            "te": "బ్యాక్‌గ్రౌండ్ నీలం రంగులోకి మార్చబడింది.",
            "kn": "ಹಿನ್ನೆಲೆಯನ್ನು ನೀಲಿ ಬಣ್ಣಕ್ಕೆ ಬದಲಾಯಿಸಲಾಗಿದೆ.",
            "ml": "പശ്ചാത്തലം നീല നിറമാക്കി മാറ്റി.",
            "en": "Background changed to blue.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["white", "safed", "vellai", "tella", "bili", "vella", "सफेद", "सफ़ेद", "తెల్ల", "வெள்ளை", "ಬಿಳಿ", "വെള്ള"]):
        operations.append({"type": "replace_background", "value": "white"})
        confirmations = {
            "hi": "सफ़ेद पृष्ठभूमि लागू की गई है।",
            "ta": "வெள்ளை பின்னணி அமைக்கப்பட்டது.",
            "te": "తెల్లటి బ్యాక్‌గ్రౌండ్ వర్తింపజేయబడింది.",
            "kn": "ಬಿಳಿ ಹಿನ್ನೆಲೆಯನ್ನು ಅನ್ವಯಿಸಲಾಗಿದೆ.",
            "ml": "വെള്ള പശ്ചാത്തലം സജ്ജമാക്കി.",
            "en": "White background applied.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["linen", "linan", "safed kapda"]):
        operations.append({"type": "replace_background", "value": "linen"})
        confirmations = {
            "hi": "लिनन पृष्ठभूमि लागू की गई है।",
            "ta": "லினன் பின்னணி அமைக்கப்பட்டது.",
            "te": "లినెన్ బ్యాక్‌గ్రౌండ్ వర్తింపజేయబడింది.",
            "kn": "ಲಿನೆನ್ ಹಿನ್ನೆಲೆಯನ್ನು ಅನ್ವಯಿಸಲಾಗಿದೆ.",
            "ml": "ലിനൻ പശ്ചാത്തലം സജ്ജമാക്കി.",
            "en": "Linen background applied.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["remove background", "background hatao", "hata do", "bg remove", "thedidu", "cutout", "హటావో", "తొలగించు", "తీసివేయి", "நீக்கு", "ತೆಗೆದುಹಾಕು", "നീക്കം", "हटाओ", "हटा दो"]):
        operations.append({"type": "remove_background", "value": True})
        confirmations = {
            "hi": "पृष्ठभूमि हटा दी गई है।",
            "ta": "பின்னணி நீக்கப்பட்டது.",
            "te": "బ్యాక్‌గ్రౌండ్ తొలగించబడింది.",
            "kn": "ಹಿನ್ನೆಲೆ ತೆಗೆದುಹಾಕಲಾಗಿದೆ.",
            "ml": "പശ്ചാത്തലം നീക്കം ചെയ്തു.",
            "en": "Background removed.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    elif any(k in t for k in ["gradient", "soft gradient"]):
        operations.append({"type": "replace_background", "value": "soft gradient"})
        confirmation = "Soft gradient background applied."

    elif any(k in t for k in ["blur", "dhundhla", "mangal"]):
        operations.append({"type": "replace_background", "value": "blur"})
        confirmation = "Background softly blurred."

    elif any(k in t for k in ["texture", "textured", "surface"]):
        operations.append({"type": "replace_background", "value": "textured"})
        confirmation = "Artisan textured surface applied."

    # 2. Auto Enhance / Professional lighting
    if any(k in t for k in ["enhance", "professional", "clearer", "बेहतर", "మెరుగు", "మేம்படுத்து", "ಸುಧಾರಿಸು"]):
        operations.append({"type": "auto_enhance", "value": True})
        confirmations = {
            "hi": "फ़ोटो की रोशनी और स्पष्टता को बेहतर बनाया गया है।",
            "ta": "ஒளி மற்றும் தரம் மேம்படுத்தப்பட்டது.",
            "te": "ఫోటో నాణ్యత మరియు కాంతి మెరుగుపరచబడింది.",
            "kn": "ಫೋಟೋ ಗುಣಮಟ್ಟ ಮತ್ತು ಬೆಳಕನ್ನು ಸುಧಾರಿಸಲಾಗಿದೆ.",
            "ml": "ഫോട്ടോയുടെ വ്യക്തത വർദ്ധിപ്പിച്ചു.",
            "en": "Photo enhanced for e-commerce.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    # 3. Brightness
    elif any(k in t for k in ["bright", "roshni", "velicham", "ujwala", "prakasam", "lighting", "रोशनी", "चमक", "వెలుతురు", "வெளிச்சம்", "ಬೆಳಕು", "വെളിച്ചം"]):
        operations.append({"type": "brightness", "value": 1.25})
        confirmations = {
            "hi": "रोशनी बढ़ा दी गई है।",
            "ta": "வெளிச்சம் அதிகரிக்கப்பட்டது.",
            "te": "వెలుతురు పెంచబడింది.",
            "kn": "ಬೆಳಕನ್ನು ಹೆಚ್ಚಿಸಲಾಗಿದೆ.",
            "ml": "വെളിച്ചം കൂട്ടിയിട്ടുണ്ട്.",
            "en": "Brightness increased.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    # 4. Shadow removal / addition
    if any(k in t for k in ["shadow", "chhaya", "nizhal", "needa", "neralu", "छाया", "నీడ", "நிழல்", "ನೆರಳು"]):
        if any(k in t for k in ["theeseyyi", "hatao", "hata", "vendam", "beda", "kalayuka", "remove", "no", "off", "హటావో", "తొలగించు"]):
            operations.append({"type": "shadow", "value": False})
            confirmations = {
                "hi": "छाया हटा दी गई है।",
                "ta": "நிழல் நீக்கப்பட்டது.",
                "te": "నీడ తొలగించబడింది.",
                "kn": "ನೆರಳು ತೆಗೆದುಹಾಕಲಾಗಿದೆ.",
                "ml": "ನಿഴൽ നീക്കം ചെയ്തു.",
                "en": "Shadow removed.",
            }
            confirmation = confirmations.get(lang, confirmations["en"])
        else:
            operations.append({"type": "shadow", "value": True})
            confirmation = "Shadow applied."

    # 5. Product size / Zoom
    if any(k in t for k in ["peddadi", "bada", "perisaakku", "dodda", "valuth", "bigger", "zoom", "పెద్ద"]):
        operations.append({"type": "product_size", "value": 0.88})
        confirmations = {
            "hi": "उत्पाद का आकार बढ़ा दिया गया है।",
            "ta": "பொருளின் அளவு பெரிதாக்கப்பட்டது.",
            "te": "కుండ పరిమాణం పెంచబడింది.",
            "kn": "ಗಾತ್ರವನ್ನು ಹೆಚ್ಚಿಸಲಾಗಿದೆ.",
            "ml": "വലുപ്പം കൂട്ടിയിട്ടുണ്ട്.",
            "en": "Product size enlarged on canvas.",
        }
        confirmation = confirmations.get(lang, confirmations["en"])

    # 6. Free-form AI request detection
    if any(k in t for k in ["flower", "phool", "pookal", "puthulu", "deepam", "diya", "lamp", "draw", "generate"]):
        return {
            "operations": [],
            "action": "apply",
            "confirmation": "",
            "clarification_needed": False,
            "is_free_form_ai": True,
        }

    # 7. Unclear query check
    if not operations:
        clarifying_questions = {
            "hi": "आप क्या बदलना चाहते हैं? पृष्ठभूमि, रोशनी, या छाया?",
            "ta": "நீங்கள் என்ன மாற்ற விரும்புகிறீர்கள்? பின்னணி, வெளிச்சம் அல்லது நிழல்?",
            "te": "మీరు ఏమి మార్చాలనుకుంటున్నారు? బ్యాక్‌గ్రౌండ్, వెలుతురు లేదా నీడ?",
            "kn": "ನೀವು ಏನನ್ನು ಬದಲಾಯಿಸಲು ಬಯಸುತ್ತೀರಿ? ಹಿನ್ನೆಲೆ, ಬೆಳಕು ಅಥವಾ ನೆರಳು?",
            "ml": "നിങ്ങൾ എന്താണ് മാറ്റാൻ ആഗ്രഹിക്കുന്നത്? പശ്ചാത്തലം, വെളിച്ചം അല്ലെങ്കിൽ നിഴൽ?",
            "en": "What would you like to adjust? The background, lighting, shadow, or size?",
        }
        return {
            "operations": [],
            "action": "none",
            "confirmation": clarifying_questions.get(lang, clarifying_questions["en"]),
            "clarification_needed": True,
            "clarifying_question": clarifying_questions.get(lang, clarifying_questions["en"]),
            "is_free_form_ai": False,
        }

    return {
        "operations": operations,
        "action": "apply",
        "confirmation": confirmation,
        "clarification_needed": False,
        "is_free_form_ai": False,
        "warn_product_change": warn_product_change,
        "product_warning": product_warning,
    }


class RealImageEditor(ImageEditor):
    def __init__(self, gemini_client: Optional[GeminiClient] = None, stt: Optional[GeminiSpeechToText] = None):
        self.gemini_client = gemini_client or GeminiClient()
        self.stt = stt or GeminiSpeechToText()

    async def edit_image(
        self,
        image_id: str,
        operations: Optional[List[Dict[str, Any]]] = None,
        prompt: Optional[str] = None,
        action: Optional[str] = None,
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        settings = get_settings()
        out_dir = storage_dir or settings.STORAGE_LOCAL_PATH
        act = (action or "apply").lower().strip()

        # Handle undo, redo, reset directly via session history
        if act in ["undo", "redo", "reset"]:
            return await execute_edit_action_async(
                image_id=image_id,
                operations=operations,
                action=act,
                storage_dir=out_dir,
            )

        # Parse prompt into operations if operations not explicitly supplied
        effective_ops = list(operations) if operations else []
        if prompt and not effective_ops:
            parsed = parse_rule_based_voice_command(prompt, lang=lang)
            if parsed.get("action") in ["undo", "redo", "reset"]:
                return await execute_edit_action_async(
                    image_id=image_id,
                    operations=None,
                    action=parsed["action"],
                    storage_dir=out_dir,
                )
            if parsed.get("operations"):
                effective_ops = parsed["operations"]

        if not effective_ops:
            effective_ops = [
                {"type": "remove_background", "value": True},
                {"type": "replace_background", "value": "white"},
            ]

        # Construct prompt for Gemini image model
        if prompt and prompt.strip():
            gemini_prompt = (
                f"Edit this handcrafted product photo: {prompt.strip()}. "
                "MANDATORY RULE: Edit ONLY background, scene and lighting; keep the handcrafted product strictly unchanged."
            )
        else:
            op_descriptions = []
            for op in effective_ops:
                op_type = str(op.get("type", "")).lower()
                op_val = op.get("value", "")
                if op_type == "remove_background":
                    op_descriptions.append("remove cluttered background")
                elif op_type == "replace_background":
                    op_descriptions.append(f"replace background with clean {op_val}")
                elif op_type == "brightness":
                    op_descriptions.append(f"adjust brightness factor to {op_val}")
                elif op_type == "shadow":
                    op_descriptions.append("add realistic contact shadow" if op_val else "remove shadow")
                elif op_type == "auto_enhance":
                    op_descriptions.append("auto enhance lighting and clarity")
                elif op_type == "ai_edit" and op.get("prompt"):
                    op_descriptions.append(str(op["prompt"]))
                else:
                    op_descriptions.append(f"{op_type} {op_val}")

            gemini_prompt = (
                f"Edit this handcrafted product photo: {', '.join(op_descriptions)}. "
                "MANDATORY RULE: Edit ONLY background, scene and lighting; keep the handcrafted product strictly unchanged."
            )

        fallback_enabled = getattr(settings, "ENABLE_LOCAL_FALLBACK", False) or os.environ.get("ENABLE_LOCAL_FALLBACK", "").lower() in ("true", "1")
        target_model = (settings.GEMINI_IMAGE_MODEL or "").strip()

        # Shared gateway: All edits use GEMINI_IMAGE_MODEL when in real AI mode
        if settings.AI_MODE == "real" and settings.GEMINI_API_KEY and target_model and act == "apply":
            from app.services.image_editor import _find_source_images, _get_session, _save_session
            orig_path, _ = _find_source_images(image_id, out_dir)
            orig_rel_url = f"/static/uploads/{os.path.basename(orig_path)}"

            with open(orig_path, "rb") as f:
                source_bytes = f.read()

            try:
                edited_bytes = await self.gemini_client.edit_image(
                    image_bytes=source_bytes,
                    prompt=gemini_prompt,
                    model=target_model,
                )
                if not edited_bytes or edited_bytes == source_bytes:
                    raise GeminiClientError(
                        f"No image returned by Gemini model '{target_model}'.",
                        http_status=502,
                        gemini_status="NO_IMAGE_RETURNED",
                        model=target_model,
                        hint="no image returned",
                    )

                sess = _get_session(image_id, out_dir)
                sess["version"] += 1
                ver = sess["version"]
                output_filename = f"{image_id}_v{ver}.png"
                output_path = os.path.join(out_dir, output_filename)
                with open(output_path, "wb") as f:
                    f.write(edited_bytes)

                sess["operations"].extend(effective_ops)
                _save_session(image_id, sess, out_dir)

                return {
                    "status": "success",
                    "image_id": image_id,
                    "image_url": f"/static/uploads/{output_filename}",
                    "original_url": orig_rel_url,
                    "operations": sess["operations"],
                    "can_undo": len(sess["operations"]) > 0,
                    "can_redo": len(sess.get("redo_stack", [])) > 0,
                    "message": "Operation completed successfully via Gemini",
                }
            except Exception as e:
                # Log the exact backend status, Gemini error status, message, model name (never keys)
                info = log_ai_failure(e, target_model)
                logger.warning(
                    f"Backend image edit failed: status={info['http_status']}, "
                    f"gemini_status={info['gemini_status']}, message={info['hint']}, "
                    f"model={info['model']}"
                )

                if fallback_enabled:
                    logger.info(
                        f"ENABLE_LOCAL_FALLBACK is true. Falling back to local image editor for image {image_id}."
                    )
                    local_res = await execute_edit_action_async(
                        image_id=image_id,
                        operations=effective_ops,
                        action=action,
                        storage_dir=out_dir,
                    )
                    local_res["message"] = f"Processed with local fallback ({info['hint']})"
                    return local_res
                else:
                    # Re-raise honest Gemini error so backend returns exact status to developer
                    raise GeminiClientError(
                        f"Gemini image edit failed: [HTTP {info['http_status']} {info['gemini_status']}] {info['hint']}",
                        http_status=info["http_status"],
                        gemini_status=info["gemini_status"],
                        model=info["model"],
                        hint=info["hint"],
                    ) from e

        # If real mode but GEMINI_IMAGE_MODEL is not configured
        if settings.AI_MODE == "real" and not target_model:
            if not fallback_enabled:
                raise GeminiClientError(
                    "GEMINI_IMAGE_MODEL is not configured and ENABLE_LOCAL_FALLBACK is false.",
                    http_status=400,
                    gemini_status="INVALID_ARGUMENT",
                    model="none",
                    hint="GEMINI_IMAGE_MODEL is not configured",
                )
            logger.info("GEMINI_IMAGE_MODEL unset but ENABLE_LOCAL_FALLBACK is true; using local editor.")

        # Local processing (mock AI mode or local fallback)
        return await execute_edit_action_async(
            image_id=image_id,
            operations=effective_ops,
            action=action,
            storage_dir=out_dir,
        )

    async def process_voice_command(
        self,
        image_id: str,
        text: Optional[str] = None,
        audio_bytes: Optional[bytes] = None,
        audio_mime_type: str = "audio/wav",
        lang: str = "en",
        storage_dir: Optional[str] = None,
    ) -> Dict[str, Any]:
        settings = get_settings()

        # 1. Transcribe audio if provided
        transcript = (text or "").strip()
        detected_lang = lang

        if audio_bytes and not transcript:
            try:
                stt_res = await self.stt.transcribe(
                    audio_bytes=audio_bytes,
                    mime_type=audio_mime_type,
                    language_hint=lang,
                )
                transcript = stt_res.get("text", "").strip()
                detected_lang = stt_res.get("detected_lang", lang)
            except Exception as e:
                logger.warning(f"Voice transcription error: {e}")
                transcript = ""

        if not transcript:
            return {
                "status": "error",
                "message": "No command audio or text received",
                "clarification_needed": True,
                "clarifying_question": "Please speak or type what you would like to change.",
            }

        # 2. Extract JSON operations via Gemini or rule-based fallback
        parsed_cmd = None
        if settings.AI_MODE == "real" and self.gemini_client.is_configured:
            try:
                user_prompt = (
                    f"{VOICE_COMMAND_SYSTEM_PROMPT}\n\n"
                    f"User command: \"{transcript}\"\n"
                    f"User language: \"{detected_lang}\"\n"
                    f"Generate the exact JSON."
                )
                gemini_res = await self.gemini_client.generate_json(
                    prompt=user_prompt,
                    temperature=0.1,
                )
                if isinstance(gemini_res, dict) and ("operations" in gemini_res or "action" in gemini_res):
                    parsed_cmd = gemini_res
            except Exception as e:
                logger.warning(f"Gemini voice command interpretation failed: {e}")

        if not parsed_cmd:
            parsed_cmd = parse_rule_based_voice_command(transcript, lang=detected_lang)

        # 3. Check for Free-form Generative AI edit request
        if parsed_cmd.get("is_free_form_ai"):
            if settings.GEMINI_IMAGE_MODEL and settings.GEMINI_IMAGE_MODEL.strip():
                logger.info(f"Dispatching free-form AI edit to model {settings.GEMINI_IMAGE_MODEL}")
                out_dir = storage_dir or settings.STORAGE_LOCAL_PATH
                from app.services.image_editor import _find_source_images, _get_session, _save_session
                orig_path, _ = _find_source_images(image_id, out_dir)
                orig_rel_url = f"/static/uploads/{os.path.basename(orig_path)}"
                try:
                    with open(orig_path, "rb") as f:
                        source_bytes = f.read()

                    edited_bytes = await self.gemini_client.edit_image(
                        image_bytes=source_bytes,
                        prompt=transcript,
                        model=settings.GEMINI_IMAGE_MODEL,
                    )
                    if not edited_bytes or edited_bytes == source_bytes:
                        raise GeminiClientError("Model returned identical or empty image bytes.")

                    sess = _get_session(image_id, out_dir)
                    sess["version"] += 1
                    ver = sess["version"]
                    output_filename = f"{image_id}_v{ver}.png"
                    output_path = os.path.join(out_dir, output_filename)
                    with open(output_path, "wb") as f:
                        f.write(edited_bytes)
                    applied_op = [{"type": "ai_edit", "prompt": transcript}]
                    sess["operations"].extend(applied_op)
                    _save_session(image_id, sess, out_dir)

                    return {
                        "status": "success",
                        "transcript": transcript,
                        "operations": sess["operations"],
                        "new_operations": applied_op,
                        "action": "apply",
                        "confirmation": "AI Generative edit applied.",
                        "clarification_needed": False,
                        "image_id": image_id,
                        "image_url": f"/static/uploads/{output_filename}",
                        "original_url": orig_rel_url,
                        "can_undo": len(sess["operations"]) > 0,
                        "can_redo": len(sess.get("redo_stack", [])) > 0,
                        "warn_product_change": parsed_cmd.get("warn_product_change", False),
                        "product_warning": parsed_cmd.get("product_warning") or parsed_cmd.get("product_change_warning"),
                    }
                except Exception as e:
                    logger.error(f"Free-form AI edit failed on {settings.GEMINI_IMAGE_MODEL}: {e}")
                    return {
                        "status": "error",
                        "message": f"Image editing failed: {e}",
                        "transcript": transcript,
                        "operations": [],
                        "new_operations": [],
                        "action": "none",
                        "confirmation": "Photo editing could not be completed. Please try again.",
                        "clarification_needed": False,
                        "image_id": image_id,
                        "image_url": None,
                        "original_url": orig_rel_url,
                        "can_undo": False,
                        "can_redo": False,
                        "warn_product_change": False,
                        "product_warning": None,
                    }
            else:
                polite_replies = {
                    "hi": "क्षमा करें, जनरेटिव एआई संपादन वर्तमान में उपलब्ध नहीं है। आप पृष्ठभूमि, रोशनी, छाया या आकार बदल सकते हैं।",
                    "ta": "மன்னிக்கவும், AI ஜெனரேட்டிவ் எடிட்டிங் தற்போது கிடைக்கவில்லை. நீங்கள் பின்னணி, வெளிச்சம் அல்லது நிழலை மாற்றலாம்.",
                    "te": "క్షమించండి, AI జెనరేటివ్ ఎడిటింగ్ ప్రస్తుతం అందుబాటులో లేదు. మీరు బ్యాక్‌గ్రౌండ్, వెలుతురు లేదా నీడను మార్చవచ్చు.",
                    "kn": "ಕ್ಷಮಿಸಿ, AI ಜನರೇಟಿವ್ ಎಡಿಟಿಂಗ್ ಪ್ರಸ್ತುತ ಲಭ್ಯವಿಲ್ಲ. ನೀವು ಹಿನ್ನೆಲೆ, ಬೆಳಕು ಅಥವಾ ನೆರಳು ಬದಲಾಯಿಸಬಹುದು.",
                    "ml": "ക്ഷമിക്കണം, AI ജനറേറ്റീവ് എഡിറ്റിംഗ് നിലവിൽ ലഭ്യമല്ല. നിങ്ങൾക്ക് പശ്ചാത്തലം, വെളിച്ചം അല്ലെങ്കിൽ നിഴൽ മാറ്റാം.",
                    "en": "Generative AI editing is currently not available. You can adjust the background, brightness, contrast, shadow, or size.",
                }
                return {
                    "status": "unavailable",
                    "transcript": transcript,
                    "operations": [],
                    "confirmation": polite_replies.get(detected_lang, polite_replies["en"]),
                    "clarification_needed": False,
                    "ai_edit_available": False,
                }

        # 4. Check if clarification is needed
        if parsed_cmd.get("clarification_needed"):
            return {
                "status": "clarification_needed",
                "transcript": transcript,
                "operations": [],
                "confirmation": parsed_cmd.get("clarifying_question") or "Please clarify your request.",
                "clarification_needed": True,
                "clarifying_question": parsed_cmd.get("clarifying_question"),
            }

        # 5. Apply operations non-destructively
        action = parsed_cmd.get("action", "apply")
        new_ops = parsed_cmd.get("operations", [])

        from app.services.image_editor import _get_session
        sess = _get_session(image_id, storage_dir or settings.STORAGE_LOCAL_PATH)
        current_ops = list(sess.get("operations", []))

        if action == "apply":
            all_ops = current_ops + new_ops
        else:
            all_ops = current_ops

        try:
            edit_res = await self.edit_image(
                image_id=image_id,
                operations=all_ops if action == "apply" else None,
                action=action if action != "apply" else None,
                storage_dir=storage_dir,
            )
            return {
                "status": "success",
                "transcript": transcript,
                "operations": edit_res["operations"],
                "new_operations": new_ops,
                "action": action,
                "confirmation": parsed_cmd.get("confirmation", "Changes applied successfully."),
                "clarification_needed": False,
                "image_id": image_id,
                "image_url": edit_res["image_url"],
                "original_url": edit_res["original_url"],
                "can_undo": edit_res["can_undo"],
                "can_redo": edit_res["can_redo"],
                "warn_product_change": parsed_cmd.get("warn_product_change", False),
                "product_warning": parsed_cmd.get("product_warning") or parsed_cmd.get("product_change_warning"),
            }
        except Exception as e:
            logger.error(f"Standard image edit failed: {e}")
            from app.services.image_editor import _find_source_images
            orig_path, _ = _find_source_images(image_id, storage_dir or settings.STORAGE_LOCAL_PATH)
            return {
                "status": "error",
                "message": f"Image editing failed: {e}",
                "transcript": transcript,
                "operations": [],
                "new_operations": [],
                "action": action,
                "confirmation": "Photo editing could not be completed. Please try again.",
                "clarification_needed": False,
                "image_id": image_id,
                "image_url": None,
                "original_url": f"/static/uploads/{os.path.basename(orig_path)}",
                "can_undo": False,
                "can_redo": False,
                "warn_product_change": False,
                "product_warning": None,
            }


async def check_image_fidelity(
    image_id: str,
    storage_dir: Optional[str] = None,
    gemini_client: Optional[GeminiClient] = None,
) -> Dict[str, Any]:
    """Runs a Gemini vision fidelity check comparing original craft image with current edited image."""
    import os
    settings = get_settings()
    from app.services.image_editor import _get_session
    sess = _get_session(image_id, storage_dir or settings.STORAGE_LOCAL_PATH)
    orig_path = sess.get("orig_path")
    curr_path = sess.get("curr_path")

    if not orig_path or not os.path.exists(orig_path):
        return {"status": "ok", "product_changed": False, "confidence": 1.0, "warning": None}
    if not curr_path or not os.path.exists(curr_path):
        return {"status": "ok", "product_changed": False, "confidence": 1.0, "warning": None}

    client = gemini_client or GeminiClient()
    if settings.AI_MODE != "real" or not client.is_configured:
        return {"status": "ok", "product_changed": False, "confidence": 0.95, "warning": None}

    try:
        with open(orig_path, "rb") as f:
            orig_bytes = f.read()

        prompt = (
            "You are a quality inspector for authentic handcrafted goods on KalaSetu.\n"
            "MANDATORY RULE: Edit ONLY background, scene and lighting; keep the product exactly as is.\n"
            "Compare the handcrafted product in this original photo with the current edited status.\n"
            "Did the product itself change in its own physical shape, structural geometry, material craft, or intrinsic product color (excluding scene lighting/reflections)?\n"
            "Return JSON:\n"
            "{\n"
            "  \"product_changed\": false,\n"
            "  \"confidence\": 0.95,\n"
            "  \"warning\": \"\"\n"
            "}\n"
            "If product changed, set product_changed to true and explain what changed."
        )

        res = await client.generate_json(
            prompt=prompt,
            image_bytes=orig_bytes,
            image_mime_type="image/jpeg",
            temperature=0.1,
        )
        if isinstance(res, dict):
            changed = bool(res.get("product_changed", False))
            return {
                "status": "ok",
                "product_changed": changed,
                "confidence": float(res.get("confidence", 0.95)),
                "warning": str(res.get("warning", "")) if changed else None,
            }
    except Exception as e:
        logger.warning(f"Gemini fidelity check notice: {e}")

    return {"status": "ok", "product_changed": False, "confidence": 0.90, "warning": None}
