import '../../core/services/developer_log_service.dart';
import '../../core/services/storage_service.dart';
import '../api/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;

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
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await _apiClient.post(
          '/api/v1/auth/otp/send',
          body: {'phone': phone},
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
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        final response = await _apiClient.post(
          '/api/v1/auth/otp/verify',
          body: {'phone': phone, 'otp': otp},
        );
        if (response is Map && response.containsKey('access_token')) {
          final token = response['access_token'] as String;
          final refresh = response['refresh_token'] as String;
          final isNewUser = response['is_new_user'] as bool? ?? false;

          await StorageService.saveAuthTokens(
            accessToken: token,
            refreshToken: refresh,
            phone: phone,
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
