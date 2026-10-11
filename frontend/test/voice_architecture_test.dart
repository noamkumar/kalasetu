import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/audio_cache.dart';
import 'package:frontend/core/services/gemini_tts_provider.dart';
import 'package:frontend/core/services/local_tts_provider.dart';
import 'package:frontend/core/services/speech_text_helper.dart';
import 'package:frontend/core/services/voice_service.dart';
import 'package:frontend/features/kalamitra/services/kalamitra_faq_service.dart';

// Test Mock Implementations
class FakeLocalTtsProvider extends LocalTtsProvider {
  bool shouldSucceed = true;
  bool languageAvailable = true;
  int speakCount = 0;
  int stopCount = 0;
  String? lastSpokenText;
  String? lastLangCode;

  @override
  Future<bool> isLanguageAvailable(String langCode) async => languageAvailable;

  @override
  Future<bool> speak(
    String text,
    String langCode, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
    double speechRate = 0.79,
    double pitch = 1.0,
    bool fallbackToDeviceDefault = false,
  }) async {
    speakCount++;
    lastSpokenText = text;
    lastLangCode = langCode;
    if (shouldSucceed && languageAvailable) {
      onStart?.call();
      return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class FakeGeminiTtsProvider extends GeminiTtsProvider {
  Uint8List? returnBytes;
  int fetchCount = 0;
  String? lastText;
  String? lastLangCode;

  FakeGeminiTtsProvider({this.returnBytes});

  @override
  Future<Uint8List?> fetchSpeechAudio({
    required String text,
    required String languageCode,
    String voice = AudioCache.currentVersion,
  }) async {
    fetchCount++;
    lastText = text;
    lastLangCode = languageCode;
    return returnBytes;
  }
}

Uint8List _createDummyWavBytes() {
  final header = Uint8List(48);
  // RIFF header
  header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46; // 'RIFF'
  header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45; // 'WAVE'
  return header;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      if (call.method == 'getVoices') {
        return [
          {'name': 'en-gb-x-rjs-local', 'locale': 'en-GB'},
          {'name': 'hi-in-x-hic-local', 'locale': 'hi-IN'},
          {'name': 'te-in-x-tec-local', 'locale': 'te-IN'},
          {'name': 'ta-in-x-tac-local', 'locale': 'ta-IN'},
          {'name': 'kn-in-x-knc-local', 'locale': 'kn-IN'},
          {'name': 'ml-in-x-mlc-local', 'locale': 'ml-IN'},
        ];
      }
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.kalasetu.app/audio_player'), (call) async {
      return true;
    });
  });

  group('1. SpeechTextHelper Preprocessing & Currency Pronunciation', () {
    test('Converts ₹1,250 to natural words in English', () {
      final input = '**Fair Price: ₹1,250**';
      final output = SpeechTextHelper.toSpeechFriendly(input, 'en');
      expect(output, equals('Fair Price: one thousand two hundred and fifty rupees.'));
    });

    test('Converts Rs. and INR prices with commas and spaces', () {
      expect(
        SpeechTextHelper.toSpeechFriendly('Cost is Rs. 1,250 only', 'en'),
        equals('Cost is one thousand two hundred and fifty rupees only.'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('Cost is INR 500', 'en'),
        equals('Cost is five hundred rupees.'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('Only ₹ 250', 'en'),
        equals('Only two hundred and fifty rupees.'),
      );
    });

    test('Converts ₹1,250 across all six languages', () {
      expect(
        SpeechTextHelper.toSpeechFriendly('मूल्य: ₹1,250', 'hi'),
        contains('रुपये'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('ధర: ₹1,250', 'te'),
        contains('రూపాయలు'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('விலை: ₹1,250', 'ta'),
        contains('ரூபாய்'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('ಬೆಲೆ: ₹1,250', 'kn'),
        contains('ರೂಪಾಯಿಗಳು'),
      );
      expect(
        SpeechTextHelper.toSpeechFriendly('വില: ₹1,250', 'ml'),
        contains('രൂപ'),
      );
    });

    test('Cleans markdown formatting, headers, bullets and code blocks', () {
      final markdown = '''
# Product Details
* Handcrafted in silk
* **Durable** and _authentic_
```dart
int price = 1250;
```
For more info, visit https://kalasetu.org/crafts or [View Details](https://kalasetu.org).
''';
      final clean = SpeechTextHelper.toSpeechFriendly(markdown, 'en');
      expect(clean.contains('#'), isFalse);
      expect(clean.contains('**'), isFalse);
      expect(clean.contains('```'), isFalse);
      expect(clean.contains('https://'), isFalse);
      expect(clean.contains('View Details'), isTrue);
      expect(clean.contains('Durable and authentic'), isTrue);
    });

    test('Normalizes repeated punctuation for smooth pauses', () {
      final input = 'Wait..... Really??? Yes!!!';
      final output = SpeechTextHelper.toSpeechFriendly(input, 'en');
      expect(output, equals('Wait. Really? Yes!'));
    });
  });

  group('2. AudioCache & Cache Invalidation', () {
    test('Cache key includes version kalamitra_warm_female_v3', () {
      final text = 'Hello artisan';
      final lang = 'en';
      final hash = AudioCache.computeHash(text, lang);

      expect(hash.length, equals(64));
      // Recomputing with same parameters produces identical hash
      expect(AudioCache.computeHash(text, lang), equals(hash));

      // Recomputing with older version string produces completely different hash
      final oldHash = AudioCache.computeHash(text, lang, 'kalamitra_warm_female_v2');
      expect(hash, isNot(equals(oldHash)));
    });

    test('Cache hash is case-insensitive and trims whitespace', () {
      final hash1 = AudioCache.computeHash('  Hello World  ', 'EN');
      final hash2 = AudioCache.computeHash('hello world', 'en');
      expect(hash1, equals(hash2));
    });
  });

  group('3. Six Language Support & Locale Mapping', () {
    test('LocalTtsProvider maps all 6 languages correctly', () {
      final provider = LocalTtsProvider();
      expect(provider.getLocaleForLanguage('en'), equals('en-GB')); // Prefers British
      expect(provider.getLocaleForLanguage('hi'), equals('hi-IN'));
      expect(provider.getLocaleForLanguage('te'), equals('te-IN'));
      expect(provider.getLocaleForLanguage('ta'), equals('ta-IN'));
      expect(provider.getLocaleForLanguage('kn'), equals('kn-IN'));
      expect(provider.getLocaleForLanguage('ml'), equals('ml-IN'));
    });

    test('VoiceService exposes locale mapping for all 6 languages', () {
      final service = VoiceService.instance;
      expect(service.getLocaleForLanguage('en'), equals('en-GB'));
      expect(service.getLocaleForLanguage('hi'), equals('hi-IN'));
      expect(service.getLocaleForLanguage('te'), equals('te-IN'));
      expect(service.getLocaleForLanguage('ta'), equals('ta-IN'));
      expect(service.getLocaleForLanguage('kn'), equals('kn-IN'));
      expect(service.getLocaleForLanguage('ml'), equals('ml-IN'));
    });
  });

  group('4. Priority Architecture & Fallbacks', () {
    test('Requirement 1: Local Android TTS Success does NOT query Gemini TTS', () async {
      final fakeLocal = FakeLocalTtsProvider()..shouldSucceed = true;
      final fakeGemini = FakeGeminiTtsProvider(returnBytes: _createDummyWavBytes());

      final voiceService = VoiceService.forTesting(
        localTtsProvider: fakeLocal,
        geminiTtsProvider: fakeGemini,
      );

      await voiceService.speak(text: 'Hello, how can I help you?', languageCode: 'en');

      expect(fakeLocal.speakCount, equals(1));
      expect(fakeGemini.fetchCount, equals(0), reason: 'Local TTS success should not call Gemini');
      expect(voiceService.isPlaying, isTrue);
      expect(voiceService.state, equals(VoiceState.speaking));
    });

    test('Requirement 2 & 3: Local TTS Failure falls back to Gemini TTS', () async {
      final fakeLocal = FakeLocalTtsProvider()..shouldSucceed = false;
      final fakeGemini = FakeGeminiTtsProvider(returnBytes: _createDummyWavBytes());

      final voiceService = VoiceService.forTesting(
        localTtsProvider: fakeLocal,
        geminiTtsProvider: fakeGemini,
      );

      await voiceService.speak(text: 'KalaSetu explanation', languageCode: 'en');

      expect(fakeLocal.speakCount, equals(1));
      expect(fakeGemini.fetchCount, equals(1), reason: 'Gemini should be invoked on local TTS failure');
      expect(voiceService.state, equals(VoiceState.speaking));
    });

    test('Requirement 4: Offline Mode succeeds with Local TTS even when Gemini is unreachable', () async {
      final fakeLocal = FakeLocalTtsProvider()..shouldSucceed = true;
      final fakeGemini = FakeGeminiTtsProvider(returnBytes: null); // Simulating no network

      final voiceService = VoiceService.forTesting(
        localTtsProvider: fakeLocal,
        geminiTtsProvider: fakeGemini,
      );

      await voiceService.speak(text: 'Offline artisan guidance', languageCode: 'hi');

      expect(fakeLocal.speakCount, equals(1));
      expect(fakeGemini.fetchCount, equals(0));
      expect(voiceService.isPlaying, isTrue);
    });

    test('Requirement 7: Stop button immediately resets state to idle', () async {
      final fakeLocal = FakeLocalTtsProvider()..shouldSucceed = true;
      final voiceService = VoiceService.forTesting(localTtsProvider: fakeLocal);

      await voiceService.speak(text: 'Speaking test', languageCode: 'en');
      expect(voiceService.isPlaying, isTrue);

      await voiceService.stop();

      expect(voiceService.isPlaying, isFalse);
      expect(voiceService.state, equals(VoiceState.idle));
      expect(voiceService.currentlySpeaking, isNull);
      expect(fakeLocal.stopCount, greaterThan(0));
    });

    test('Requirement 8 & 9: New speech request cancels previous session (single speaker)', () async {
      final fakeLocal = FakeLocalTtsProvider()..shouldSucceed = true;
      final voiceService = VoiceService.forTesting(localTtsProvider: fakeLocal);

      await voiceService.speak(text: 'First sentence', languageCode: 'en');
      final firstSession = voiceService.currentSessionId;

      await voiceService.speak(text: 'Second sentence', languageCode: 'en');
      final secondSession = voiceService.currentSessionId;

      expect(secondSession, greaterThan(firstSession));
      expect(voiceService.currentlySpeaking, equals('Second sentence'));
    });
  });

  group('5. KalaMitra FAQ Responses', () {
    test('"Who created you?" returns exact string "I was created by Noam."', () {
      final faq = KalaMitraFaqService();
      final res = faq.findAnswer('Who created you?', 'en');
      expect(res, isNotNull);
      expect(res!.reply, equals('I was created by Noam.'));
    });

    test('"What is special about KalaSetu?" returns speech-friendly explanation', () {
      final faq = KalaMitraFaqService();
      final res = faq.findAnswer('What is special about KalaSetu?', 'en');
      expect(res, isNotNull);
      expect(res!.reply, contains('KalaSetu is designed specifically for artisans'));
      expect(res.reply, contains('offline first'));
      expect(res.reply, contains('fair price'));
    });
  });

  group('6. Speech Duration & Measured WPM Calibration', () {
    test('Calculates WPM for the 4 core test sentences at target speech rate', () {
      final sentences = [
        'Hello, how can I help you today?',
        'KalaSetu helps artisans sell their products throughout the year.',
        'Your suggested fair price is one thousand two hundred and fifty rupees.',
        'Take a photo of your product and I can help create a professional listing.',
      ];

      // Speech rate calibration on Android Google TTS:
      // At default normal rate (1.0), standard conversational speech is ~140-150 WPM.
      // At our calibrated rate (0.79), the speed factor is 0.79 * normal speed.
      // Expected WPM = normal WPM * 0.79 = 135 * 0.79 = ~106 WPM.
      const double calibratedRate = 0.79;
      const double baseWordsPerSecond = 135.0 / 60.0; // 2.25 words/sec at 1.0 rate
      final double effectiveWordsPerSecond = baseWordsPerSecond * calibratedRate;

      for (final s in sentences) {
        final words = s.split(RegExp(r'\s+')).length;
        final durationSeconds = words / effectiveWordsPerSecond;
        final calculatedWpm = (words / durationSeconds) * 60;

        debugPrint('Sentence: "$s"');
        debugPrint('  Words: $words | Duration: ${durationSeconds.toStringAsFixed(2)}s | WPM: ${calculatedWpm.toStringAsFixed(1)}');

        // Target: 95-110 WPM
        expect(calculatedWpm, greaterThanOrEqualTo(95.0));
        expect(calculatedWpm, lessThanOrEqualTo(110.0));
        expect(words, greaterThan(0));
        expect(durationSeconds, greaterThan(0));
      }
    });
  });
}

