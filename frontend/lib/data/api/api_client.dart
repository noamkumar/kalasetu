import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/services/developer_log_service.dart';
import '../../core/services/storage_service.dart';

enum ApiErrorType {
  noInternet,
  serverUnreachable,
  serverError,
  validationError,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isTimeout;
  final String? url;
  final String? method;
  final String? responseBody;
  final ApiErrorType errorType;

  const ApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.url,
    this.method,
    this.responseBody,
    this.errorType = ApiErrorType.unknown,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static const String productionBaseUrl = 'https://kalasetu-backend-s3uq.onrender.com/api/v1';
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000';
  static String get defaultBaseUrl => kReleaseMode ? productionBaseUrl : emulatorBaseUrl;
  static const Duration defaultTimeout = Duration(seconds: 25);
  static const Duration uploadTimeout = Duration(seconds: 75);

  final String? _configuredBaseUrl;
  final http.Client _client;

  ApiClient({
    String? baseUrl,
    http.Client? client,
  })  : _configuredBaseUrl = baseUrl,
        _client = client ?? http.Client();

  /// Returns the active base URL:
  /// 1. Value manually set at runtime via Settings > Developer (stored in Hive)
  /// 2. Value passed into constructor
  /// 3. Dart define --dart-define=API_BASE_URL=...
  /// 4. Default: Render production in release mode, emulator loopback in debug mode
  String get baseUrl {
    // 1. Value manually set at runtime via Settings > Developer (stored in Hive)
    final runtimeStored = StorageService.serverBaseUrl;
    if (runtimeStored.isNotEmpty) {
      return runtimeStored;
    }
    // 2. Explicit constructor override
    final configured = _configuredBaseUrl;
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    // 3. Compile-time --dart-define=API_BASE_URL=...
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // 4. Default fallback
    return defaultBaseUrl;
  }

  /// Default server URL based on compile-time --dart-define or fallback
  static String get compileTimeOrPlatformDefaultUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultBaseUrl;
  }

  /// Requirement 2:
  /// On app start, if the saved server address does not answer /health but the default one does,
  /// use the default and tell me in the developer log.
  static Future<void> healServerAddressOnStartup({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    final savedUrl = StorageService.serverBaseUrl;
    final defaultUrl = compileTimeOrPlatformDefaultUrl;

    if (savedUrl.isEmpty) {
      DeveloperLogService.log('Active server URL is default: $defaultUrl');
      return;
    }

    // 1. Test saved URL
    final savedOk = await _pingUrl(httpClient, savedUrl);
    if (savedOk) {
      DeveloperLogService.log('Saved server address ($savedUrl) answered /health successfully.');
      return;
    }

    DeveloperLogService.log(
      'Saved server address ($savedUrl) did NOT answer /health. Testing default address ($defaultUrl)...',
    );

    // 2. Test default URL
    final defaultOk = await _pingUrl(httpClient, defaultUrl);
    if (defaultOk) {
      await StorageService.clearServerBaseUrl();
      DeveloperLogService.log(
        'Switched to default server address! Saved address ($savedUrl) was unreachable, '
        'but default address ($defaultUrl) answered /health. Stale saved address cleared.',
      );
      return;
    }

    // 3. Also test 127.0.0.1:8000 for ADB reverse on Android phone
    const localhostUrl = 'http://127.0.0.1:8000/api/v1';
    if (savedUrl != localhostUrl && defaultUrl != localhostUrl) {
      final localhostOk = await _pingUrl(httpClient, localhostUrl);
      if (localhostOk) {
        await StorageService.setServerBaseUrl(localhostUrl);
        DeveloperLogService.log(
          'Switched to ADB reverse localhost ($localhostUrl)! '
          'Saved address ($savedUrl) failed, but $localhostUrl answered /health successfully.',
        );
        return;
      }
    }

    DeveloperLogService.log(
      'Neither saved server address ($savedUrl) nor default ($defaultUrl) answered /health.',
    );
  }

  static Future<bool> _pingUrl(http.Client client, String targetUrl) async {
    try {
      String clean = targetUrl.trim();
      if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
      final healthUri = clean.endsWith('/api/v1')
          ? Uri.parse('$clean/health')
          : Uri.parse('$clean/health');
      final resp = await client.get(healthUri).timeout(const Duration(milliseconds: 5000));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  /// Returns the root host and port (e.g., http://192.168.1.10:8000) stripped of any path
  String get rootUrl {
    final clean = baseUrl.trim();
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portStr';
    }
    return clean;
  }

  /// Resolve any relative media URL (like /static/uploads/abc.webp) against the root server URL
  String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$rootUrl$cleanPath';
  }

  Map<String, String> _buildHeaders([Map<String, String>? extra]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = StorageService.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    String base = baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    String cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    // Deduplicate /api/v1 if both base and path have it
    if (base.endsWith('/api/v1') && cleanPath.startsWith('/api/v1/')) {
      cleanPath = cleanPath.substring('/api/v1'.length);
    }

    final fullUrl = '$base$cleanPath';

    if (queryParams != null && queryParams.isNotEmpty) {
      final filtered = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      )..removeWhere((k, v) => v.isEmpty);
      return Uri.parse(fullUrl).replace(queryParameters: filtered);
    }
    return Uri.parse(fullUrl);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams, Duration? timeout}) async {
    final uri = _buildUri(path, queryParams);
    try {
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response, method: 'GET', url: uri.toString());
    } on SocketException catch (e) {
      DeveloperLogService.recordError(
        method: 'GET',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Cannot reach KalaSetu server at $baseUrl',
      );
      throw ApiException(
        message: 'Cannot reach KalaSetu server at $baseUrl. Ensure your PC and phone are on the same Wi-Fi.',
        isNetworkError: true,
        method: 'GET',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      DeveloperLogService.recordError(
        method: 'GET',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Network request timed out.',
      );
      throw ApiException(
        message: 'Network is running slow. Server took too long to respond. Working in offline mode.',
        isNetworkError: true,
        isTimeout: true,
        method: 'GET',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on http.ClientException catch (e) {
      DeveloperLogService.recordError(
        method: 'GET',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: e.message,
      );
      throw ApiException(
        message: 'Network error: ${e.message}. Using offline cache.',
        isNetworkError: true,
        method: 'GET',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Request failed: $e', method: 'GET', url: uri.toString());
    }
  }

  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    final uri = _buildUri(path);
    final startTime = DateTime.now();
    DeveloperLogService.log(
      '[HTTP REQUEST START] POST ${uri.path} | Host: ${uri.host} | Time: ${startTime.toIso8601String()}',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      DeveloperLogService.log(
        '[HTTP REQUEST COMPLETED] POST ${uri.path} -> HTTP ${response.statusCode} (${durationMs}ms)',
      );
      return _processResponse(response, method: 'POST', url: uri.toString());
    } on SocketException catch (e) {
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      final sanitized = DeveloperLogService.scrubSecrets(e.toString());
      DeveloperLogService.log(
        '[HTTP FAILED PRE-SERVER] POST ${uri.path} -> SocketException: Failed before reaching server (${durationMs}ms) | $sanitized',
      );
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Cannot reach KalaSetu server at $baseUrl',
      );
      throw ApiException(
        message: 'Cannot reach KalaSetu server at $baseUrl. Ensure your PC and phone are on the same Wi-Fi.',
        isNetworkError: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      DeveloperLogService.log(
        '[HTTP FAILED PRE-SERVER] POST ${uri.path} -> TimeoutException: Timed out after ${durationMs}ms',
      );
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Network request timed out.',
      );
      throw ApiException(
        message: 'Network request timed out. Server took too long to respond.',
        isNetworkError: true,
        isTimeout: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on http.ClientException catch (e) {
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      DeveloperLogService.log(
        '[HTTP FAILED PRE-SERVER] POST ${uri.path} -> ClientException: ${e.message} (${durationMs}ms)',
      );
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: e.message,
      );
      throw ApiException(
        message: 'Network error: ${e.message}.',
        isNetworkError: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      final sanitized = DeveloperLogService.scrubSecrets(e.toString());
      DeveloperLogService.log(
        '[HTTP FAILED] POST ${uri.path} -> Error (${durationMs}ms): $sanitized',
      );
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Request failed: $e', method: 'POST', url: uri.toString());
    }
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    required String fileField,
    required String filePath,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path);
    try {
      final request = http.MultipartRequest('POST', uri);
      final token = StorageService.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));

      final streamedResponse = await _client.send(request).timeout(timeout ?? uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response, method: 'POST', url: uri.toString());
    } on SocketException catch (e) {
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Cannot reach KalaSetu server at $baseUrl',
      );
      throw ApiException(
        message: 'Cannot reach KalaSetu server at $baseUrl. Photo saved locally.',
        isNetworkError: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: 'Photo upload timed out.',
      );
      throw ApiException(
        message: 'Photo upload/AI processing timed out due to slow network. Saved locally.',
        isNetworkError: true,
        isTimeout: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on http.ClientException catch (e) {
      DeveloperLogService.recordError(
        method: 'POST',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
        friendlyMessage: e.message,
      );
      throw ApiException(
        message: 'Network upload error: ${e.message}.',
        isNetworkError: true,
        method: 'POST',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Upload failed: $e', method: 'POST', url: uri.toString());
    }
  }

  Future<dynamic> patch(String path, {dynamic body, Duration? timeout}) async {
    final uri = _buildUri(path);
    try {
      final response = await _client
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response, method: 'PATCH', url: uri.toString());
    } on SocketException catch (e) {
      DeveloperLogService.recordError(
        method: 'PATCH',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Cannot reach KalaSetu server. Action saved offline.',
        isNetworkError: true,
        method: 'PATCH',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      DeveloperLogService.recordError(
        method: 'PATCH',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Network timed out. Action saved offline.',
        isNetworkError: true,
        isTimeout: true,
        method: 'PATCH',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Request failed: $e', method: 'PATCH', url: uri.toString());
    }
  }

  Future<dynamic> delete(String path, {Duration? timeout}) async {
    final uri = _buildUri(path);
    try {
      final response = await _client
          .delete(uri, headers: _buildHeaders())
          .timeout(timeout ?? defaultTimeout);
      return _processResponse(response, method: 'DELETE', url: uri.toString());
    } on SocketException catch (e) {
      DeveloperLogService.recordError(
        method: 'DELETE',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Cannot reach KalaSetu server. Action saved offline.',
        isNetworkError: true,
        method: 'DELETE',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      DeveloperLogService.recordError(
        method: 'DELETE',
        url: uri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Network timed out.',
        isNetworkError: true,
        isTimeout: true,
        method: 'DELETE',
        url: uri.toString(),
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Request failed: $e', method: 'DELETE', url: uri.toString());
    }
  }

  /// Ping the server to test reachability (e.g. from Settings > Developer)
  Future<Map<String, dynamic>> testConnection([String? candidateUrl]) async {
    final targetUrl = candidateUrl != null && candidateUrl.trim().isNotEmpty
        ? candidateUrl.trim()
        : baseUrl;

    String cleanBase = targetUrl.endsWith('/')
        ? targetUrl.substring(0, targetUrl.length - 1)
        : targetUrl;

    // Try health check at both cleanBase/health and cleanBase/api/v1/health
    final healthUri = cleanBase.endsWith('/api/v1')
        ? Uri.parse('$cleanBase/health')
        : Uri.parse('$cleanBase/health');

    try {
      final resp = await _client.get(healthUri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      } else {
        DeveloperLogService.recordError(
          method: 'GET',
          url: healthUri.toString(),
          statusCode: resp.statusCode,
          responseBody: resp.body,
          errorType: 'server_error',
        );
        throw ApiException(
          message: 'Server responded with HTTP ${resp.statusCode}',
          statusCode: resp.statusCode,
          url: healthUri.toString(),
          method: 'GET',
          responseBody: resp.body,
          errorType: ApiErrorType.serverError,
        );
      }
    } on SocketException catch (e) {
      DeveloperLogService.recordError(
        method: 'GET',
        url: healthUri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Connection refused. Check that your PC and phone share the same Wi-Fi and firewall allows port 8000.',
        isNetworkError: true,
        url: healthUri.toString(),
        method: 'GET',
        errorType: ApiErrorType.serverUnreachable,
      );
    } on TimeoutException catch (e) {
      DeveloperLogService.recordError(
        method: 'GET',
        url: healthUri.toString(),
        rawError: e.toString(),
        errorType: 'server_unreachable',
      );
      throw ApiException(
        message: 'Connection timed out after 6 seconds. Check IP address.',
        isNetworkError: true,
        isTimeout: true,
        url: healthUri.toString(),
        method: 'GET',
        errorType: ApiErrorType.serverUnreachable,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Ping failed: $e', isNetworkError: true);
    }
  }

  dynamic _processResponse(
    http.Response response, {
    String method = 'GET',
    String? url,
  }) {
    final sanitizedBody = DeveloperLogService.scrubSecrets(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      DeveloperLogService.log(
        '[API CLIENT] $method ${url ?? ""} -> HTTP ${response.statusCode}',
      );
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      DeveloperLogService.log(
        '[API CLIENT ERROR] $method ${url ?? ""} -> HTTP ${response.statusCode} | Body: $sanitizedBody',
      );
      String errMsg = 'Server error (${response.statusCode})';

      int? aiHttpStatus;
      String? aiGeminiStatus;
      String? aiModel;
      String? aiHint;

      try {
        final errJson = json.decode(response.body);
        if (errJson is Map && errJson.containsKey('detail')) {
          final detail = errJson['detail'];
          if (detail is Map) {
            errMsg = detail['message']?.toString() ?? detail.toString();
            aiHttpStatus = (detail['http_status'] as num?)?.toInt();
            aiGeminiStatus = detail['gemini_status']?.toString();
            aiModel = detail['model']?.toString();
            aiHint = detail['hint']?.toString();
          } else {
            errMsg = detail.toString();
          }
        } else if (errJson is Map && errJson.containsKey('message')) {
          errMsg = errJson['message'].toString();
          aiHttpStatus = (errJson['http_status'] as num?)?.toInt();
          aiGeminiStatus = errJson['gemini_status']?.toString();
          aiModel = errJson['model']?.toString();
          aiHint = errJson['hint']?.toString();
        }
      } catch (_) {}

      final isValidation = response.statusCode == 400 || response.statusCode == 422;
      final errorType = isValidation ? ApiErrorType.validationError : ApiErrorType.serverError;

      DeveloperLogService.recordError(
        method: method,
        url: url ?? '',
        statusCode: response.statusCode,
        responseBody: response.body,
        rawError: errMsg,
        errorType: errorType.name,
        friendlyMessage: errMsg,
        httpStatus: aiHttpStatus,
        geminiStatus: aiGeminiStatus,
        modelName: aiModel,
        hint: aiHint,
      );

      throw ApiException(
        message: errMsg,
        statusCode: response.statusCode,
        url: url,
        method: method,
        responseBody: response.body,
        errorType: errorType,
      );
    }
  }
}
