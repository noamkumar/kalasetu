import 'dart:convert';
import 'package:flutter/services.dart';
import 'kalamitra_service.dart';

/// Localized FAQ Service for KalaMitra
/// Specification Task: Natural voice & KalaMitra identity answers
/// Checks localized FAQ in assets (six languages) BEFORE calling LLM
class KalaMitraFaqService {
  static final KalaMitraFaqService _instance = KalaMitraFaqService._internal();
  factory KalaMitraFaqService() => _instance;
  KalaMitraFaqService._internal();

  bool _isLoaded = false;
  Map<String, dynamic>? _faqData;

  static const Map<String, String> _defaultCreatorAnswers = {
    'en': 'I was created by Noam.',
    'hi': 'मुझे नोम (Noam) ने बनाया है। मैं कलामित्र हूँ, कलासेतु के लिए आपका सहायक।',
    'ta': 'நான் நோம் (Noam) அவர்களால் உருவாக்கப்பட்டேன். நான் கலாமித்ரா, உங்கள் கலாசேது உதவியாளர்.',
    'te': 'నేను నోమ్ (Noam) ద్వారా సృష్టించబడ్డాను. నేను కలామిత్రను, కలాసేతు కోసం మీ సహాయకుడిని.',
    'kn': 'ನನ್ನನ್ನು ನೋಮ್ (Noam) ರಚಿಸಿದ್ದಾರೆ. ನಾನು ಕಲಾವಿತ್ರ, ಕಲಾಸೇತುಗೆ ನಿಮ್ಮ ಸಹಾಯಕ.',
    'ml': 'എന്നെ നോം (Noam) ആണ് സൃഷ്ടിച്ചത്. ഞാൻ കലാമിത്ര, കലാസേതുവിനായുള്ള നിങ്ങളുടെ സഹായി.',
  };

  static const Map<String, String> _defaultSpecialAnswers = {
    'en': 'KalaSetu is designed specifically for artisans. You can take a photo of your product and KalaSetu can improve the image. You can describe your product by speaking in your own language. KalaSetu can create a professional listing in multiple languages. It can suggest a fair price based on your costs and should never recommend selling below your basic cost. It also helps artisans reach customers throughout the year instead of depending only on occasional fairs. And because KalaSetu is designed to work offline first, it can remain useful even when internet connectivity is limited.',
    'hi': 'कलासेतु विशेष रूप से कारीगरों के लिए डिज़ाइन किया गया है। आप अपने उत्पाद की फोटो ले सकते हैं और कलासेतु छवि को बेहतर बना सकता है। आप अपनी भाषा में बोलकर उत्पाद का विवरण दे सकते हैं। कलासेतु कई भाषाओं में एक पेशेवर लिस्टिंग बना सकता है। यह आपकी लागत के आधार पर उचित मूल्य सुझा सकता है और कभी भी बुनियादी लागत से कम बेचने की सलाह नहीं देता। यह कारीगरों को पूरे वर्ष ग्राहकों तक पहुँचने में मदद करता है। और कलासेतु ऑफ़लाइन-प्रथम काम करने के लिए डिज़ाइन किया गया है, इसलिए इंटरनेट सीमित होने पर भी यह उपयोगी रहता है।',
    'ta': 'கலாசேது குறிப்பாகக் கைவினைஞர்களுக்காக வடிவமைக்கப்பட்டுள்ளது. உங்கள் தயாரிப்பைப் புகைப்படம் எடுத்தால் கலாசேது அதை மெருகேற்றும். உங்கள் தாய்மொழியில் பேசி தயாரிப்பை விவரிக்கலாம். கலாசேது பல மொழிகளில் தொழில்முறைப் பட்டியலை உருவாக்கும். உங்கள் அடக்க விலையின் அடிப்படையில் நியாயமான விலையைப் பரிந்துரைக்கும், அடக்க விலைக்குக் கீழ் விற்க ஒருபோதும் பரிந்துரைக்காது. திருவிழாக்களை மட்டுமே சார்ந்திருக்காமல் ஆண்டு முழுவதும் வாடிக்கையாளர்களை அடைய உதவும். மேலும் இது ஆஃப்லைனிலும் சிறப்பாகச் செயல்படும்.',
    'te': 'కలాసేతు ప్రత్యేకంగా చేతివృత్తుల కళాకారుల కోసం రూపొందించబడింది. మీరు మీ ఉత్పత్తి ఫోటో తీయవచ్చు, కలాసేతు ఆ చిత్రాన్ని మెరుగుపరుస్తుంది. మీ స్వంత భాషలో మాట్లాడి వివరించవచ్చు. కలాసేతు బహుళ భాషల్లో ప్రొఫెషనల్ లిస్టింగ్ తయారు చేస్తుంది. మీ ఖర్చుల ఆధారంగా న్యాయమైన ధరను సూచిస్తుంది. ఏడాది పొడవునా వినియోగదారులను చేరుకోవడానికి సహాయపడుతుంది. మరియు ఇది ఆఫ్‌లైన్‌లోనూ పనిచేస్తుంది.',
    'kn': 'ಕಲಾಸೇತು ವಿಶೇಷವಾಗಿ ಕರಕುಶಲಕರ್ಮಿಗಳಿಗಾಗಿ ವಿನ್ಯಾಸಗೊಳಿಸಲಾಗಿದೆ. ನಿಮ್ಮ ಉತ್ಪನ್ನದ ಫೋಟೋ ತೆಗೆದರೆ ಕಲಾಸೇತು ಚಿತ್ರವನ್ನು ಸುಧಾರಿಸುತ್ತದೆ. ನಿಮ್ಮ ಭಾಷೆಯಲ್ಲೇ ಮಾತನಾಡಿ ವಿವರಿಸಬಹುದು. ಕಲಾಸೇತು ಹಲವು ಭಾಷೆಗಳಲ್ಲಿ ಪಟ್ಟಿಯನ್ನು ಸಿದ್ಧಪಡಿಸುತ್ತದೆ. ನಿಮ್ಮ ವೆಚ್ಚದ ಆಧಾರದ ಮೇಲೆ ನ್ಯಾಯಯುತ ಬೆಲೆಯನ್ನು ಸೂಚಿಸುತ್ತದೆ. ವರ್ಷವಿಡೀ ಗ್ರಾಹಕರನ್ನು ತಲುಪಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ ಮತ್ತು ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಕಾರ್ಯನಿರ್ವಹಿಸುತ್ತದೆ.',
    'ml': 'കലാസേതു കരകൗശല വിദഗ്ദ്ധർക്കായി പ്രത്യേകം രൂപകൽപ്പന ചെയ്തിട്ടുള്ളതാണ്. ഉൽപ്പന്നത്തിന്റെ ഫോട്ടോ എടുത്താൽ കലാസേതു അത് മെച്ചപ്പെടുത്തും. സ്വന്തം ഭാഷയിൽ സംസാരിച്ച് വിവരണം നൽകാം. ഒന്നിലധികം ഭാഷകളിൽ പ്രൊഫഷണൽ ലിസ്റ്റിംഗ് സൃഷ്ടിക്കും. ചെലവുകളുടെ അടിസ്ഥാനത്തിൽ ന്യായവില നിർദ്ദേശിക്കും. വർഷം മുഴുവൻ ഉപഭോക്താക്കളിലേക്ക് എത്താൻ സഹായിക്കുകയും ഇന്റർനെറ്റ് ഇല്ലാതെ പ്രവർത്തിക്കുകയും ചെയ്യും.',
  };

  static const Map<String, String> _defaultEcommerceDiffAnswers = {
    'en': 'KalaSetu is not an ordinary marketplace; it is your AI virtual business manager. Unlike regular e-commerce that requires typing, pro cameras, and English, KalaSetu lets you simply snap a photo to polish it, speak in your own language to create listings, guarantees prices never fall below your cost floor, and works completely offline.',
    'hi': 'कलासेतु कोई साधारण बाज़ार नहीं, बल्कि कारीगरों का एआई वर्चुअल बिज़नेस मैनेजर है। सामान्य ई-कॉमर्स के विपरीत जहाँ टाइपिंग, अंग्रेज़ी और स्टूडियो कैमरों की ज़रूरत होती है, कलासेतु में आप सिर्फ शिल्प की फोटो लेकर उसे निखार सकते हैं, अपनी भाषा में बोलकर लिस्टिंग बना सकते हैं, लागत से कम न होने वाला उचित मूल्य पा सकते हैं और बिना इंटरनेट भी काम कर सकते हैं।',
    'ta': 'கலாசேது ஒரு சாதாரண சந்தை அல்ல; இது கைவினைஞர்களுக்கான AI வணிக மேலாளர். தட்டச்சு, ஆங்கிலம் மற்றும் ஸ்டுடியோ கேமராக்கள் தேவைப்படும் வழக்கமான இ-காமர்ஸ் போலல்லாமல், கலாசேதுவில் ஒரு புகைப்படம் எடுத்து அதை மெருகூட்டலாம், உங்கள் தாய்மொழியில் பேசி விவரக்குறிப்பை உருவாக்கலாம், அடக்க விலைக்குக் குறையாத நியாயமான விலையைப் பெறலாம், மேலும் இணையம் இல்லாமலும் பயன்படுத்தலாம்.',
    'te': 'కలాసేతు కేవలం సాధారణ మార్కెట్ కాదు; ఇది చేతివృత్తుల వారి కోసం AI వర్చువల్ బిజినెస్ మేనేజర్. ఇంగ్లీష్, టైపింగ్ మరియు స్టూడియో కెమెరాలు అవసరమయ్యే సాధారణ ఇ-కామర్స్ వలె కాకుండా, కలాసేతులో మీరు కేవలం ఫోటో తీసి దాన్ని మెరుగుపరచవచ్చు, మీ స్వంత భాషలో మాట్లాడి కేటలాగ్ సృష్టించవచ్చు, ఖర్చు కంటే తగ్గని న్యాయమైన ధరను పొందవచ్చు మరియు ఆఫ్‌లైన్‌లోనూ పనిచేయవచ్చు.',
    'kn': 'ಕಲಾಸೇತು ಕೇವಲ ಸಾಮಾನ್ಯ ಮಾರುಕಟ್ಟೆಯಲ್ಲ; ಇದು ಕರಕುಶಲಕರ್ಮಿಗಳ AI ವರ್ಚುವಲ್ ವ್ಯವಹಾರ ವ್ಯವಸ್ಥಾಪಕ. ಟೈಪಿಂಗ್, ಇಂಗ್ಲಿಷ್ ಮತ್ತು ಸ್ಟುಡಿಯೋ ಕ್ಯಾಮೆರಾಗಳ ಅಗತ್ಯವಿರುವ ಸಾಮಾನ್ಯ ಇ-ಕಾಮರ್ಸ್‌ಗಿಂತ ಭಿನ್ನವಾಗಿ, ಕಲಾಸೇತುನಲ್ಲಿ ಕೇವಲ ಫೋಟೋ ತೆಗೆದು ಅದನ್ನು ಸುಧಾರಿಸಬಹುದು, ನಿಮ್ಮ ಮಾತೃಭಾಷೆಯಲ್ಲೇ ಮಾತನಾಡಿ ಪಟ್ಟಿಯನ್ನು ರಚಿಸಬಹುದು, ವೆಚ್ಚಕ್ಕಿಂತ ಕಡಿಮೆಯಾಗದ ನ್ಯಾಯಯುತ ಬೆಲೆ ಪಡೆಯಬಹುದು ಮತ್ತು ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಬಳಸಬಹುದು.',
    'ml': 'കലാസേതു ഒരു സാധാരണ വിപണിയല്ല; ഇത് കരകൗശല വിദഗ്ദ്ധർക്കായുള്ള ഒരു AI വെർച്വൽ ബിസിനസ്സ് മാനേജറാണ്. ടൈപ്പിംഗും ഇംഗ്ലീഷും സ്റ്റുഡിയോ ക്യാമറകളും ആവശ്യമായ സാധാരണ ഇ-കൊമേഴ്‌സിൽ നിന്ന് വ്യത്യസ്തമായി, കലാസേതുവിൽ ഒരു ഫോട്ടോ എടുത്ത് അത് മെച്ചപ്പെടുത്താനും, സ്വന്തം ഭാഷയിൽ സംസാരിച്ച് ലിസ്റ്റിംഗ് തയ്യാറാക്കാനും, ചെലവിനേക്കാൾ താഴെ പോകാത്ത ന്യായവില ഉറപ്പാക്കാനും, ഇന്റർനെറ്റ് ഇല്ലാതെയും ഉപയോഗിക്കാനും സാധിക്കും.',
  };

  static const List<String> _creatorKeywordsAll = [
    'who made you', 'who made this app', 'who created you', 'who created this app',
    'who invented you', 'who invented this app', 'who developed you', 'who developed this app',
    'who built you', 'who built this app', 'who is your creator', 'who designed you',
    'who created kalasetu', 'who made kalamitra', 'who developed kalamitra',
    'who is behind this app', 'made by whom', 'created by whom', 'noam',
    'किसने बनाया', 'कौन बनाया', 'निर्माता कौन', 'किसने आविष्कार', 'बनाने वाला',
    'யார் உருவாக்கியது', 'யார் படைத்தது', 'யார் கண்டுபிடித்தது', 'உருவாக்கியவர் யார்',
    'ఎవరు తయారు చేశారు', 'ఎవరు సృష్టించారు', 'ఎవరు కనిపెట్టారు', 'సృష్టికర్త ఎవరు',
    'ಯಾರು ಮಾಡಿದ್ದು', 'ಯಾರು ಸೃಷ್ಟಿಸಿದರು', 'ಯಾರು ರಚಿಸಿದರು', 'ಯಾರು ಕಂಡುಹಿಡಿದರು',
    'ആരാണ് ഉണ്ടാക്കിയത്', 'ആരാണ് സൃഷ്ടിച്ചത്', 'ആരാണ് നിർമ്മിച്ചത്',
  ];

  static const List<String> _ecommerceDiffKeywordsAll = [
    'how different from amazon', 'how different from flipkart', 'different from amazon',
    'different from flipkart', 'how are you different from amazon', 'how are you different from flipkart',
    'how is this different from amazon', 'how is this different from flipkart',
    'different from normal ecommerce', 'different from other apps', 'different from ecommerce',
    'why not amazon', 'why not flipkart', 'difference from amazon', 'difference from flipkart',
    'why better than amazon', 'why better than flipkart', 'difference from normal marketplace',
    'अमेज़न से कैसे अलग', 'फ्लिपकार्ट से कैसे अलग', 'अन्य ई-कॉमर्स से अलग', 'सामान्य ई-कॉमर्स से अलग',
    'अमेजन से अलग', 'फ्लिपकार्ट से अलग', 'बाकी ऐप से अलग',
    'அமேசானிலிருந்து எவ்வாறு வேறுபடுகிறது', 'பிளிப்கார்ட்டிலிருந்து வேறுபாடு', 'மற்ற இ-காமர்ஸ்',
    'அமேசானை விட எப்படி சிறந்தது', 'வழக்கமான வர்த்தகத்தில் இருந்து வேறுபாடு',
    'అమెజాన్ నుండి ఎలా భిన్నమైనది', 'ఫ్లిప్‌కార్ట్ నుండి భిన్నం', 'సాధారణ ఇ-కామర్స్ కంటే భిన్నం',
    'ఇతర యాప్‌ల కంటే భిన్నం', 'అమెజాన్ కంటే ఎలా భిన్నం',
    'ಅಮೆಜಾನ್‌ಗಿಂತ ಹೇಗೆ ಭಿನ್ನ', 'ಫ್ಲಿಪ್‌ಕಾರ್ಟ್‌ಗಿಂತ ಹೇಗೆ ಭಿನ್ನ', 'ಇತರೆ ಇ-ಕಾಮರ್ಸ್‌ಗಿಂತ ಭಿನ್ನ',
    'ಸಾಮಾನ್ಯ ಮಾರುಕಟ್ಟೆಗಿಂತ ಭಿನ್ನ',
    'ആമസോണിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തമാണ്', 'ഫ്ലിപ്കാർട്ടിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തമാണ്',
    'മറ്റ് ഇ-കൊമേഴ്‌സിൽ നിന്ന് വ്യത്യാസം', 'സാധാരണ ഇ-കൊമേഴ്‌സിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തം',
  ];

  static const List<String> _specialKeywordsAll = [
    'what is special', 'what is special about this app', 'special about this app', 'why this app',
    'why artisan ai', 'what makes this app special', 'how does this app help',
    'what does this app do', 'special feature of this app', 'why should i use this app',
    'why kalasetu', 'what is kalasetu', 'about this app', 'what can this app do for me',
    'what is unique about kalasetu', 'what is unique about this app', 'why is this better for artisans',
    'इस ऐप में क्या खास है', 'क्या खासियत है', 'यह ऐप क्या करता है', 'इस ऐप की विशेषता',
    'क्यों इस्तेमाल करें', 'यह कैसे मदद करता है', 'कलासेतु क्या है', 'कारीगरों के लिए क्या खास',
    'இந்த செயலியில் என்ன சிறப்பு', 'இந்த பயன்பாட்டில் என்ன சிறப்பு', 'என்ன சிறப்பம்சம்', 'என்ன சிறப்பு', 'இந்த ஆப் என்ன செய்கிறது',
    'எப்படி உதவுகிறது', 'கலாசேது என்றால் என்ன', 'கைவினைஞர்களுக்கு என்ன பயன்',
    'ఈ యాప్‌లో ఏమిటి ప్రత్యేకత', 'ఈ యాప్‌లో ప్రత్యేకత ఏమిటి', 'ఈ యాప్‌లో ప్రత్యేకతలు', 'ఈ యాప్ ఏమి చేస్తుంది',
    'ఎలా సహాయపడుతుంది', 'కలాసేతు అంటే ఏమిటి', 'చేతివృత్తుల వారికి ఏమిటి ప్రయోజనం',
    'ಈ ಆ್ಯಪ್‌ನಲ್ಲಿ ಏನು ವಿಶೇಷ', 'ವಿಶೇಷತೆ ಏನು', 'ಈ ಆ್ಯಪ್ ಏನು ಮಾಡುತ್ತದೆ',
    'ಹೇಗೆ ಸಹಾಯ ಮಾಡುತ್ತದೆ', 'ಕಲಾಸೇತು ಎಂದರೇನು', 'ಕರಕುಶಲಕರ್ಮಿಗಳಿಗೆ ಏನು ಪ್ರಯೋಜನ',
    'ഈ ആപ്പിൽ എന്താണ് പ്രത്യേകത', 'പ്രത്യേകത എന്താണ്', 'ഈ ആപ്പ് എന്താണ് ചെയ്യുന്നത്',
    'എങ്ങനെ സഹായിക്കുന്നു', 'കലാസേതു എന്നാൽ എന്താണ്', 'കരകൗശലക്കാർക്ക് എന്ത് ഗുണം',
  ];

  Future<void> ensureLoaded() async {
    if (_isLoaded && _faqData != null) return;
    await loadFaq();
  }

  Future<void> loadFaq() async {
    if (_isLoaded && _faqData != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/faq/kalamitra_faq.json');
      _faqData = json.decode(jsonString) as Map<String, dynamic>;
      _isLoaded = true;
    } catch (_) {
      // In tests or offline environments without Flutter asset bundle, use embedded fallback
      _isLoaded = true;
    }
  }

  /// Checks specifically if message matches Creator identity intent
  KalaMitraResponse? findCreatorAnswer(String message, String langCode) {
    final lower = message.toLowerCase().trim();
    final normLang = _normalizeLang(langCode);
    if (_matchesKeywords(lower, 'creator_identity', _creatorKeywordsAll, normLang)) {
      final reply = _getFaqAnswer('creator_identity', normLang, _defaultCreatorAnswers);
      return KalaMitraResponse(
        reply: reply,
        action: 'none',
        suggestions: ['What is special about KalaSetu?', 'Why use KalaSetu instead of Amazon?', 'Add Product'],
      );
    }
    return null;
  }

  /// Checks if message matches fixed FAQ before calling LLM
  KalaMitraResponse? findAnswer(String message, String langCode) {
    final lower = message.toLowerCase().trim();
    final normLang = _normalizeLang(langCode);

    // 1. Check Creator identity intent
    if (_matchesKeywords(lower, 'creator_identity', _creatorKeywordsAll, normLang)) {
      final reply = _getFaqAnswer('creator_identity', normLang, _defaultCreatorAnswers);
      return KalaMitraResponse(
        reply: reply,
        action: 'none',
        suggestions: ['What is special about this app?', 'How different from Amazon?', 'Add Product'],
      );
    }

    // 2. Check E-commerce Difference intent (Amazon / Flipkart / marketplace differentiation)
    if (_matchesKeywords(lower, 'ecommerce_difference', _ecommerceDiffKeywordsAll, normLang)) {
      final reply = _getFaqAnswer('ecommerce_difference', normLang, _defaultEcommerceDiffAnswers);
      return KalaMitraResponse(
        reply: reply,
        action: 'none',
        suggestions: ['What is special about this app?', 'Check Fair Pricing', 'Take craft photo'],
      );
    }

    // 3. Check App Special intent
    if (_matchesKeywords(lower, 'app_special', _specialKeywordsAll, normLang)) {
      final reply = _getFaqAnswer('app_special', normLang, _defaultSpecialAnswers);
      return KalaMitraResponse(
        reply: reply,
        action: 'none',
        suggestions: ['How different from Amazon?', 'Take craft photo', 'Who created you?'],
      );
    }

    return null;
  }

  bool _matchesKeywords(
    String message,
    String faqId,
    List<String> defaultKeywords,
    String lang,
  ) {
    if (_faqData != null && _faqData!['faq'] is List) {
      final faqs = _faqData!['faq'] as List;
      for (final item in faqs) {
        if (item is Map && item['id'] == faqId) {
          final kwMap = item['keywords'];
          if (kwMap is Map) {
            final langList = kwMap[lang] as List?;
            if (langList != null) {
              for (final k in langList) {
                if (message.contains(k.toString().toLowerCase())) return true;
              }
            }
            final enList = kwMap['en'] as List?;
            if (enList != null) {
              for (final k in enList) {
                if (message.contains(k.toString().toLowerCase())) return true;
              }
            }
          }
        }
      }
    }

    // Fallback to in-memory keyword list
    return defaultKeywords.any((k) => message.contains(k.toLowerCase()));
  }

  String _getFaqAnswer(
    String faqId,
    String lang,
    Map<String, String> defaultAnswers,
  ) {
    if (_faqData != null && _faqData!['faq'] is List) {
      final faqs = _faqData!['faq'] as List;
      for (final item in faqs) {
        if (item is Map && item['id'] == faqId) {
          final ansMap = item['answers'];
          if (ansMap is Map) {
            final ans = ansMap[lang]?.toString() ?? ansMap['en']?.toString();
            if (ans != null && ans.isNotEmpty) return ans;
          }
        }
      }
    }
    return defaultAnswers[lang] ?? defaultAnswers['en']!;
  }

  String getSpecialAnswer(String langCode) {
    return _getFaqAnswer('app_special', _normalizeLang(langCode), _defaultSpecialAnswers);
  }

  String getEcommerceDiffAnswer(String langCode) {
    return _getFaqAnswer('ecommerce_difference', _normalizeLang(langCode), _defaultEcommerceDiffAnswers);
  }

  String getCreatorAnswer(String langCode) {
    return _getFaqAnswer('creator_identity', _normalizeLang(langCode), _defaultCreatorAnswers);
  }

  String _normalizeLang(String lang) {
    final lower = lang.toLowerCase();
    if (const ['en', 'hi', 'ta', 'te', 'kn', 'ml'].contains(lower)) {
      return lower;
    }
    return 'en';
  }
}
