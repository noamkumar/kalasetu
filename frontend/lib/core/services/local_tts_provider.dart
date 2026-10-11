import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// KalaSetu Local Android TTS Provider
///
/// Implements offline-first speech synthesis using native device TTS (via flutter_tts).
/// Supports English (en-GB/en-US, preferring British female voice), Hindi (hi-IN),
/// Telugu (te-IN), Tamil (ta-IN), Kannada (kn-IN), and Malayalam (ml-IN).
/// Calibrated for natural unhurried speech (~95-110 WPM).
class LocalTtsProvider {
  static const double defaultSpeechRate = 0.79; // Calibrated for ~95-110 WPM
  static const double defaultPitch = 1.0; // Natural pitch, avoiding artificial effects

  final FlutterTts _flutterTts;
  bool _isInitialized = false;
  final Map<String, Map<String, String>?> _voiceCache = {};
  VoidCallback? _onStartCallback;
  VoidCallback? _onCompleteCallback;
  bool _isSpeaking = false;

  LocalTtsProvider({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts() {
    _init();
  }

  bool get isSpeaking => _isSpeaking;

  void _init() {
    try {
      _flutterTts.setSpeechRate(defaultSpeechRate).catchError((_) {});
      _flutterTts.setPitch(defaultPitch).catchError((_) {});

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _onStartCallback?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _onCompleteCallback?.call();
        _onCompleteCallback = null;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        _onCompleteCallback = null;
      });

      _flutterTts.setErrorHandler((dynamic msg) {
        debugPrint('[LocalTtsProvider] TTS Error: $msg');
        _isSpeaking = false;
        _onCompleteCallback?.call();
        _onCompleteCallback = null;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[LocalTtsProvider] Init error: $e');
    }
  }

  /// Maps language code to locale identifier
  String getLocaleForLanguage(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'hi':
        return 'hi-IN';
      case 'ta':
        return 'ta-IN';
      case 'te':
        return 'te-IN';
      case 'kn':
        return 'kn-IN';
      case 'ml':
        return 'ml-IN';
      case 'en':
      default:
        // Prefer en-GB for British-style voice if available
        return 'en-GB';
    }
  }

  /// Checks if a language is installed and available on the local device
  Future<bool> isLanguageAvailable(String langCode) async {
    try {
      final locale = getLocaleForLanguage(langCode);
      final dynamic res = await _flutterTts.isLanguageAvailable(locale);
      if (res == true || res == 1 || (res is int && res >= 0)) return true;

      // For English, test en-US and en-IN if en-GB was not found
      if (langCode.toLowerCase() == 'en') {
        final dynamic usRes = await _flutterTts.isLanguageAvailable('en-US');
        if (usRes == true || usRes == 1 || (usRes is int && usRes >= 0)) return true;
        final dynamic inRes = await _flutterTts.isLanguageAvailable('en-IN');
        return inRes == true || inRes == 1 || (inRes is int && inRes >= 0);
      }

      return false;
    } catch (e) {
      debugPrint('[LocalTtsProvider] isLanguageAvailable check failed for $langCode: $e');
      return false;
    }
  }

  /// Finds the best installed voice for a language.
  /// Prefers female, gentle, high-quality voices (and en-GB for English if present).
  Future<Map<String, String>?> findBestVoice(String langCode) async {
    final normLang = langCode.toLowerCase();
    if (_voiceCache.containsKey(normLang)) {
      return _voiceCache[normLang];
    }

    try {
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is! List) return null;

      final List<Map<String, String>> matchingVoices = [];
      for (final v in rawVoices) {
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          if (normLang == 'en') {
            if (locale.toLowerCase().startsWith('en')) {
              matchingVoices.add({'name': name, 'locale': locale});
            }
          } else {
            if (locale.toLowerCase().contains(normLang)) {
              matchingVoices.add({'name': name, 'locale': locale});
            }
          }
        }
      }

      if (matchingVoices.isEmpty) {
        _voiceCache[normLang] = null;
        return null;
      }

      Map<String, String>? selected;

      // For English: prefer British English female voice
      if (normLang == 'en') {
        // 1. British female (warm, polished, gentle)
        for (final v in matchingVoices) {
          final loc = v['locale']!.toLowerCase();
          final nm = v['name']!.toLowerCase();
          if ((loc.contains('gb') || loc.contains('gbr')) &&
              (nm.contains('female') ||
                  nm.contains('woman') ||
                  nm.contains('c-') ||
                  nm.contains('f-') ||
                  nm.contains('rjs') ||
                  nm.contains('gbb') ||
                  nm.contains('gb-x'))) {
            selected = v;
            break;
          }
        }
        // 2. Any British voice
        if (selected == null) {
          for (final v in matchingVoices) {
            final loc = v['locale']!.toLowerCase();
            if (loc.contains('gb') || loc.contains('gbr')) {
              selected = v;
              break;
            }
          }
        }
        // 3. Any English female voice (e.g. en-US or en-IN)
        if (selected == null) {
          for (final v in matchingVoices) {
            final nm = v['name']!.toLowerCase();
            if (nm.contains('female') ||
                nm.contains('woman') ||
                nm.contains('c-') ||
                nm.contains('f-')) {
              selected = v;
              break;
            }
          }
        }
      }

      // If not yet selected or non-English: prefer female / neural voices
      if (selected == null) {
        for (final v in matchingVoices) {
          final nm = v['name']!.toLowerCase();
          if (nm.contains('female') ||
              nm.contains('woman') ||
              nm.contains('neural') ||
              nm.contains('network') ||
              nm.contains('c-') ||
              nm.contains('f-')) {
            selected = v;
            break;
          }
        }
      }

      // Fallback to first matching voice
      selected ??= matchingVoices.first;

      _voiceCache[normLang] = selected;
      return selected;
    } catch (e) {
      debugPrint('[LocalTtsProvider] Error discovering voices: $e');
      return null;
    }
  }

  /// Synthesize speech locally using native Android TTS.
  /// Returns `true` on successful start; returns `false` on failure/unavailability to allow Gemini fallback.
  Future<bool> speak(
    String text,
    String langCode, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
    double speechRate = defaultSpeechRate,
    double pitch = defaultPitch,
    bool fallbackToDeviceDefault = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;

    try {
      if (!_isInitialized) _init();

      // Check whether device supports this language before attempting
      final isAvail = await isLanguageAvailable(langCode);
      if (!isAvail && !fallbackToDeviceDefault) {
        debugPrint('[LocalTtsProvider] Language $langCode not available on device TTS.');
        return false;
      }

      // Ensure previous local speech is stopped
      await stop();

      _onStartCallback = onStart;
      _onCompleteCallback = onComplete;

      final locale = getLocaleForLanguage(langCode);
      try {
        await _flutterTts.setLanguage(locale);
      } catch (_) {
        if (fallbackToDeviceDefault) {
          try {
            await _flutterTts.setLanguage('en-IN');
          } catch (_) {}
        }
      }
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setPitch(pitch);

      final bestVoice = await findBestVoice(langCode);
      if (bestVoice != null && bestVoice['name'] != null) {
        final voiceLocale = bestVoice['locale'] ?? locale;
        await _flutterTts.setLanguage(voiceLocale);
        await _flutterTts.setVoice({
          'name': bestVoice['name']!,
          'locale': voiceLocale,
        });
      }

      final dynamic result = await _flutterTts.speak(clean);
      // Result is 1 or true on Android when speech successfully starts
      if (result == 1 || result == true) {
        return true;
      } else {
        debugPrint('[LocalTtsProvider] flutter_tts speak returned: $result');
        return false;
      }
    } catch (e) {
      debugPrint('[LocalTtsProvider] Failed to speak locally ($e).');
      _isSpeaking = false;
      _onCompleteCallback = null;
      return false;
    }
  }

  /// Immediately stop any ongoing local TTS
  Future<void> stop() async {
    _isSpeaking = false;
    _onCompleteCallback = null;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
