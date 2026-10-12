import '../../core/services/developer_log_service.dart';
import '../../core/services/storage_service.dart';
import '../api/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;

  static const Set<String> demoPhoneNumbers = {
    '+919876543210', '9876543210',
    '+919876543211', '9876543211',
    '+919876543212', '9876543212',
    '+919876543220', '9876543220',
    '+919876543221', '9876543221',
  };

  static String normalizePhone(String rawPhone) {
    final clean = rawPhone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.startsWith('+91') && clean.length == 13) {
      return clean;
    }
    if (clean.startsWith('+')) {
      return clean;
    }
    if (clean.startsWith('0') && clean.length == 11) {
      return '+91${clean.substring(1)}';
    }
    if (clean.startsWith('91') && clean.length == 12) {
      return '+$clean';
    }
    if (clean.length == 10 && RegExp(r'^\d{10}$').hasMatch(clean)) {
      return '+91$clean';
    }
    return clean;
  }

  static bool isDemoPhone(String rawPhone) {
    final norm = normalizePhone(rawPhone);
    final raw10 = norm.startsWith('+91') ? norm.substring(3) : norm;
    return demoPhoneNumbers.contains(norm) || demoPhoneNumbers.contains(raw10);
  }

  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  bool _isTransient(dynamic error) {
    if (error is ApiException) {
      if (error.statusCode != null) {
        // Do not retry 4xx client validation errors (e.g. 400 invalid phone, 422, 401 invalid OTP)
        if (error.statusCode! >= 400 && error.statusCode! < 500) {
          return false;
        }
        return error.statusCode! >= 500;
      }
      return error.isNetworkError || error.isTimeout;
    }
    return true;
  }

  Future<String?> sendOtp(String phone, {int maxRetries = 2}) async {
    final normalized = normalizePhone(phone);
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await _apiClient.post(
          '/api/v1/auth/otp/send',
          body: {'phone': normalized},
        );
        if (response is Map) {
          return response['debug_otp']?.toString();
        }
        return null;
      } catch (e) {
        if (attempt <= maxRetries && _isTransient(e)) {
          final backoffMs = attempt * 500; // 500ms, then 1000ms
          DeveloperLogService.log('sendOtp attempt $attempt failed ($e). Retrying in ${backoffMs}ms...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<bool> verifyOtp(String phone, String otp, {int maxRetries = 2}) async {
    final normalized = normalizePhone(phone);
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await _apiClient.post(
          '/api/v1/auth/otp/verify',
          body: {'phone': normalized, 'otp': otp},
        );
        if (response is Map && response.containsKey('access_token')) {
          final token = response['access_token'] as String;
          final refresh = response['refresh_token'] as String;
          final isNewUser = response['is_new_user'] as bool? ?? false;

          await StorageService.saveAuthTokens(
            accessToken: token,
            refreshToken: refresh,
            phone: normalized,
          );

          // Attempt to load current profile
          try {
            await fetchProfile();
          } catch (_) {}

          return isNewUser;
        }
        throw const ApiException(message: 'Invalid verification response from server');
      } catch (e) {
        if (attempt <= maxRetries && _isTransient(e)) {
          final backoffMs = attempt * 500;
          DeveloperLogService.log('verifyOtp attempt $attempt failed ($e). Retrying in ${backoffMs}ms...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final profile = await _apiClient.get('/api/v1/me');
    if (profile is Map<String, dynamic>) {
      final role = profile['role']?.toString().toLowerCase() ?? 'artisan';
      await StorageService.setUserRole(role);
      if (role == 'buyer') {
        await StorageService.saveBuyerProfile(
          name: profile['name']?.toString() ?? '',
          address: profile['cluster_location']?.toString() ?? '',
          state: profile['state']?.toString() ?? '',
        );
      } else {
        await StorageService.saveArtisanProfile(
          name: profile['name']?.toString() ?? '',
          craftType: profile['craft_type']?.toString() ?? '',
          location: profile['cluster_location']?.toString() ?? '',
          state: profile['state']?.toString() ?? '',
        );
      }
      return profile;
    }
    return {};
  }

  Future<void> updateProfile({
    required String name,
    required String craftType,
    required String location,
    required String state,
    int? experienceYears,
    String? pehchanId,
  }) async {
    final body = {
      'name': name,
      'role': 'artisan',
      'craft_type': craftType,
      'cluster_location': location,
      'state': state,
      if (experienceYears != null) 'experience_years': experienceYears,
      if (pehchanId != null) 'pehchan_id': pehchanId,
    };

    try {
      await _apiClient.patch('/api/v1/me', body: body);
    } catch (_) {
      // In offline mode, still update local preferences
    }

    await StorageService.saveArtisanProfile(
      name: name,
      craftType: craftType,
      location: location,
      state: state,
    );
  }

  Future<void> updateBuyerProfile({
    required String name,
    required String address,
    required String state,
  }) async {
    final body = {
      'name': name,
      'role': 'buyer',
      'cluster_location': address,
      'state': state,
    };

    try {
      await _apiClient.patch('/api/v1/me', body: body);
    } catch (_) {}

    await StorageService.saveBuyerProfile(
      name: name,
      address: address,
      state: state,
    );
  }

  Future<void> signOut() async {
    await StorageService.clearAuth();
  }
}
