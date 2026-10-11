import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import '../api/api_client.dart';
import '../local_db/app_database.dart';

const String kSyncTaskName = 'com.kalasetu.offline_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final service = SyncService();
    await service.syncPendingQueue();
    return true;
  });
}

class SyncService {
  final AppDatabase _db;
  final ApiClient _api;

  SyncService({AppDatabase? db, ApiClient? api})
      : _db = db ?? AppDatabase(),
        _api = api ?? ApiClient();

  static Future<void> initializeWorkManager() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      await Workmanager().registerPeriodicTask(
        'kalasetu_periodic_sync',
        kSyncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (_) {
      // Gracefully continue if WorkManager isn't available on non-Android platform
    }
  }

  Future<int> syncPendingQueue() async {
    // Check network connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return 0;
    }

    final pending = await _db.getPendingSyncItems();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final itemsPayload = <Map<String, dynamic>>[];

    for (final item in pending) {
      final entity = item.entityType.toLowerCase().trim();
      if (entity == 'tts' || entity == 'voice' || !AppDatabase.allowedSyncEntityTypes.contains(entity)) {
        await _db.deleteSyncItem(item.id);
        continue;
      }

      dynamic payload = {};
      try {
        payload = json.decode(item.payloadJson);
      } catch (_) {}

      itemsPayload.add({
        'client_id': item.clientId,
        'entity_type': item.entityType,
        'entity_id': item.entityId,
        'action': item.action,
        'payload': payload,
      });
    }

    try {
      final res = await _api.post('/api/v1/sync/push', body: {'items': itemsPayload});
      if (res is Map && res['success'] == true) {
        for (final item in pending) {
          await _db.markSyncItemSynced(item.id);
          syncedCount++;
        }
      }
    } catch (_) {
      for (final item in pending) {
        await _db.markSyncItemFailed(item.id, item.retryCount);
      }
    }

    return syncedCount;
  }
}
