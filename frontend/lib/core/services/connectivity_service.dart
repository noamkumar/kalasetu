import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../data/api/api_client.dart';
import '../../data/local_db/app_database.dart';
import '../widgets/connectivity_pill.dart';

/// KalaSetu Connectivity Service
///
/// Monitors physical device network connectivity and KalaSetu backend health.
/// Distinguishes between:
/// - [ConnectivityState.online]: Device connected to network and backend /health is 200 OK.
/// - [ConnectivityState.syncing]: Backend connected and offline sync items are queued.
/// - [ConnectivityState.serverUnreachable]: Device has network (Wi-Fi/cellular) but server is unreachable.
/// - [ConnectivityState.noInternet]: Device has no network connection (offline).
class ConnectivityService with ChangeNotifier {
  static ConnectivityService? _instance;
  factory ConnectivityService() => instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._internal();

  @visibleForTesting
  static void setInstanceForTesting(ConnectivityService service) {
    _instance = service;
  }

  final Connectivity _connectivity;
  final ApiClient _apiClient;
  final AppDatabase _db;

  ConnectivityState _state = ConnectivityState.online;
  int _pendingSyncCount = 0;
  Timer? _pollingTimer;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _syncCountSubscription;
  bool _isChecking = false;

  ConnectivityState get state => _state;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isServerReachable => _state == ConnectivityState.online || _state == ConnectivityState.syncing;
  bool get hasInternet => _state != ConnectivityState.noInternet && _state != ConnectivityState.offline;

  ConnectivityService._internal({
    Connectivity? connectivity,
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _connectivity = connectivity ?? Connectivity(),
        _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase.instance {
    _init();
  }

  @visibleForTesting
  ConnectivityService.forTesting({
    Connectivity? connectivity,
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _connectivity = connectivity ?? Connectivity(),
        _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase.instance;

  void _init() {
    try {
      _syncCountSubscription = _db.watchPendingSyncCount().listen((count) {
        _pendingSyncCount = count;
        _updateDerivedState();
      });
    } catch (e) {
      debugPrint('[ConnectivityService] Sync count watch error: $e');
    }

    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
        checkConnectivity();
      });
    } catch (e) {
      debugPrint('[ConnectivityService] Connectivity stream error: $e');
    }

    // Check connectivity initially and periodically
    checkConnectivity();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnectivity();
    });
  }

  Future<void> checkConnectivity() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final results = await _connectivity.checkConnectivity();
      final hasNoNetwork = results.isEmpty || results.every((r) => r == ConnectivityResult.none);

      if (hasNoNetwork) {
        if (_state != ConnectivityState.noInternet) {
          _state = ConnectivityState.noInternet;
          notifyListeners();
        }
        return;
      }

      // We have physical network; test if KalaSetu backend is reachable
      bool serverReachable = false;
      try {
        await _apiClient.testConnection();
        serverReachable = true;
      } catch (_) {
        serverReachable = false;
      }

      final newState = serverReachable
          ? (_pendingSyncCount > 0 ? ConnectivityState.syncing : ConnectivityState.online)
          : ConnectivityState.serverUnreachable;

      if (_state != newState) {
        _state = newState;
        notifyListeners();
      }
    } catch (_) {
      if (_state != ConnectivityState.noInternet) {
        _state = ConnectivityState.noInternet;
        notifyListeners();
      }
    } finally {
      _isChecking = false;
    }
  }

  void _updateDerivedState() {
    if (_state == ConnectivityState.noInternet ||
        _state == ConnectivityState.offline ||
        _state == ConnectivityState.serverUnreachable) {
      return;
    }
    final target = _pendingSyncCount > 0 ? ConnectivityState.syncing : ConnectivityState.online;
    if (_state != target) {
      _state = target;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncCountSubscription?.cancel();
    super.dispose();
  }
}
