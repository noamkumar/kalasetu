import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/network_error_helper.dart';
import 'package:frontend/data/api/api_client.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/features/auth/auth_otp_screen.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _map.containsKey(key) ? _map[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _map.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _map.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    final authBox = _FakeBox();
    final settingsBox = _FakeBox();
    await settingsBox.put(StorageService.keySimpleMode, false);
    await settingsBox.put(StorageService.keyAutoSpeakEnabled, false);
    StorageService.initForTesting(authBox: authBox, settingsBox: settingsBox);
  });

  Widget buildTestableWidget(Widget child) {
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(400, 800),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('AuthRepository Phone Normalization & Demo Detection', () {
    test('normalizePhone formats Indian numbers to E.164 +91 format', () {
      expect(AuthRepository.normalizePhone('9876543210'), equals('+919876543210'));
      expect(AuthRepository.normalizePhone('+919876543210'), equals('+919876543210'));
      expect(AuthRepository.normalizePhone('09876543210'), equals('+919876543210'));
      expect(AuthRepository.normalizePhone('919876543210'), equals('+919876543210'));
      expect(AuthRepository.normalizePhone('+91 98765-43210'), equals('+919876543210'));
      expect(AuthRepository.normalizePhone(' 98765 43210 '), equals('+919876543210'));
    });

    test('isDemoPhone accurately identifies all 5 documented demo accounts', () {
      final demoNumbers = [
        '9876543210', '+919876543210',
        '9876543211', '+919876543211',
        '9876543212', '+919876543212',
        '9876543220', '+919876543220',
        '9876543221', '+919876543221',
      ];
      for (final num in demoNumbers) {
        expect(AuthRepository.isDemoPhone(num), isTrue,
            reason: '$num should be recognized as a demo phone');
      }

      expect(AuthRepository.isDemoPhone('9999999999'), isFalse);
      expect(AuthRepository.isDemoPhone('+919999999999'), isFalse);
      expect(AuthRepository.isDemoPhone('9123456789'), isFalse);
    });

    test('sendOtp normalizes 10-digit number before posting to API', () async {
      String? sentPhone;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/auth/otp/send')) {
          final body = json.decode(request.body) as Map<String, dynamic>;
          sentPhone = body['phone'];
          return http.Response(
            json.encode({'message': 'OTP sent successfully', 'debug_otp': '123456'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final authRepo = AuthRepository(apiClient: apiClient);

      final debugOtp = await authRepo.sendOtp('9876543210');
      expect(sentPhone, equals('+919876543210'));
      expect(debugOtp, equals('123456'));
    });

    test('verifyOtp normalizes phone before posting to API', () async {
      String? sentPhone;
      String? sentOtp;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/auth/otp/verify')) {
          final body = json.decode(request.body) as Map<String, dynamic>;
          sentPhone = body['phone'];
          sentOtp = body['otp'];
          return http.Response(
            json.encode({
              'access_token': 'test_token',
              'refresh_token': 'test_refresh',
              'is_new_user': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/api/v1/me')) {
          return http.Response(
            json.encode({
              'name': 'Rameshwar Prajapati',
              'role': 'artisan',
              'craft_type': 'Pottery',
              'cluster_location': 'Gorakhpur',
              'state': 'Uttar Pradesh',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final authRepo = AuthRepository(apiClient: apiClient);

      final isNewUser = await authRepo.verifyOtp('9876543210', '123456');
      expect(sentPhone, equals('+919876543210'));
      expect(sentOtp, equals('123456'));
      expect(isNewUser, isFalse);
    });
  });

  group('NetworkErrorHelper OTP Discrimination', () {
    test('Resolves 400 OTP error to check_otp_title rather than check_phone_title', () {
      const otpErr = ApiException(
        message: 'Invalid or expired OTP code',
        statusCode: 400,
        errorType: ApiErrorType.validationError,
      );

      final resolved = NetworkErrorHelper.resolve(otpErr);
      expect(resolved.type, equals(ApiErrorType.validationError));
      expect(resolved.statusCode, equals(400));
      expect(resolved.message, equals('Invalid or expired OTP code'));
      expect(resolved.title, anyOf(equals('Enter Verification Code'), equals('check_otp_title')));
    });
  });

  group('AuthOtpScreen Widget Rendering', () {
    testWidgets('Demo account auto-fills 123456 and renders demo hint banner', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        buildTestableWidget(
          const AuthOtpScreen(phone: '9876543210'),
        ),
      );
      await tester.pumpAndSettle();

      // Demo banner icon is present
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // OTP TextField has 123456 auto-filled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('123456'));

      // Subtitle cleanly displays +91 without duplication
      expect(find.textContaining('+91 9876543210'), findsOneWidget);
    });

    testWidgets('Non-demo real account hides demo hint banner and does NOT prefill 123456', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        buildTestableWidget(
          const AuthOtpScreen(phone: '9123456789'),
        ),
      );
      await tester.pumpAndSettle();

      // Demo banner icon is NOT present
      expect(find.byIcon(Icons.info_outline), findsNothing);

      // OTP TextField is empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);

      // Subtitle cleanly displays +91 9123456789
      expect(find.textContaining('+91 9123456789'), findsOneWidget);
    });
  });
}
