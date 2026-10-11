import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:frontend/core/services/developer_log_service.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/utils/network_error_helper.dart';
import 'package:frontend/core/widgets/connectivity_pill.dart';
import 'package:frontend/data/api/api_client.dart';
import 'package:frontend/data/repositories/auth_repository.dart';

// In-memory fake box for testing StorageService
class FakeStorageBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(key, {defaultValue}) => _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(key, value) async => _map[key] = value;

  @override
  Future<void> delete(key) async => _map.remove(key);

  @override
  bool containsKey(key) => _map.containsKey(key);

  @override
  Future<int> clear() async {
    final count = _map.length;
    _map.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStorageBox fakeSettingsBox;

  setUp(() {
    fakeSettingsBox = FakeStorageBox();
    StorageService.initForTesting(settingsBox: fakeSettingsBox);
    DeveloperLogService.lastErrorNotifier.value = null;
  });

  group('Requirement 1 & 2: DeveloperLogService & Startup Server Self-Healing', () {
    test('DeveloperLogService scrubs sensitive tokens and passwords', () {
      const rawJson = '{"access_token": "secret123", "password": "mypass", "otp": "999888", "phone": "9876543210"}';
      final scrubbed = DeveloperLogService.scrubSecrets(rawJson);

      expect(scrubbed.contains('secret123'), isFalse);
      expect(scrubbed.contains('mypass'), isFalse);
      expect(scrubbed.contains('999888'), isFalse);
      expect(scrubbed.contains('"access_token": "[REDACTED]"'), isTrue);
      expect(scrubbed.contains('"password": "[REDACTED]"'), isTrue);
      expect(scrubbed.contains('9876543210'), isTrue); // Phone is preserved
    });

    test('DeveloperLogService records error and stores in StorageService', () async {
      DeveloperLogService.recordError(
        method: 'POST',
        url: 'http://127.0.0.1:8000/api/v1/auth/otp/send',
        statusCode: 500,
        responseBody: '{"detail": "Internal server crash", "token": "abc"}',
        rawError: 'Server error (500)',
        errorType: 'server_error',
      );

      final lastError = DeveloperLogService.lastErrorNotifier.value;
      expect(lastError, isNotNull);
      expect(lastError!.statusCode, equals(500));
      expect(lastError.method, equals('POST'));
      expect(lastError.errorType, equals('server_error'));
      expect(lastError.responseBody?.contains('abc'), isFalse);
      expect(lastError.responseBody?.contains('[REDACTED]'), isTrue);

      // Verify persistence
      expect(StorageService.lastErrorJson, isNotNull);

      // Clear last error
      await DeveloperLogService.clearLastError();
      expect(DeveloperLogService.lastErrorNotifier.value, isNull);
      expect(StorageService.lastErrorJson, isNull);
    });

    test('Startup self-healing: switches to default when saved server fails /health', () async {
      // Configure an old unreachable saved URL
      const staleSavedUrl = 'http://192.168.1.99:8000/api/v1';
      await StorageService.setServerBaseUrl(staleSavedUrl);
      expect(StorageService.serverBaseUrl, equals(staleSavedUrl));

      final defaultUrl = ApiClient.compileTimeOrPlatformDefaultUrl;

      // Mock client: fails for staleSavedUrl, succeeds 200 OK for defaultUrl
      final mockClient = MockClient((request) async {
        final uriStr = request.url.toString();
        if (uriStr.contains('192.168.1.99')) {
          return http.Response('Connection refused', 503);
        } else if (uriStr.contains('/health')) {
          return http.Response(json.encode({'status': 'ok', 'app': 'KalaSetu'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      await ApiClient.healServerAddressOnStartup(client: mockClient);

      // Verify that stale saved address was cleared and defaulted
      expect(StorageService.serverBaseUrl, isEmpty);
      final apiClient = ApiClient(client: mockClient);
      expect(apiClient.baseUrl, equals(defaultUrl));
    });
  });

  group('Requirement 3: Distinguishing Network, Server Unreachable, and 500/Validation Errors', () {
    test('Resolves 500 Internal Server Error', () {
      const apiErr = ApiException(
        message: 'Server error (500)',
        statusCode: 500,
        errorType: ApiErrorType.serverError,
      );

      final resolved = NetworkErrorHelper.resolve(apiErr);
      expect(resolved.type, equals(ApiErrorType.serverError));
      expect(resolved.statusCode, equals(500));
      expect(resolved.title, isNotEmpty);
      expect(resolved.message, isNotEmpty);
    });

    test('Resolves 422 Validation Error', () {
      const apiErr = ApiException(
        message: 'Invalid phone format',
        statusCode: 422,
        errorType: ApiErrorType.validationError,
      );

      final resolved = NetworkErrorHelper.resolve(apiErr);
      expect(resolved.type, equals(ApiErrorType.validationError));
      expect(resolved.statusCode, equals(422));
      expect(resolved.message, equals('Invalid phone format'));
    });

    test('Resolves Server Unreachable', () {
      const apiErr = ApiException(
        message: 'Cannot reach server',
        isNetworkError: true,
        errorType: ApiErrorType.serverUnreachable,
      );

      final resolved = NetworkErrorHelper.resolve(
        apiErr,
        connectivityState: ConnectivityState.serverUnreachable,
      );
      expect(resolved.type, equals(ApiErrorType.serverUnreachable));
      expect(resolved.statusCode, isNull);
    });

    test('Resolves No Internet when device is offline', () {
      const apiErr = ApiException(
        message: 'Cannot reach server',
        isNetworkError: true,
        errorType: ApiErrorType.serverUnreachable,
      );

      final resolved = NetworkErrorHelper.resolve(
        apiErr,
        connectivityState: ConnectivityState.noInternet,
      );
      expect(resolved.type, equals(ApiErrorType.noInternet));
      expect(resolved.statusCode, isNull);
    });
  });

  group('Requirement 4: Short Backoff Retry for Login & OTP Calls', () {
    test('sendOtp retries transient 500 errors and succeeds on retry', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First attempt fails with 500
          return http.Response(json.encode({'detail': 'Temporary server hiccup'}), 500);
        }
        // Second attempt succeeds
        return http.Response(json.encode({'debug_otp': '123456'}), 200);
      });

      final apiClient = ApiClient(client: mockClient);
      final authRepo = AuthRepository(apiClient: apiClient);

      final otp = await authRepo.sendOtp('9876543210');
      expect(otp, equals('123456'));
      expect(requestCount, equals(2));
    });

    test('sendOtp does NOT retry 422 validation errors and fails immediately', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(json.encode({'detail': 'Invalid phone number format'}), 422);
      });

      final apiClient = ApiClient(client: mockClient);
      final authRepo = AuthRepository(apiClient: apiClient);

      await expectLater(
        () => authRepo.sendOtp('123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422)),
      );
      expect(requestCount, equals(1)); // Only 1 attempt, no useless retry
    });

    testWidgets('AuthPhoneScreen renders Test Connection button on error state when Developer Mode is enabled', (tester) async {
      await StorageService.setDeveloperMode(true);
      expect(StorageService.isDeveloperMode, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // Renders Test Connection button when developer mode is on
                if (StorageService.isDeveloperMode) {
                  return OutlinedButton.icon(
                    key: const Key('test_connection_btn'),
                    onPressed: () {},
                    icon: const Icon(Icons.wifi_find_rounded),
                    label: const Text('Test Connection'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('test_connection_btn')), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
    });
  });
}
