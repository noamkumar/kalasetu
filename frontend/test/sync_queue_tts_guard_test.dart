import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/audio_cache.dart';
import 'package:frontend/core/services/gemini_tts_provider.dart';
import 'package:frontend/core/services/local_tts_provider.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/services/voice_service.dart';
import 'package:frontend/data/api/api_client.dart';
import 'package:frontend/data/local_db/app_database.dart';
import 'package:hive/hive.dart';

class MockLocalTtsProvider extends LocalTtsProvider {
  bool shouldSucceed = true;
  bool languageAvailable = true;
  int speakCount = 0;
  String? lastSpokenText;
  String? lastLang;
  bool lastFallbackToDeviceDefault = false;

  @override
  Future<bool> isLanguageAvailable(String langCode) async => languageAvailable;

  @override
  Future<bool> speak(
    String text,
    String langCode, {
    void Function()? onStart,
    void Function()? onComplete,
    double speechRate = 0.79,
    double pitch = 1.0,
    bool fallbackToDeviceDefault = false,
  }) async {
    speakCount++;
    lastSpokenText = text;
    lastLang = langCode;
    lastFallbackToDeviceDefault = fallbackToDeviceDefault;
    if (shouldSucceed) {
      onStart?.call();
      return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {}
}

class MockUnreachableGeminiTtsProvider extends GeminiTtsProvider {
  int fetchAttempts = 0;

  @override
  Future<Uint8List?> fetchSpeechAudio({
    required String text,
    required String languageCode,
    String voice = AudioCache.currentVersion,
  }) async {
    fetchAttempts++;
    // Simulating server unreachable (offline or invalid host)
    return null;
  }
}

class InMemoryBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _map.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1: Sync Queue TTS Guard & Startup Purge', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Real data changes (product, order, edit, profile) are accepted into sync queue', () async {
      final productItem = LocalSyncQueueCompanion.insert(
        clientId: 'client_1',
        entityType: 'product',
        entityId: 'prod_123',
        action: 'create',
        payloadJson: json.encode({'title': 'Clay Pot'}),
        createdAt: DateTime.now(),
      );

      final orderItem = LocalSyncQueueCompanion.insert(
        clientId: 'client_2',
        entityType: 'order',
        entityId: 'ord_456',
        action: 'update',
        payloadJson: json.encode({'status': 'packed'}),
        createdAt: DateTime.now(),
      );

      final prodId = await db.enqueueSyncItem(productItem);
      final ordId = await db.enqueueSyncItem(orderItem);

      expect(prodId, isPositive);
      expect(ordId, isPositive);

      final pending = await db.getPendingSyncItems();
      expect(pending.length, equals(2));
      expect(pending.map((e) => e.entityType), containsAll(['product', 'order']));
    });

    test('TTS/voice requests are strictly REJECTED and NEVER added to offline sync queue', () async {
      final ttsItem = LocalSyncQueueCompanion.insert(
        clientId: 'client_tts',
        entityType: 'tts',
        entityId: 'tts_audio_1',
        action: 'synthesize',
        payloadJson: json.encode({'text': 'Namaste'}),
        createdAt: DateTime.now(),
      );

      final voiceItem = LocalSyncQueueCompanion.insert(
        clientId: 'client_voice',
        entityType: 'voice',
        entityId: 'voice_audio_2',
        action: 'speak',
        payloadJson: json.encode({'text': 'Hello'}),
        createdAt: DateTime.now(),
      );

      final ttsResult = await db.enqueueSyncItem(ttsItem);
      final voiceResult = await db.enqueueSyncItem(voiceItem);

      expect(ttsResult, equals(-1), reason: 'TTS requests must be rejected from sync queue');
      expect(voiceResult, equals(-1), reason: 'Voice requests must be rejected from sync queue');

      final pending = await db.getPendingSyncItems();
      expect(pending, isEmpty, reason: 'Sync queue must remain empty');
    });

    test('Startup purge successfully removes any already-queued TTS items', () async {
      // Force direct insert bypassing validation to simulate legacy corrupted data
      await db.into(db.localSyncQueue).insert(
        LocalSyncQueueCompanion.insert(
          clientId: 'legacy_tts',
          entityType: 'tts',
          entityId: 'old_tts',
          action: 'speak',
          payloadJson: json.encode({'text': 'Old TTS'}),
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.localSyncQueue).insert(
        LocalSyncQueueCompanion.insert(
          clientId: 'legacy_voice',
          entityType: 'voice',
          entityId: 'old_voice',
          action: 'speak',
          payloadJson: json.encode({'text': 'Old Voice'}),
          createdAt: DateTime.now(),
        ),
      );
      // And insert one valid product
      await db.into(db.localSyncQueue).insert(
        LocalSyncQueueCompanion.insert(
          clientId: 'valid_prod',
          entityType: 'product',
          entityId: 'prod_999',
          action: 'create',
          payloadJson: json.encode({'title': 'Vase'}),
          createdAt: DateTime.now(),
        ),
      );

      // Verify 3 items initially exist
      final initialItems = await db.getPendingSyncItems();
      expect(initialItems.length, equals(3));

      // Execute startup purge
      final purgedCount = await db.removeQueuedTtsItems();
      expect(purgedCount, equals(2));

      // Verify only valid product remains
      final remaining = await db.getPendingSyncItems();
      expect(remaining.length, equals(1));
      expect(remaining.first.entityType, equals('product'));
    });
  });

  group('Requirement 1: Immediate On-Device Flutter TTS Fallback on Server Unreachable', () {
    test('When server/Gemini is unreachable, immediately plays on-device flutter_tts with no error shown', () async {
      final fakeLocal = MockLocalTtsProvider()..shouldSucceed = true;
      final fakeGemini = MockUnreachableGeminiTtsProvider();

      final voiceService = VoiceService.forTesting(
        localTtsProvider: fakeLocal,
        geminiTtsProvider: fakeGemini,
      );

      // Speak should complete gracefully without throwing exceptions
      await expectLater(
        voiceService.speak(
          text: 'Welcome to KalaSetu artisan hub',
          languageCode: 'en',
          forceGemini: true, // Forces attempt to reach server
        ),
        completes,
      );

      // Verify Gemini was attempted then local TTS immediately played
      expect(fakeGemini.fetchAttempts, equals(1));
      expect(fakeLocal.speakCount, isPositive);
      expect(fakeLocal.lastFallbackToDeviceDefault, isTrue);
      expect(voiceService.state, equals(VoiceState.speaking));
    });
  });

  group('Requirement 2: Runtime Hive Server Base URL Overrides Compile-Time Default', () {
    test('Hive stored serverBaseUrl takes precedence over default / compile-time URL', () async {
      final mockBox = InMemoryBox();
      StorageService.initForTesting(settingsBox: mockBox);

      // Before saving, default is returned
      final clientBefore = ApiClient();
      expect(clientBefore.baseUrl, isNotEmpty);

      // Save custom server URL in Hive
      await StorageService.setServerBaseUrl('http://10.73.89.51:8000');

      // ApiClient now picks up the Hive stored address over any default
      final clientAfter = ApiClient();
      expect(clientAfter.baseUrl, equals('http://10.73.89.51:8000/api/v1'));
      expect(StorageService.serverBaseUrl, equals('http://10.73.89.51:8000/api/v1'));

      // Clear returns back to default
      await StorageService.clearServerBaseUrl();
      final clientCleared = ApiClient();
      expect(clientCleared.baseUrl, equals(ApiClient.defaultBaseUrl));
    });
  });
}
