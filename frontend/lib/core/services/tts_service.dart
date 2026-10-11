import 'package:flutter/foundation.dart';
import 'voice_service.dart';

/// Legacy TTS compatibility wrapper that delegates directly to [VoiceService]
/// Section 2, 5.5 and 8 of Project Specification
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final VoiceService _voiceService = VoiceService.instance;

  bool get isPlaying => _voiceService.isPlaying;
  String? get currentlySpeaking => _voiceService.currentlySpeaking;

  /// Map language code to standard Indic locale string
  String getLocaleForLanguage(String langCode) =>
      _voiceService.getLocaleForLanguage(langCode);

  /// Speak text via VoiceService (natural voice backend + tuned offline TTS)
  Future<void> speak({
    required String text,
    required String languageCode,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    return _voiceService.speak(
      text: text,
      languageCode: languageCode,
      onStart: onStart,
      onComplete: onComplete,
    );
  }

  /// Stop ongoing speech
  Future<void> stop() {
    return _voiceService.stop();
  }
}
