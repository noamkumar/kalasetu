import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';
import 'audio_cache.dart';

/// KalaSetu Gemini TTS Fallback Provider
///
/// Calls backend POST /voice/speak to synthesize speech using Google Gemini Speech API.
/// Used when local Android TTS is unavailable, language voice is missing,
/// or high-quality online synthesis is explicitly required.
class GeminiTtsProvider {
  final ApiClient _apiClient;

  GeminiTtsProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches audio bytes from Gemini backend.
  /// Validates genuine WAV audio before returning.
  Future<Uint8List?> fetchSpeechAudio({
    required String text,
    required String languageCode,
    String voice = AudioCache.currentVersion,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return null;

    final reqSw = Stopwatch()..start();
    try {
      final response = await _apiClient.post(
        '/voice/speak',
        body: {
          'text': cleanText,
          'lang': languageCode,
          'voice': voice,
        },
      );
      final totalReqMs = reqSw.elapsedMilliseconds;

      if (response is Map<String, dynamic> && response['audio_base64'] != null) {
        final b64 = response['audio_base64'] as String;
        final audioBytes = base64Decode(b64);

        // Strict audio validation: genuine speech (>44 bytes, not the 32044-byte sine wave)
        if (audioBytes.length > 44 && audioBytes.length != 32044) {
          final headerStr = String.fromCharCodes(audioBytes.sublist(0, 12));
          if (headerStr.startsWith('RIFF') && headerStr.contains('WAVE')) {
            debugPrint('[GeminiTtsProvider] Received valid WAV audio (${audioBytes.length} bytes in ${totalReqMs}ms)');
            return audioBytes;
          } else {
            debugPrint('[GeminiTtsProvider] Invalid WAV header received from backend: $headerStr');
            return null;
          }
        } else {
          debugPrint('[GeminiTtsProvider] Corrupt or mock audio returned (${audioBytes.length} bytes)');
          return null;
        }
      }
    } catch (e) {
      debugPrint('[GeminiTtsProvider] Gemini TTS request failed or offline: $e');
    }
    return null;
  }
}
