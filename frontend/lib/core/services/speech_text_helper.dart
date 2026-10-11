/// KalaSetu Speech Text Helper
///
/// Prepares text for natural speech synthesis without altering displayed UI text.
/// Converts currency (e.g. ₹1,250 -> "one thousand two hundred and fifty rupees")
/// across all six supported languages (English, Hindi, Telugu, Tamil, Kannada, Malayalam)
/// and cleans markdown, URLs, or disruptive characters for natural conversational pacing.
class SpeechTextHelper {
  /// Converts text into speech-friendly natural sentences for a given language.
  static String toSpeechFriendly(String text, String langCode) {
    if (text.isEmpty) return text;

    String result = text.trim();

    // 1. Remove code blocks (e.g. ```dart ... ```)
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 2. Strip inline code backticks `code`
    result = result.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!);

    // 3. Strip URLs (http://, https://, www.) so TTS doesn't spell out full web links
    result = result.replaceAll(RegExp(r'https?:\/\/\S+|www\.\S+'), '');

    // 4. Convert markdown links [Text](url) -> Text
    result = result.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);

    // 5. Strip markdown formatting: bold **text**, italic *text*, headers # Header, strikethrough ~~text~~
    result = result.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m[1]!);
    result = result.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1]!);
    result = result.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^[•\-\*]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), ''); // number list bullets "1. "

    // 6. Strip programming braces, brackets, and pipe symbols that disrupt speech
    result = result.replaceAll(RegExp(r'[{}\[\]<>]'), ' ');
    result = result.replaceAll(RegExp(r'\|'), ', ');

    // 7. Format Currency (₹ / Rs / INR) into natural spoken words BEFORE normalizing punctuation
    final normLang = langCode.toLowerCase().trim();
    result = _convertPrices(result, normLang);

    // 8. Natural conversational sentence line breaks:
    // If a line ends without terminal punctuation, ensure a period is added so sentences don't merge
    final lines = result.split('\n').map((l) {
      final trimmed = l.trim();
      if (trimmed.isEmpty) return '';
      if (!RegExp(r'[.!?:,]$').hasMatch(trimmed)) {
        return '$trimmed.';
      }
      return trimmed;
    }).where((l) => l.isNotEmpty);
    result = lines.join(' ');

    // 9. Normalize repeated punctuation for natural pauses without artificial gaps
    result = result.replaceAll(RegExp(r'\.{2,}'), '. ');
    result = result.replaceAll(RegExp(r'!{2,}'), '! ');
    result = result.replaceAll(RegExp(r'\?{2,}'), '? ');
    result = result.replaceAll(RegExp(r';'), ', ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }

  static String _convertPrices(String text, String lang) {
    // Regex matches ₹1,250 or ₹ 1250 or Rs. 1250 or INR 1250
    final priceRegex = RegExp(r'(?:₹|Rs\.?|INR)\s*([0-9]+(?:,[0-9]+)*)', caseSensitive: false);
    return text.replaceAllMapped(priceRegex, (match) {
      final rawNum = match.group(1)?.replaceAll(',', '') ?? '';
      final val = int.tryParse(rawNum);
      if (val == null) return match.group(0) ?? '';

      switch (lang) {
        case 'en':
          final words = _numberToEnglishWords(val);
          return words != null ? '$words rupees' : '$val rupees';
        case 'hi':
          final words = _numberToHindiWords(val);
          return words != null ? '$words रुपये' : '$val रुपये';
        case 'te':
          final words = _numberToTeluguWords(val);
          return words != null ? '$words రూపాయలు' : '$val రూపాయలు';
        case 'ta':
          final words = _numberToTamilWords(val);
          return words != null ? '$words ரூபாய்' : '$val ரூபாய்';
        case 'kn':
          final words = _numberToKannadaWords(val);
          return words != null ? '$words ರೂಪಾಯಿಗಳು' : '$val ರೂಪಾಯಿಗಳು';
        case 'ml':
          final words = _numberToMalayalamWords(val);
          return words != null ? '$words രൂപ' : '$val രൂപ';
        default:
          final words = _numberToEnglishWords(val);
          return words != null ? '$words rupees' : '$val rupees';
      }
    });
  }

  /// Converts numbers up to 999,999 into clear English words for natural pronunciation
  static String? _numberToEnglishWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'zero';

    final units = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    final tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        str += '${units[num ~/ 100]} hundred';
        num %= 100;
        if (num > 0) str += ' and ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = '${convertBelowThousand(thousands)} thousand';
      if (remainder == 0) return thousandsStr;
      if (remainder < 100) {
        return '$thousandsStr and ${convertBelowThousand(remainder)}';
      }
      return '$thousandsStr ${convertBelowThousand(remainder)}';
    }

    return convertBelowThousand(n);
  }

  /// Converts numbers up to 999,999 into natural Hindi spoken words
  static String? _numberToHindiWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'शून्य';

    // Direct mappings for frequent amounts
    final direct = {
      100: 'एक सौ',
      200: 'दो सौ',
      250: 'दो सौ पचास',
      300: 'तीन सौ',
      400: 'चार सौ',
      500: 'पांच सौ',
      600: 'छह सौ',
      700: 'सात सौ',
      750: 'सात सौ पचास',
      800: 'आठ सौ',
      900: 'नौ सौ',
      1000: 'एक हजार',
      1200: 'एक हजार दो सौ',
      1250: 'एक हजार दो सौ पचास',
      1500: 'एक हजार पांच सौ',
      2000: 'दो हजार',
      2500: 'दो हजार पांच सौ',
      3000: 'तीन हजार',
      5000: 'पांच हजार',
      10000: 'दस हजार',
      12500: 'बारह हजार पांच सौ',
      15000: 'पंद्रह हजार',
      20000: 'बीस हजार',
      25000: 'पच्चीस हजार',
      50000: 'पचास हजार',
    };
    if (direct.containsKey(n)) return direct[n];

    final units = [
      '', 'एक', 'दो', 'तीन', 'चार', 'पांच', 'छह', 'सात', 'आठ', 'नौ',
      'दस', 'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस'
    ];
    final tens = [
      '', '', 'बीस', 'तीस', 'चालीस', 'पचास', 'साठ', 'सत्तर', 'अस्सी', 'नब्बे'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        str += '${units[num ~/ 100]} सौ';
        num %= 100;
        if (num > 0) str += ' ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = '${convertBelowThousand(thousands)} हजार';
      if (remainder == 0) return thousandsStr;
      return '$thousandsStr ${convertBelowThousand(remainder)}'.trim();
    }

    return convertBelowThousand(n);
  }

  /// Converts numbers up to 999,999 into natural Telugu spoken words
  static String? _numberToTeluguWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'సున్నా';

    final direct = {
      100: 'వంద',
      200: 'రెండు వందలు',
      250: 'రెండు వందల యాభై',
      500: 'ఐదు వందలు',
      1000: 'వెయ్యి',
      1250: 'వెయ్యి రెండు వందల యాభై',
      1500: 'వెయ్యి ఐదు వందలు',
      2000: 'రెండు వేలు',
      2500: 'రెండు వేల ఐదు వందలు',
      5000: 'ఐదు వేలు',
      10000: 'పది వేలు',
    };
    if (direct.containsKey(n)) return direct[n];

    final units = [
      '', 'ఒకటి', 'రెండు', 'మూడు', 'నాలుగు', 'ఐదు', 'ఆరు', 'ఏడు', 'ఎనిమిది', 'తొమ్మిది',
      'పది', 'పదకొండు', 'పన్నెండు', 'పదమూడు', 'పద్నాలుగు', 'పదిహేను', 'పదహారు', 'పదిహేడు', 'పద్దెనిమిది', 'పంతొమ్మిది'
    ];
    final tens = [
      '', '', 'ఇరవై', 'ముప్పై', 'నలభై', 'యాభై', 'అరవై', 'డెబ్బై', 'ఎనభై', 'తొంభై'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        final h = num ~/ 100;
        str += (h == 1) ? 'వంద' : '${units[h]} వందలు';
        num %= 100;
        if (num > 0) str += ' ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = (thousands == 1) ? 'వెయ్యి' : '${units[thousands]} వేలు';
      if (remainder == 0) return thousandsStr;
      return '$thousandsStr ${convertBelowThousand(remainder)}'.trim();
    }

    return convertBelowThousand(n);
  }

  /// Converts numbers up to 999,999 into natural Tamil spoken words
  static String? _numberToTamilWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'பூஜ்ஜியம்';

    final direct = {
      100: 'நூறு',
      200: 'இருநூறு',
      250: 'இருநூற்று ஐம்பது',
      500: 'ஐந்நூறு',
      1000: 'ஆயிரம்',
      1250: 'ஆயிரத்து இருநூற்று ஐம்பது',
      1500: 'ஆயிரத்து ஐந்நூறு',
      2000: 'இரண்டாயிரம்',
      2500: 'இரண்டாயிரத்து ஐந்நூறு',
      5000: 'ஐந்தாயிரம்',
      10000: 'பத்தாயிரம்',
    };
    if (direct.containsKey(n)) return direct[n];

    final units = [
      '', 'ஒன்று', 'இரண்டு', 'மூன்று', 'நான்கு', 'ஐந்து', 'ஆறு', 'ஏழு', 'எட்டு', 'ஒன்பது',
      'பத்து', 'பதினொன்று', 'பன்னிரண்டு', 'பதின்மூன்று', 'பதினான்கு', 'பதினைந்து', 'பதினாறு', 'பதினேழு', 'பதினெட்டு', 'பத்தொன்பது'
    ];
    final tens = [
      '', '', 'இருபது', 'முப்பது', 'நாற்பது', 'ஐம்பது', 'அறுபது', 'எழுபது', 'எண்பது', 'தொண்ணூறு'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        final h = num ~/ 100;
        str += (h == 1) ? 'நூறு' : '${units[h]} நூறு';
        num %= 100;
        if (num > 0) str += ' ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = (thousands == 1) ? 'ஆயிரம்' : '${units[thousands]} ஆயிரம்';
      if (remainder == 0) return thousandsStr;
      return '$thousandsStr ${convertBelowThousand(remainder)}'.trim();
    }

    return convertBelowThousand(n);
  }

  /// Converts numbers up to 999,999 into natural Kannada spoken words
  static String? _numberToKannadaWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'ಶೂನ್ಯ';

    final direct = {
      100: 'ಒಂದು ನೂರು',
      200: 'ಇನ್ನೂರು',
      250: 'ಇನ್ನೂರ ಐವತ್ತು',
      500: 'ಐದು ನೂರು',
      1000: 'ಒಂದು ಸಾವಿರ',
      1250: 'ಒಂದು ಸಾವಿರದ ಇನ್ನೂರ ಐವತ್ತು',
      1500: 'ಒಂದು ಸಾವಿರದ ಐದು ನೂರು',
      2000: 'ಎರಡು ಸಾವಿರ',
      2500: 'ಎರಡು ಸಾವಿರದ ಐದು ನೂರು',
      5000: 'ಐದು ಸಾವಿರ',
      10000: 'ಹತ್ತು ಸಾವಿರ',
    };
    if (direct.containsKey(n)) return direct[n];

    final units = [
      '', 'ಒಂದು', 'ಎರಡು', 'ಮೂರು', 'ನಾಲ್ಕು', 'ಐದು', 'ಆರು', 'ಏಳು', 'ಎಂಟು', 'ಒಂಬತ್ತು',
      'ಹತ್ತು', 'ಹನ್ನೊಂದು', 'ಹನ್ನೆರಡು', 'ಹದಿಮೂರು', 'ಹದಿನಾಲ್ಕು', 'ಹದಿನೈದು', 'ಹದಿನಾರು', 'ಹದಿನೇಳು', 'ಹದಿನೆಂಟು', 'ಹತ್ತೊಂಬತ್ತು'
    ];
    final tens = [
      '', '', 'ಇಪ್ಪತ್ತು', 'ಮೂವತ್ತು', 'ನಲವತ್ತು', 'ಐವತ್ತು', 'ಅರವತ್ತು', 'ಎಪ್ಪತ್ತು', 'ಎಂಬತ್ತು', 'ತೊಂಬತ್ತು'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        final h = num ~/ 100;
        str += (h == 1) ? 'ನೂರು' : '${units[h]} ನೂರು';
        num %= 100;
        if (num > 0) str += ' ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = (thousands == 1) ? 'ಒಂದು ಸಾವಿರ' : '${units[thousands]} ಸಾವಿರ';
      if (remainder == 0) return thousandsStr;
      return '$thousandsStr ${convertBelowThousand(remainder)}'.trim();
    }

    return convertBelowThousand(n);
  }

  /// Converts numbers up to 999,999 into natural Malayalam spoken words
  static String? _numberToMalayalamWords(int n) {
    if (n < 0 || n > 999999) return null;
    if (n == 0) return 'പൂജ്യം';

    final direct = {
      100: 'നൂറ്',
      200: 'ഇരുനൂറ്',
      250: 'ഇരുന്നൂറ്റി അൻപത്',
      500: 'അഞ്ഞൂറ്',
      1000: 'ആയിരം',
      1250: 'ആയിരത്തി ഇരുന്നൂറ്റി അൻപത്',
      1500: 'ആയിരത്തി അഞ്ഞൂറ്',
      2000: 'രണ്ടായിരം',
      2500: 'രണ്ടായിരത്തി അഞ്ഞൂറ്',
      5000: 'അയ്യായിരം',
      10000: 'പതിനായിരം',
    };
    if (direct.containsKey(n)) return direct[n];

    final units = [
      '', 'ഒന്ന്', 'രണ്ട്', 'മൂന്ന്', 'നാല്', 'അഞ്ച്', 'ആറ്', 'ഏഴ്', 'എട്ട്', 'ഒൻപത്',
      'പത്ത്', 'പതിനൊന്ന്', 'പന്ത്രണ്ട്', 'പതിമൂന്ന്', 'പതിനാല്', 'പതിനഞ്ച്', 'പതിനാറ്', 'പതിനേഴ്', 'പതിനെട്ട്', 'പത്തൊൻപത്'
    ];
    final tens = [
      '', '', 'ഇരുപത്', 'മുപ്പത്', 'നാൽപ്പത്', 'അൻപത്', 'അറുപത്', 'എഴുപത്', 'എൺപത്', 'തൊണ്ണൂറ്'
    ];

    String convertBelowThousand(int num) {
      String str = '';
      if (num >= 100) {
        final h = num ~/ 100;
        str += (h == 1) ? 'നൂറ്' : '${units[h]} നൂറ്';
        num %= 100;
        if (num > 0) str += ' ';
      }
      if (num >= 20) {
        str += tens[num ~/ 10];
        final rem = num % 10;
        if (rem > 0) str += ' ${units[rem]}';
      } else if (num > 0) {
        str += units[num];
      }
      return str.trim();
    }

    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final remainder = n % 1000;
      final thousandsStr = (thousands == 1) ? 'ആയിരം' : '${units[thousands]} ആയിരം';
      if (remainder == 0) return thousandsStr;
      return '$thousandsStr ${convertBelowThousand(remainder)}'.trim();
    }

    return convertBelowThousand(n);
  }
}
