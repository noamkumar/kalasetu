import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:frontend/core/services/local_tts_provider.dart';
import 'package:frontend/core/services/speech_text_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Device TTS voices and WPM measurements on actual Android device', () async {
    final flutterTts = FlutterTts();
    final provider = LocalTtsProvider(flutterTts: flutterTts);

    // 1. Query voices installed on this device
    try {
      final dynamic rawVoices = await flutterTts.getVoices;
      debugPrint('=== INSTALLED VOICES ON DEVICE ===');
      if (rawVoices is List) {
        debugPrint('Total voices found: ${rawVoices.length}');
        for (final lang in ['en', 'hi', 'te', 'ta', 'kn', 'ml']) {
          final best = await provider.findBestVoice(lang);
          debugPrint('Selected voice for $lang: ${best?['name']} (locale: ${best?['locale']})');
        }
      }
    } catch (e) {
      debugPrint('Error querying device voices: $e');
    }

    // 2. Measure actual speech duration and WPM on device
    final testSentences = [
      'Hello, how can I help you today?',
      'KalaSetu helps artisans sell their products throughout the year.',
      'Your suggested fair price is one thousand two hundred and fifty rupees.',
      'Take a photo of your product and I can help create a professional listing.',
    ];

    debugPrint('=== WPM MEASUREMENT ON DEVICE ===');
    for (final s in testSentences) {
      final wordCount = s.split(RegExp(r'\s+')).length;
      final sw = Stopwatch()..start();
      final completer = Completer<void>();

      flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });

      final spokenText = SpeechTextHelper.toSpeechFriendly(s, 'en');
      final started = await provider.speak(
        spokenText,
        'en',
        speechRate: 0.79,
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      if (started) {
        // Wait for completion or 10s max
        await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {});
        sw.stop();
        final durationSec = sw.elapsedMilliseconds / 1000.0;
        final wpm = (wordCount / durationSec) * 60.0;
        debugPrint('Sentence: "$s"');
        debugPrint('  Words: $wordCount | Duration: ${durationSec.toStringAsFixed(2)}s | Calculated WPM: ${wpm.toStringAsFixed(1)}');
      } else {
        debugPrint('Could not start local TTS for: $s');
      }
    }
  });
}
