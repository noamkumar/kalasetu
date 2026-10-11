import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/voice_service.dart';
import 'package:frontend/core/widgets/speaker_affordance.dart';
import 'package:frontend/features/kalamitra/services/kalamitra_faq_service.dart';
import 'package:frontend/features/kalamitra/services/kalamitra_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KalaMitra FAQ Six-Language Tests', () {
    late KalaMitraFaqService faqService;
    late KalaMitraService assistantService;

    setUp(() {
      faqService = KalaMitraFaqService();
      assistantService = KalaMitraService();
    });

    test('Creator Identity FAQ returns localized Noam answer across all 6 languages', () {
      final questions = {
        'en': 'Who made this app?',
        'hi': 'तुम्हें किसने बनाया?',
        'ta': 'உங்களை யார் உருவாக்கியது?',
        'te': 'నిన్ను ఎవరు తయారు చేశారు?',
        'kn': 'ನಿಮ್ಮನ್ನು ಯಾರು ಮಾಡಿದ್ದು?',
        'ml': 'നിങ്ങളെ ആരാണ് ഉണ്ടാക്കിയത്?',
      };

      for (final entry in questions.entries) {
        final lang = entry.key;
        final question = entry.value;

        // 1. Direct FaqService check
        final response = faqService.findAnswer(question, lang);
        expect(response, isNotNull, reason: 'Failed FAQ match for $lang: $question');
        expect(response!.reply.contains('Noam'), isTrue,
            reason: 'Creator reply for $lang should mention Noam: ${response.reply}');

        // 2. Offline fallback in KalaMitraService check
        final offlineResponse = assistantService.offlineFallback(question, 'home', lang);
        expect(offlineResponse.reply.contains('Noam'), isTrue,
            reason: 'Offline fallback for $lang should answer with creator: ${offlineResponse.reply}');
      }
    });

    test('Special About App FAQ returns localized Artisan AI answer across all 6 languages', () {
      final questions = {
        'en': 'What is special about this app?',
        'hi': 'इस ऐप में क्या खास है?',
        'ta': 'இந்த செயலியில் என்ன சிறப்பு?',
        'te': 'ఈ యాప్‌లో ఏమిటి ప్రత్యేకత?',
        'kn': 'ಈ ಆ್ಯಪ್‌ನಲ್ಲಿ ಏನು ವಿಶೇಷ?',
        'ml': 'ഈ ആപ്പിൽ എന്താണ് പ്രത്യേകത?',
      };

      for (final entry in questions.entries) {
        final lang = entry.key;
        final question = entry.value;

        // 1. Direct FaqService check
        final response = faqService.findAnswer(question, lang);
        expect(response, isNotNull, reason: 'Failed FAQ match for $lang: $question');
        expect(
          response!.reply.contains('Artisan AI') ||
              response.reply.contains('KalaSetu') ||
              response.reply.contains('कलासेतु') ||
              response.reply.contains('கலாசேது') ||
              response.reply.contains('కలాసేతు') ||
              response.reply.contains('ಕಲಾಸೇತು') ||
              response.reply.contains('കലാസേതു') ||
              response.reply.contains('ஆர்ட்டிசன்') ||
              response.reply.contains('ఆర్టిసన్') ||
              response.reply.contains('ಆರ್ಟಿಸನ್') ||
              response.reply.contains('ആർട്ടിസാൻ'),
          isTrue,
          reason: 'Special reply for $lang should describe KalaSetu / Artisan AI: ${response.reply}',
        );

        // 2. Offline fallback in KalaMitraService check
        final offlineResponse = assistantService.offlineFallback(question, 'home', lang);
        expect(offlineResponse.reply, equals(response.reply));
      }
    });

    test('Varied phrasing for creator identity matches properly', () {
      final variants = [
        'Who invented you?',
        'Who created KalaSetu?',
        'Who is your creator?',
        'Who developed this app?',
        'Tell me who made you',
      ];

      for (final v in variants) {
        final res = faqService.findAnswer(v, 'en');
        expect(res, isNotNull, reason: 'Should match variant: $v');
        expect(res!.reply, contains('Noam'));
      }
    });

    test('Varied phrasing for app special feature matches properly', () {
      final variants = [
        'Why should I use this app?',
        'What makes this app special?',
        'How does this app help artisans?',
        'Tell me what is special',
      ];

      for (final v in variants) {
        final res = faqService.findAnswer(v, 'en');
        expect(res, isNotNull, reason: 'Should match variant: $v');
        expect(res!.reply.contains('Artisan AI') || res.reply.contains('KalaSetu'), isTrue);
      }
    });

    test('Ecommerce Difference FAQ returns localized answer across all 6 languages', () {
      final questions = {
        'en': 'How are you different from Amazon?',
        'hi': 'अमेज़न से कैसे अलग है यह ऐप?',
        'ta': 'அமேசானிலிருந்து எவ்வாறு வேறுபடுகிறது?',
        'te': 'అమెజాన్ నుండి ఎలా భిన్నమైనది?',
        'kn': 'ಅಮೆಜಾನ್‌ಗಿಂತ ಹೇಗೆ ಭಿನ್ನ?',
        'ml': 'ആമസോണിൽ നിന്ന് എങ്ങനെ വ്യത്യസ്തമാണ്?',
      };

      for (final entry in questions.entries) {
        final lang = entry.key;
        final question = entry.value;

        // 1. Direct FaqService check
        final response = faqService.findAnswer(question, lang);
        expect(response, isNotNull, reason: 'Failed FAQ match for $lang: $question');
        expect(
          response!.reply.contains('KalaSetu') ||
              response.reply.contains('कलासेतु') ||
              response.reply.contains('கலாசேது') ||
              response.reply.contains('కలాసేతు') ||
              response.reply.contains('ಕಲಾಸೇತು') ||
              response.reply.contains('കലാസേതു'),
          isTrue,
          reason: 'Ecommerce difference reply for $lang should describe KalaSetu: ${response.reply}',
        );

        // 2. Offline fallback in KalaMitraService check
        final offlineResponse = assistantService.offlineFallback(question, 'home', lang);
        expect(offlineResponse.reply, equals(response.reply));
      }
    });

    test('Varied phrasing for e-commerce difference matches properly', () {
      final variants = [
        'How different from Amazon?',
        'How different from Flipkart?',
        'Why not Amazon?',
        'Why better than Amazon?',
        'Difference from normal marketplace',
      ];

      for (final v in variants) {
        final res = faqService.findAnswer(v, 'en');
        expect(res, isNotNull, reason: 'Should match variant: $v');
        expect(res!.reply, contains('KalaSetu'));
      }
    });

    test('General questions do not match fixed FAQ and return null', () {
      final generalQueries = [
        'What is Python?',
        'What is GST?',
        'How should I package a handmade craft?',
        'What is cotton fabric?',
        'How can I calculate profit margins?',
      ];

      for (final q in generalQueries) {
        final res = faqService.findAnswer(q, 'en');
        expect(res, isNull, reason: 'General query should not match FAQ: $q');
      }
    });
  });

  group('VoiceService Tests', () {
    test('computeVoiceHash generates deterministic SHA-256 hashes matching backend lowercase logic', () {
      final hash1 = VoiceService.computeVoiceHash('Hello world', 'en', 'kore');
      final hash2 = VoiceService.computeVoiceHash('  hello WORLD  ', 'EN', 'Kore');
      final hashDiffLang = VoiceService.computeVoiceHash('Hello world', 'hi', 'kore');

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
      expect(hash1, isNot(equals(hashDiffLang)));
    });

    test('VoiceService Indic locale mapping is correct for all 6 languages', () {
      final service = VoiceService.instance;
      expect(service.getLocaleForLanguage('en'), equals('en-GB'));
      expect(service.getLocaleForLanguage('hi'), equals('hi-IN'));
      expect(service.getLocaleForLanguage('ta'), equals('ta-IN'));
      expect(service.getLocaleForLanguage('te'), equals('te-IN'));
      expect(service.getLocaleForLanguage('kn'), equals('kn-IN'));
      expect(service.getLocaleForLanguage('ml'), equals('ml-IN'));
    });

    test('Fixed phrases list is populated for all 6 languages', () {
      for (final lang in ['en', 'hi', 'ta', 'te', 'kn', 'ml']) {
        final phrases = VoiceService.getFixedPhrasesForLang(lang);
        expect(phrases.length, greaterThanOrEqualTo(2),
            reason: 'Each language should have at least 2 fixed phrases (FAQ)');
        // Ensure creator and special answers are in the list
        expect(phrases.any((p) => p.contains('Noam')), isTrue);
      }
    });

    test('KalaMitraService.sendMessage intercepts FAQ questions locally before backend in all 6 languages', () async {
      final assistant = KalaMitraService();
      final questions = {
        'en': 'Who made this app?',
        'hi': 'तुम्हें किसने बनाया?',
        'ta': 'உங்களை யார் உருவாக்கியது?',
        'te': 'నిన్ను ఎవరు తయారు చేశారు?',
        'kn': 'ನಿಮ್ಮನ್ನು ಯಾರು ಮಾಡಿದ್ದು?',
        'ml': 'നിങ്ങളെ ആരാണ് ഉണ്ടാക്കിയത്?',
      };

      for (final entry in questions.entries) {
        final res = await assistant.sendMessage(
          message: entry.value,
          currentScreen: 'home',
          language: entry.key,
        );
        expect(res.reply, contains('Noam'));
        expect(res.action, equals('none'));
      }
    });
  });

  group('SpeakerAffordance Widget Tests', () {
    testWidgets('Renders idle state with volume icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeakerAffordance(
              label: 'Tap to hear',
              isPlaying: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(find.text('Tap to hear'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_rounded), findsNothing);
    });

    testWidgets('Renders active speaking state with Stop button and sound wave', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeakerAffordance(
              label: 'Tap to hear',
              isPlaying: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Stop'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('Compact SpeakerAffordance shows stop icon when playing', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeakerAffordance(
              isCompact: true,
              isPlaying: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_circle_rounded));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
