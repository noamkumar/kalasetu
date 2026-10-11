import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'core/services/developer_log_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/voice_service.dart';
import 'data/api/api_client.dart';
import 'data/local_db/app_database.dart';
import 'data/sync/sync_service.dart';
import 'features/kalamitra/services/kalamitra_faq_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await StorageService.init();
  DeveloperLogService.init();
  // Self-heal server address if saved address does not answer /health
  await ApiClient.healServerAddressOnStartup();
  await SyncService.initializeWorkManager();
  // Remove any already-queued TTS or non-data items on startup
  await AppDatabase.instance.removeQueuedTtsItems();

  final savedLocaleCode = StorageService.savedLocaleCode;

  // Background initialization of FAQ and prefetch audio for fixed phrases
  KalaMitraFaqService().loadFaq();
  VoiceService.instance.prefetchFixedPhrases(savedLocaleCode);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ta'),
        Locale('te'),
        Locale('kn'),
        Locale('ml'),
        Locale('bn'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLocaleCode),
      child: const ProviderScope(
        child: KalaSetuApp(),
      ),
    ),
  );
}
