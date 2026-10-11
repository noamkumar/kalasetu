import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/api/api_client.dart';
import 'package:frontend/features/kalamitra/services/kalamitra_service.dart';

class MockTestApiClient extends ApiClient {
  Map<String, dynamic>? lastSentBody;

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Duration? timeout,
  }) async {
    lastSentBody = body is Map<String, dynamic> ? body : null;
    final message = (body?['message'] as String? ?? '').toLowerCase();

    if (message.contains('amazon')) {
      return {
        'reply':
            'KalaSetu is not just another shopping app; it is designed as an AI virtual business manager for artisans. Normal e-commerce platforms like Amazon provide a marketplace, while KalaSetu assists you before and during selling with photo cleanup, voice cataloging, and fair cost floors.',
        'action': 'none',
        'suggestions': ['What is special about KalaSetu?', 'How does pricing work?', 'Take craft photo'],
      };
    }

    if (message.contains('special')) {
      return {
        'reply':
            'KalaSetu is designed specifically for traditional artisans. It offers an AI Image Studio that cleans backgrounds, a Multilingual Voice Cataloger, and a Fair Pricing Assistant.',
        'action': 'none',
        'suggestions': ['Why use KalaSetu instead of Amazon?', 'Check fair pricing'],
      };
    }

    if (message.contains('help an artisan') || message.contains('help')) {
      return {
        'reply':
            'KalaSetu helps artisans by removing technical and digital barriers with AI photo studio, regional voice cataloging, cost-floor pricing, and continuous market access.',
        'action': 'none',
        'suggestions': ['Take craft photo', 'Explain pricing'],
      };
    }

    if (message.contains('python')) {
      return {
        'reply':
            'Python is a popular high-level programming language known for its clear syntax and versatility in web development, data science, and AI.',
        'action': 'none',
        'suggestions': ['What is machine learning?', 'Tell me a joke'],
      };
    }

    if (message.contains('joke')) {
      return {
        'reply': 'Why do programmers prefer dark mode? Because light attracts bugs!',
        'action': 'none',
        'suggestions': ['Tell me another joke', 'What is Python?'],
      };
    }

    if (message.contains('weather')) {
      return {
        'reply':
            'I currently do not have access to live weather data or external weather sensors, so live weather information is unavailable. Please check your local weather app.',
        'action': 'none',
        'suggestions': ['What is KalaSetu?', 'What is Python?'],
      };
    }

    if (body?['image_id'] != null) {
      return {
        'reply': 'Background has been updated.',
        'action': 'edit_image',
        'image_id': body?['image_id'],
        'image_url': '/static/enhanced/test.webp',
        'can_undo': true,
        'can_redo': false,
        'suggestions': ['Make it brighter', 'Undo'],
      };
    }

    return {
      'reply': 'I am happy to assist you! Feel free to ask about KalaSetu or general topics.',
      'action': 'none',
      'suggestions': ['What is KalaSetu?', 'Tell me a joke'],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KalaMitra General Service & Category Tests', () {
    late MockTestApiClient mockApi;
    late KalaMitraService service;

    setUp(() {
      mockApi = MockTestApiClient();
      service = KalaMitraService(apiClient: mockApi);
    });

    test('TEST 8: "Who created you?" returns exact Noam answer locally without calling API', () async {
      final res = await service.sendMessage(
        message: 'Who created you?',
        currentScreen: 'home',
        language: 'en',
      );
      expect(res.reply, equals('I was created by Noam.'));
      expect(mockApi.lastSentBody, isNull, reason: 'Creator identity should be resolved without remote call');
    });

    test('TEST 1: "Why should I use KalaSetu instead of Amazon?" uses KalaSetu context', () async {
      final res = await service.sendMessage(
        message: 'Why should I use KalaSetu instead of Amazon?',
        currentScreen: 'home',
        language: 'en',
      );
      expect(mockApi.lastSentBody, isNotNull);
      expect(mockApi.lastSentBody?['message'], equals('Why should I use KalaSetu instead of Amazon?'));
      expect(res.reply.toLowerCase(), contains('amazon'));
      expect(res.reply.toLowerCase(), contains('virtual business manager'));
    });

    test('TEST 2: "What is special about KalaSetu?" returns artisan AI features', () async {
      final res = await service.sendMessage(
        message: 'What is special about KalaSetu?',
        currentScreen: 'home',
        language: 'en',
      );
      expect(res.reply.toLowerCase(), contains('artisan'));
      expect(res.reply.toLowerCase(), contains('studio'));
    });

    test('TEST 4: "What is Python?" returns general knowledge answer without forcing KalaSetu', () async {
      final res = await service.sendMessage(
        message: 'What is Python?',
        currentScreen: 'home',
        language: 'en',
      );
      expect(res.reply.toLowerCase(), contains('programming language'));
      expect(res.reply.toLowerCase(), isNot(contains('handicraft')));
    });

    test('TEST 5: "Tell me a joke." returns general answer', () async {
      final res = await service.sendMessage(
        message: 'Tell me a joke.',
        currentScreen: 'home',
        language: 'en',
      );
      expect(res.reply, contains('dark mode'));
    });

    test('TEST 7: "What is today\'s weather?" states live weather is unavailable and does not invent data', () async {
      final res = await service.sendMessage(
        message: "What is today's weather?",
        currentScreen: 'home',
        language: 'en',
      );
      expect(res.reply.toLowerCase(), contains('unavailable'));
      expect(res.reply.toLowerCase(), contains('live weather'));
    });

    test('Multi-turn conversation history is transmitted to backend for context preservation', () async {
      final history = [
        {'role': 'user', 'content': 'What is KalaSetu?'},
        {'role': 'assistant', 'content': 'KalaSetu is an AI virtual business manager for artisans.'},
      ];

      final res = await service.sendMessage(
        message: 'How does it help an artisan?',
        currentScreen: 'home',
        language: 'en',
        history: history,
      );

      expect(mockApi.lastSentBody, isNotNull);
      expect(mockApi.lastSentBody?['history'], equals(history));
      expect(res.reply.toLowerCase(), contains('artisans'));
    });

    test('Image editing request with imageId transmits image_id and returns imageUrl and undo state', () async {
      final res = await service.sendMessage(
        message: 'Make the background pure white',
        currentScreen: 'home',
        language: 'en',
        imageId: 'img_test_123',
      );

      expect(mockApi.lastSentBody, isNotNull);
      expect(mockApi.lastSentBody?['image_id'], equals('img_test_123'));
      expect(res.imageUrl, equals('/static/enhanced/test.webp'));
      expect(res.canUndo, isTrue);
      expect(res.action, equals('edit_image'));
    });

    test('Multilingual regional language commands transmit language and image_id correctly', () async {
      final indicCommands = [
        {'lang': 'te', 'text': 'ఈ ఫోటో బ్యాక్గ్రౌండ్ తెల్లగా మార్చు'},
        {'lang': 'ta', 'text': 'இந்தப் படத்தின் பின்னணியை வெள்ளையாக மாற்று'},
        {'lang': 'kn', 'text': 'ಈ ಫೋಟೋದ ಹಿನ್ನೆಲೆಯನ್ನು ಬಿಳಿ ಬಣ್ಣಕ್ಕೆ ಬದಲಾಯಿಸು'},
        {'lang': 'ml', 'text': 'ഈ ചിത്രത്തിന്റെ പശ്ചാത്തലം വെള്ളയാക്കൂ'},
        {'lang': 'hi', 'text': 'इस फोटो का बैकग्राउंड सफेद कर दो'},
      ];

      for (final cmd in indicCommands) {
        final res = await service.sendMessage(
          message: cmd['text']!,
          currentScreen: 'home',
          language: cmd['lang']!,
          imageId: 'img_artisan_456',
        );

        expect(mockApi.lastSentBody?['language'], equals(cmd['lang']));
        expect(mockApi.lastSentBody?['image_id'], equals('img_artisan_456'));
        expect(res.imageUrl, isNotEmpty);
      }
    });

    test('Offline fallback returns valid rule-based responses if network throws', () async {
      final failingService = KalaMitraService(
        apiClient: _FailingApiClient(),
      );

      final res = await failingService.sendMessage(
        message: 'add a new product photo',
        currentScreen: 'home',
        language: 'en',
      );

      expect(res.action, equals('navigate'));
      expect(res.route, equals('/studio'));
    });
  });
}

class _FailingApiClient extends ApiClient {
  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Duration? timeout,
  }) async {
    throw const ApiException(message: 'Network offline', isNetworkError: true);
  }
}
