import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/api/api_client.dart';
import '../../features/kalamitra/services/kalamitra_faq_service.dart';
import 'audio_cache.dart';
import 'gemini_tts_provider.dart';
import 'local_tts_provider.dart';
import 'speech_text_helper.dart';

enum VoiceState {
  idle,
  generating,
  speaking,
}

/// KalaSetu Centralized Voice Service
///
/// Priority Architecture:
/// 1. Local Android TTS (flutter_tts) -> Offline-first, immediate, ~95-110 WPM
/// 2. Cached audio (AudioCache) -> In-memory/disk playback, zero network
/// 3. Gemini TTS fallback (GeminiTtsProvider) -> Natural AI voice when local is unavailable
///
/// Single-voice session protection prevents echo, double-playback, or race conditions.
class VoiceService with ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  static VoiceService get instance => _instance;

  static const String defaultVoiceProfile = AudioCache.currentVersion;

  final LocalTtsProvider _localTtsProvider;
  final GeminiTtsProvider _geminiTtsProvider;
  final AudioCache _audioCache;
  static const MethodChannel _audioChannel = MethodChannel('com.kalasetu.app/audio_player');

  VoiceState _state = VoiceState.idle;
  bool _isPlaying = false;
  String? _currentlySpeakingText;
  VoidCallback? _activeOnComplete;
  String _currentVoice = defaultVoiceProfile;
  int _activeSessionId = 0;
  final Set<String> _inFlightPrefetches = {};

  VoiceState get state => _state;
  bool get isGenerating => _state == VoiceState.generating;
  bool get isPlaying => _isPlaying;
  bool get isSpeaking => _isPlaying;
  String? get currentlySpeaking => _currentlySpeakingText;
  String get currentVoice => _currentVoice;
  int get currentSessionId => _activeSessionId;

  LocalTtsProvider get localTtsProvider => _localTtsProvider;
  GeminiTtsProvider get geminiTtsProvider => _geminiTtsProvider;
  AudioCache get audioCache => _audioCache;

  VoiceService._internal({
    ApiClient? apiClient,
    LocalTtsProvider? localTtsProvider,
    GeminiTtsProvider? geminiTtsProvider,
    AudioCache? audioCache,
  })  : _audioCache = audioCache ?? AudioCache(),
        _localTtsProvider = localTtsProvider ?? LocalTtsProvider(),
        _geminiTtsProvider = geminiTtsProvider ?? GeminiTtsProvider(apiClient: apiClient) {
    _initAudioChannel();
  }

  @visibleForTesting
  VoiceService.forTesting({
    ApiClient? apiClient,
    LocalTtsProvider? localTtsProvider,
    GeminiTtsProvider? geminiTtsProvider,
    AudioCache? audioCache,
  }) : this._internal(
          apiClient: apiClient,
          localTtsProvider: localTtsProvider,
          geminiTtsProvider: geminiTtsProvider,
          audioCache: audioCache,
        );

  void _initAudioChannel() {
    try {
      _audioChannel.setMethodCallHandler((call) async {
        if (call.method == 'onComplete' || call.method == 'onError') {
          _handlePlaybackFinished(_activeSessionId);
        }
      });
    } catch (e) {
      debugPrint('[VoiceService] MethodChannel init warning: $e');
    }
  }

  /// Compute deterministic hash of (text, lang, voice) with version invalidation
  static String computeVoiceHash(String text, String lang, [String voice = defaultVoiceProfile]) {
    return AudioCache.computeHash(text, lang, voice);
  }

  /// Standard Indic locale mapping
  String getLocaleForLanguage(String langCode) {
    return _localTtsProvider.getLocaleForLanguage(langCode);
  }

  /// Speaks text following the priority architecture:
  /// 1. Local Android TTS first (offline-first, natural calm pace ~95-110 WPM)
  /// 2. Audio cache hit (for pre-generated phrases)
  /// 3. Gemini TTS fallback (when local TTS is unavailable or fails)
  Future<void> speak({
    required String text,
    required String languageCode,
    String voice = defaultVoiceProfile,
    bool forceGemini = false,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // Enforce single voice playback: cancel any ongoing speech or playback first
    await stop();

    // Increment session ID to discard stale callbacks from older requests
    final int sessionId = ++_activeSessionId;
    final totalSw = Stopwatch()..start();

    _currentlySpeakingText = cleanText;
    _currentVoice = voice;
    _activeOnComplete = onComplete;

    // Preprocess text (clean markdown, URLs, code blocks, ₹1,250 -> words)
    final spokenText = SpeechTextHelper.toSpeechFriendly(cleanText, languageCode);
    final hash = AudioCache.computeHash(spokenText, languageCode, voice);

    debugPrint('[VoiceService] Speak requested (session=$sessionId): lang=$languageCode, forceGemini=$forceGemini');

    // =========================================================================
    // PRIORITY 1: LOCAL ANDROID TTS FIRST (Offline-First)
    // =========================================================================
    if (!forceGemini) {
      debugPrint('[VoiceService] Attempting Local Android TTS for: "$spokenText"');
      final localSw = Stopwatch()..start();

      final localSuccess = await _localTtsProvider.speak(
        spokenText,
        languageCode,
        onStart: () {
          if (sessionId == _activeSessionId) {
            _isPlaying = true;
            _state = VoiceState.speaking;
            notifyListeners();
            onStart?.call();
          }
        },
        onComplete: () {
          _handlePlaybackFinished(sessionId);
        },
      );

      if (localSuccess) {
        _isPlaying = true;
        _state = VoiceState.speaking;
        notifyListeners();
        final startLatency = localSw.elapsedMilliseconds;
        debugPrint('''
[VoiceService TRACE] LOCAL TTS SUCCESS
Playback-start latency: ${startLatency}ms
Total time-to-first-audio: ${totalSw.elapsedMilliseconds}ms
''');
        return;
      }

      debugPrint('[VoiceService] Local TTS unavailable or failed. Falling back to Cache / Gemini TTS.');
    }

    if (sessionId != _activeSessionId) return;

    // =========================================================================
    // PRIORITY 2: CHECK CACHED AUDIO
    // =========================================================================
    try {
      final cachedFile = await _audioCache.getValidCachedFile(hash);
      if (cachedFile != null) {
        if (sessionId != _activeSessionId) return;

        // Ensure local TTS is stopped before native playback
        await _localTtsProvider.stop();

        final playSw = Stopwatch()..start();
        final played = await _playLocalAudioFile(cachedFile.path, sessionId);
        if (played) {
          _isPlaying = true;
          _state = VoiceState.speaking;
          notifyListeners();
          onStart?.call();
          debugPrint('''
[VoiceService TRACE] CACHE HIT
Playback-start latency: ${playSw.elapsedMilliseconds}ms
Total time-to-first-audio: ${totalSw.elapsedMilliseconds}ms
''');
          return;
        }
      }
    } catch (e) {
      debugPrint('[VoiceService] Cache check error: $e');
    }

    if (sessionId != _activeSessionId) return;

    // =========================================================================
    // PRIORITY 3: GEMINI TTS FALLBACK (Online)
    // =========================================================================
    debugPrint('[VoiceService] Cache MISS: requesting Gemini TTS fallback from backend');
    _state = VoiceState.generating;
    notifyListeners();

    final reqSw = Stopwatch()..start();
    final audioBytes = await _geminiTtsProvider.fetchSpeechAudio(
      text: spokenText,
      languageCode: languageCode,
      voice: voice,
    );

    if (sessionId != _activeSessionId) return;

    if (audioBytes != null) {
      // Ensure local TTS is stopped before native playback
      await _localTtsProvider.stop();

      final playSw = Stopwatch()..start();
      // Play directly from memory with zero disk delay
      final played = await _playAudioBytes(audioBytes, sessionId);
      if (played) {
        _isPlaying = true;
        _state = VoiceState.speaking;
        notifyListeners();
        onStart?.call();
        debugPrint('''
[VoiceService TRACE] GEMINI TTS FALLBACK SUCCESS
Request latency: ${reqSw.elapsedMilliseconds}ms
Playback-start latency: ${playSw.elapsedMilliseconds}ms
Total time-to-first-audio: ${totalSw.elapsedMilliseconds}ms
''');
        // Cache to disk asynchronously in the background
        unawaited(_audioCache.saveAudio(hash, audioBytes));
        return;
      }
    }

    if (sessionId != _activeSessionId) return;

    // If Gemini TTS failed or server was unreachable, immediately play on-device flutter_tts voice with no error shown
    debugPrint('[VoiceService] Server unreachable or Gemini failed; immediately playing on-device flutter_tts voice');
    final localSuccess = await _localTtsProvider.speak(
      spokenText,
      languageCode,
      fallbackToDeviceDefault: true,
      onStart: () {
        if (sessionId == _activeSessionId) {
          _isPlaying = true;
          _state = VoiceState.speaking;
          notifyListeners();
          onStart?.call();
        }
      },
      onComplete: () {
        _handlePlaybackFinished(sessionId);
      },
    );
    if (localSuccess) {
      _isPlaying = true;
      _state = VoiceState.speaking;
      notifyListeners();
      return;
    }

    // All providers failed or audio could not be played
    debugPrint('[VoiceService] All speech providers exhausted for: "$spokenText"');
    _handlePlaybackFinished(sessionId);
  }

  /// Play audio bytes directly from memory via native Android MediaDataSource
  Future<bool> _playAudioBytes(Uint8List bytes, int sessionId) async {
    try {
      final result = await _audioChannel.invokeMethod<bool>('playBytes', {'bytes': bytes});
      return result == true;
    } catch (e) {
      debugPrint('[VoiceService] MethodChannel playBytes failed: $e');
      return false;
    }
  }

  /// Play local WAV file via native Android MediaPlayer MethodChannel
  Future<bool> _playLocalAudioFile(String path, int sessionId) async {
    try {
      final result = await _audioChannel.invokeMethod<bool>('playFile', {'path': path});
      return result == true;
    } catch (e) {
      debugPrint('[VoiceService] MethodChannel playFile failed: $e');
      return false;
    }
  }

  /// Immediately stop any currently playing voice (local TTS, Gemini audio, native player)
  Future<void> stop() async {
    _activeSessionId++;

    try {
      await _audioChannel.invokeMethod('stop');
    } catch (_) {}

    try {
      await _localTtsProvider.stop();
    } catch (_) {}

    _isPlaying = false;
    _state = VoiceState.idle;
    _currentlySpeakingText = null;
    _activeOnComplete = null;
    notifyListeners();
    debugPrint('[VoiceService] Stopped all playback and reset state to idle (session: $_activeSessionId)');
  }

  void _handlePlaybackFinished(int sessionId) {
    if (sessionId == _activeSessionId) {
      _isPlaying = false;
      _state = VoiceState.idle;
      _currentlySpeakingText = null;
      notifyListeners();
      _activeOnComplete?.call();
      _activeOnComplete = null;
    }
  }

  /// Pre-fetch audio for fixed UI phrases in the given language when online.
  /// Stores them in device cache so subsequent playback is instant and offline-ready.
  Future<void> prefetchFixedPhrases(String langCode) async {
    await KalaMitraFaqService().ensureLoaded();
    final phrases = getFixedPhrasesForLang(langCode);

    try {
      for (final rawText in phrases) {
        final text = SpeechTextHelper.toSpeechFriendly(rawText, langCode);
        final hash = AudioCache.computeHash(text, langCode, _currentVoice);

        // Skip if already in flight
        if (_inFlightPrefetches.contains(hash)) continue;

        // Check if already valid in cache
        final existing = await _audioCache.getValidCachedFile(hash);
        if (existing != null) continue;

        _inFlightPrefetches.add(hash);
        try {
          final audioBytes = await _geminiTtsProvider.fetchSpeechAudio(
            text: text,
            languageCode: langCode,
            voice: _currentVoice,
          );
          if (audioBytes != null) {
            await _audioCache.saveAudio(hash, audioBytes);
            debugPrint('[VoiceService] Prefetched: $hash (${audioBytes.length} bytes)');
          }
          // Gentle pacing to avoid free tier rate-limits
          await Future.delayed(const Duration(milliseconds: 600));
        } catch (_) {
          // If offline or rate-limited, safely proceed without blocking
        } finally {
          _inFlightPrefetches.remove(hash);
        }
      }
    } catch (e) {
      debugPrint('[VoiceService] Error prefetching fixed phrases: $e');
    }
  }

  /// List of fixed UI phrases to prefetch for a given language
  static List<String> getFixedPhrasesForLang(String langCode) {
    final faq = KalaMitraFaqService();
    final specialAnswer = faq.getSpecialAnswer(langCode);
    final creatorAnswer = faq.getCreatorAnswer(langCode);
    final diffAnswer = faq.getEcommerceDiffAnswer(langCode);

    final List<String> list = [
      specialAnswer,
      creatorAnswer,
      diffAnswer,
    ];

    switch (langCode.toLowerCase()) {
      case 'hi':
        list.addAll([
          'नमस्ते, मैं आपकी क्या मदद कर सकता हूँ?',
          'मैं कलामित्र हूँ।',
          'आपका उत्पाद सहेज लिया गया है।',
          'आपके उत्पाद की छवि बेहतर कर दी गई है।',
          'यहाँ सुझाया गया मूल्य है।',
          'क्या आप चाहते हैं कि मैं लिस्टिंग बनाऊँ?',
          'आपकी लिस्टिंग तैयार है।',
          'आपका उत्पाद तैयार है।',
          'आपका सुझाया गया मूल्य एक हजार दो सौ पचास रुपये है।',
          'कृपया पुन: प्रयास करें।',
          'कोई इंटरनेट कनेक्शन नहीं है।',
          'आपका ऑर्डर प्राप्त हो गया है।',
          'कलासेतु में आपका स्वागत है।',
          'अपने शिल्प की फोटो लें।',
          'नया उत्पाद जोड़ें।',
          'कारीगरी को एक साफ, ठोस पृष्ठभूमि पर रखें।',
          'खिड़की से आने वाली प्राकृतिक धूप से हथकरघा के रंग निखरते हैं।',
          'फोन को स्थिर रखें और पूरी कारीगरी को फ्रेम में लें।',
        ]);
        break;
      case 'ta':
        list.addAll([
          'வணக்கம், நான் உங்களுக்கு எவ்வாறு உதவ முடியும்?',
          'நான் கலாமித்ரா.',
          'உங்கள் தயாரிப்பு சேமிக்கப்பட்டது.',
          'உங்கள் தயாரிப்பு படம் மேம்படுத்தப்பட்டது.',
          'பரிந்துரைக்கப்பட்ட விலை இதோ.',
          'நான் பட்டியலை உருவாக்க விரும்புகிறீர்களா?',
          'உங்கள் பட்டியல் தயாராக உள்ளது.',
          'உங்கள் தயாரிப்பு தயாராக உள்ளது.',
          'உங்களுக்குப் பரிந்துரைக்கப்பட்ட விலை ஆயிரத்து இருநூற்று ஐம்பது ரூபாய்.',
          'மீண்டும் முயற்சிக்கவும்.',
          'இணைய இணைப்பு இல்லை.',
          'உங்கள் ஆர்டர் பெறப்பட்டது.',
          'கலாசேதுவிற்கு வரவேற்கிறோம்.',
          'கைவினைப் படத்தை எடுக்கவும்.',
          'புதிய தயாரிப்பைச் சேர்க்கவும்.',
          'கைவினைப் பொருளை சுத்தமான, திடமான பின்னணியில் வைக்கவும்.',
          'இயற்கையான பகல் வெளிச்சம் கைத்தறி வண்ணங்களை எடுப்பாக காட்டும்.',
          'கை அசைவின்றி முழு கைவினைப் பொருளையும் படமெடுக்கவும்.',
        ]);
        break;
      case 'te':
        list.addAll([
          'నమస్కారం, నేను మీకు ఎలా సహాయపడగలను?',
          'నేను కలామిత్రను.',
          'మీ ఉత్పత్తి భద్రపరచబడింది.',
          'మీ ఉత్పత్తి చిత్రం మెరుగుపరచబడింది.',
          'ఇక్కడ సూచించిన ధర ఉంది.',
          'నేను లిస్టింగ్ సృష్టించాలనుకుంటున్నారా?',
          'మీ లిస్టింగ్ సిద్ధంగా ఉంది.',
          'మీ ఉత్పత్తి సిద్ధంగా ఉంది.',
          'మీకు సూచించిన ధర వెయ్యి రెండు వందల యాభై రూపాయలు.',
          'దయచేసి మళ్లీ ప్రయత్నించండి.',
          'ఇంటర్నెట్ కనెక్షన్ లేదు.',
          'మీ ఆర్డర్ అందింది.',
          'కలాసేతుకు స్వాగతం.',
          'హస్తకళ ఫోటో తీయండి.',
          'కొత్త ఉత్పత్తిని జోడించండి.',
          'హస్తకళను శుభ్రమైన, సాదా నేపథ్యంపై ఉంచండి.',
          'సహజ సూర్యకాంతి చేనేత రంగులను ప్రకాశవంతంగా చేస్తుంది.',
          'ఫోన్ నిశ్చలంగా ఉంచి పూర్తి వస్తువును ఫ్రేమ్ చేయండి.',
        ]);
        break;
      case 'kn':
        list.addAll([
          'ನಮಸ್ಕಾರ, ನಾನು ನಿಮಗೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಲಿ?',
          'ನಾನು ಕಲಾವಿತ್ರ.',
          'ನಿಮ್ಮ ಉತ್ಪನ್ನವನ್ನು ಉಳಿಸಲಾಗಿದೆ.',
          'ನಿಮ್ಮ ಉತ್ಪನ್ನದ ಚಿತ್ರವನ್ನು ಸುಧಾರಿಸಲಾಗಿದೆ.',
          'ಸೂಚಿಸಲಾದ ಬೆಲೆ ಇಲ್ಲಿದೆ.',
          'ನಾನು ಪಟ್ಟಿಯನ್ನು ರಚಿಸಬೇಕೆಂದು ನೀವು ಬಯಸುವಿರಾ?',
          'ನಿಮ್ಮ ಪಟ್ಟಿ ಸಿದ್ಧವಾಗಿದೆ.',
          'ನಿಮ್ಮ ಉತ್ಪನ್ನ ಸಿದ್ಧವಾಗಿದೆ.',
          'ನಿಮಗೆ ಸೂಚಿಸಲಾದ ಬೆಲೆ ಒಂದು ಸಾವಿರದ ಇನ್ನೂರ ಐವತ್ತು ರೂಪಾಯಿಗಳು.',
          'ದಯವಿಟ್ಟು ಪುನಃ ಪ್ರಯತ್ನಿಸಿ.',
          'ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕವಿಲ್ಲ.',
          'ನಿಮ್ಮ ಆರ್ಡರ್ ಸ್ವೀಕರಿಸಲಾಗಿದೆ.',
          'ಕಲಾಸೇತುಗೆ ಸುಸ್ವಾಗತ.',
          'ಕರಕುಶಲ ಫೋಟೋ ತೆಗೆಯಿರಿ.',
          'ಹೊಸ ಉತ್ಪನ್ನವನ್ನು ಸೇರಿಸಿ.',
          'ಕರಕುಶಲ ವಸ್ತುವನ್ನು ಸ್ವಚ್ಛ, ಸರಳ ಹಿನ್ನೆಲೆಯ ಮೇಲೆ ಇರಿಸಿ.',
          'ನೈಸರ್ಗಿಕ ಬೆಳಕು ಕೈಮಗ್ಗದ ಬಣ್ಣಗಳನ್ನು ಸುಂದರವಾಗಿ ತೋರಿಸುತ್ತದೆ.',
          'ಫೋನ್ ಅನ್ನು ಸ್ಥಿರವಾಗಿ ಹಿಡಿದು ಸಂಪೂರ್ಣ ವಸ್ತುವನ್ನು ಫ್ರೇಮ್ ಮಾಡಿ.',
        ]);
        break;
      case 'ml':
        list.addAll([
          'നമസ്കാരം, ഞാൻ നിങ്ങളെ എങ്ങനെ സഹായിക്കണം?',
          'ഞാൻ കലാമിത്രയാണ്.',
          'നിങ്ങളുടെ ഉൽപ്പന്നം സംരക്ഷിച്ചു.',
          'നിങ്ങളുടെ ഉൽപ്പന്ന ചിത്രം മെച്ചപ്പെടുത്തി.',
          'നിർദ്ദേശിച്ച വില ഇതാ.',
          'ഞാൻ ലിസ്റ്റിംഗ് സൃഷ്ടിക്കണമെന്ന് നിങ്ങൾ ആഗ്രഹിക്കുന്നുണ്ടോ?',
          'നിങ്ങളുടെ ലിസ്റ്റിംഗ് തയ്യാറാണ്.',
          'നിങ്ങളുടെ ഉൽപ്പന്നം തയ്യാറാണ്.',
          'നിങ്ങൾക്ക് നിർദ്ദേശിച്ച വില ആയിരത്തി ഇരുന്നൂറ്റി അൻപത് രൂപയാണ്.',
          'ദയവായി വീണ്ടും ശ്രമിക്കുക.',
          'ഇന്റർനെറ്റ് കണക്ഷൻ ലഭ്യമല്ല.',
          'നിങ്ങളുടെ ഓർഡർ ലഭിച്ചു.',
          'കലാസേതുവിലേക്ക് സ്വാഗതം.',
          'കരകൗശല ഫോട്ടോ എടുക്കുക.',
          'പുതിയ ഉൽപ്പന്നം ചേർക്കുക.',
          'കരകൗശല വസ്തു വൃത്തിയുള്ള പശ്ചാത്തലത്തിൽ വയ്ക്കുക.',
          'സ്വാഭാവിക വെളിച്ചം കൈത്തറി നിറങ്ങൾ മനോഹരമാക്കും.',
          'ഫോൺ അനക്കാതെ പിടിച്ച് മുഴുവൻ വസ്തുവും ഫ്രെയിം ചെയ്യുക.',
        ]);
        break;
      case 'en':
      default:
        list.addAll([
          'Hello, how can I help you?',
          'I am KalaMitra.',
          'Your product has been saved.',
          'Your product image has been enhanced.',
          'Here is the suggested price.',
          'Would you like me to create the listing?',
          'Your listing is ready.',
          'Your product is ready.',
          'Your suggested price is one thousand two hundred and fifty rupees.',
          'Please try again.',
          'There is no internet connection.',
          'Your order has been received.',
          'Welcome to KalaSetu.',
          'Take a craft photo.',
          'Add new craft product.',
          'Keep the craft piece on a clean, solid background.',
          'Natural daylight from a window makes handloom colors pop.',
          'Hold steady and frame the entire craft piece.',
        ]);
        break;
    }

    return list;
  }
}

