import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class DeveloperErrorInfo {
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? responseBody;
  final String? rawError;
  final String errorType; // 'no_internet', 'server_unreachable', 'server_error', 'validation_error', 'unknown'
  final String? friendlyMessage;
  final int? httpStatus;
  final String? geminiStatus;
  final String? modelName;
  final String? hint;

  const DeveloperErrorInfo({
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.responseBody,
    this.rawError,
    required this.errorType,
    this.friendlyMessage,
    this.httpStatus,
    this.geminiStatus,
    this.modelName,
    this.hint,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'url': url,
        'status_code': statusCode,
        'response_body': responseBody,
        'raw_error': rawError,
        'error_type': errorType,
        'friendly_message': friendlyMessage,
        'http_status': httpStatus,
        'gemini_status': geminiStatus,
        'model_name': modelName,
        'hint': hint,
      };

  static DeveloperErrorInfo? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    try {
      final respBody = map['response_body']?.toString();
      final rawErr = map['raw_error']?.toString();
      final statusCode = map['status_code'] is num ? (map['status_code'] as num).toInt() : null;

      int? parsedHttpStatus = map['http_status'] is num ? (map['http_status'] as num).toInt() : null;
      String? parsedGeminiStatus = map['gemini_status']?.toString();
      String? parsedModel = map['model_name']?.toString() ?? map['model']?.toString();
      String? parsedHint = map['hint']?.toString();

      // If not stored explicitly, extract from responseBody or rawError
      final combined = '${respBody ?? ""} ${rawErr ?? ""}';
      if (respBody != null && respBody.isNotEmpty) {
        try {
          final decoded = json.decode(respBody);
          Map? target;
          if (decoded is Map) {
            if (decoded['detail'] is Map) {
              target = decoded['detail'] as Map;
            } else if (decoded['error'] is Map) {
              target = decoded['error'] as Map;
            } else {
              target = decoded;
            }
          }
          if (target != null) {
            parsedHttpStatus ??= (target['http_status'] as num?)?.toInt() ?? (target['code'] as num?)?.toInt();
            parsedGeminiStatus ??= target['gemini_status']?.toString() ?? target['status']?.toString();
            parsedModel ??= target['model']?.toString() ?? target['model_name']?.toString();
            parsedHint ??= target['hint']?.toString();
          }
        } catch (_) {}
      }

      // Regex inference if still missing
      if (parsedGeminiStatus == null) {
        for (final s in ['RESOURCE_EXHAUSTED', 'PERMISSION_DENIED', 'NOT_FOUND', 'INVALID_ARGUMENT', 'NO_IMAGE_RETURNED', 'UNAUTHENTICATED']) {
          if (combined.contains(s)) {
            parsedGeminiStatus = s;
            break;
          }
        }
      }
      parsedHttpStatus ??= statusCode;
      if (parsedModel == null) {
        final modelMatch = RegExp(r'(gemini-[a-zA-Z0-9\.\-]+|imagen-[a-zA-Z0-9\.\-]+)').firstMatch(combined);
        if (modelMatch != null) {
          parsedModel = modelMatch.group(1);
        }
      }
      if (parsedHint == null) {
        final lower = combined.toLowerCase();
        if (parsedGeminiStatus == 'NO_IMAGE_RETURNED' || lower.contains('no image')) {
          parsedHint = 'no image returned';
        } else if (parsedHttpStatus == 429 || parsedGeminiStatus == 'RESOURCE_EXHAUSTED' || lower.contains('quota')) {
          if (lower.contains('limit: 0') || lower.contains('limit 0')) {
            parsedHint = 'billing not enabled (free tier request limit is 0 for this model)';
          } else {
            parsedHint = 'quota limit reached';
          }
        } else if (parsedHttpStatus == 404 || parsedGeminiStatus == 'NOT_FOUND') {
          parsedHint = 'model name not found';
        } else if (parsedHttpStatus == 403 || parsedGeminiStatus == 'PERMISSION_DENIED') {
          parsedHint = 'permission denied';
        }
      }

      return DeveloperErrorInfo(
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
        method: map['method']?.toString() ?? 'GET',
        url: map['url']?.toString() ?? '',
        statusCode: statusCode,
        responseBody: respBody,
        rawError: rawErr,
        errorType: map['error_type']?.toString() ?? 'unknown',
        friendlyMessage: map['friendly_message']?.toString(),
        httpStatus: parsedHttpStatus,
        geminiStatus: parsedGeminiStatus,
        modelName: parsedModel,
        hint: parsedHint,
      );
    } catch (_) {
      return null;
    }
  }

  String toJson() => json.encode(toMap());

  static DeveloperErrorInfo? fromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map) return fromMap(decoded);
    } catch (_) {}
    return null;
  }
}

class DeveloperLogService {
  DeveloperLogService._();

  static final ValueNotifier<DeveloperErrorInfo?> lastErrorNotifier =
      ValueNotifier<DeveloperErrorInfo?>(null);

  static final List<String> _recentLogs = [];
  static final ValueNotifier<List<String>> recentLogsNotifier =
      ValueNotifier<List<String>>([]);

  static void init() {
    final savedJson = StorageService.lastErrorJson;
    if (savedJson != null && savedJson.isNotEmpty) {
      lastErrorNotifier.value = DeveloperErrorInfo.fromJson(savedJson);
    }
  }

  /// Scrubs sensitive values (tokens, passwords, OTPs, authorization headers, API keys)
  /// so secrets are never logged or stored.
  static String scrubSecrets(String input) {
    if (input.isEmpty) return input;
    // Scrub sensitive JSON keys: token, access_token, refresh_token, password, secret, otp, debug_otp, api_key
    final jsonKeyRegex = RegExp(
      r'("(?:token|access_token|refresh_token|password|secret|otp|debug_otp|authorization|api_key|gemini_api_key)":\s*)("[^"]*"|\d+)',
      caseSensitive: false,
    );
    var scrubbed = input.replaceAllMapped(jsonKeyRegex, (m) => '${m.group(1)}"[REDACTED]"');

    // Scrub Bearer tokens in headers
    final bearerRegex = RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false);
    scrubbed = scrubbed.replaceAll(bearerRegex, 'Bearer [REDACTED]');

    // Scrub Google AI Studio and custom API keys
    final apiKeyRegex = RegExp(r'(?:AIza[0-9A-Za-z-_]{35}|AQ\.[0-9A-Za-z-_]{30,})', caseSensitive: false);
    scrubbed = scrubbed.replaceAll(apiKeyRegex, '[REDACTED_API_KEY]');

    return scrubbed;
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] ${scrubSecrets(message)}';
    debugPrint('[DeveloperLog] $logLine');

    _recentLogs.add(logLine);
    if (_recentLogs.length > 50) {
      _recentLogs.removeAt(0);
    }
    recentLogsNotifier.value = List.unmodifiable(_recentLogs);
  }

  static void recordError({
    required String method,
    required String url,
    int? statusCode,
    String? responseBody,
    String? rawError,
    required String errorType,
    String? friendlyMessage,
    int? httpStatus,
    String? geminiStatus,
    String? modelName,
    String? hint,
  }) {
    final scrubbedUrl = scrubSecrets(url);
    final scrubbedBody = responseBody != null ? scrubSecrets(responseBody) : null;
    final scrubbedError = rawError != null ? scrubSecrets(rawError) : null;

    final tempMap = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'method': method.toUpperCase(),
      'url': scrubbedUrl,
      'status_code': statusCode,
      'response_body': scrubbedBody,
      'raw_error': scrubbedError,
      'error_type': errorType,
      'friendly_message': friendlyMessage,
      'http_status': httpStatus,
      'gemini_status': geminiStatus,
      'model_name': modelName,
      'hint': hint,
    };

    final info = DeveloperErrorInfo.fromMap(tempMap) ?? DeveloperErrorInfo(
      timestamp: DateTime.now(),
      method: method.toUpperCase(),
      url: scrubbedUrl,
      statusCode: statusCode,
      responseBody: scrubbedBody,
      rawError: scrubbedError,
      errorType: errorType,
      friendlyMessage: friendlyMessage,
      httpStatus: httpStatus,
      geminiStatus: geminiStatus,
      modelName: modelName,
      hint: hint,
    );

    lastErrorNotifier.value = info;
    StorageService.setLastErrorJson(info.toJson());

    // Print to developer console
    final statusStr = statusCode != null ? 'HTTP $statusCode' : 'NETWORK_ERROR';
    debugPrint(
      '--------------------------------------------------\n'
      '[DeveloperConsole] Request Failure:\n'
      '  Status: $statusStr ($errorType)\n'
      '  URL: ${info.method} ${info.url}\n'
      '  HTTP Status: ${info.httpStatus ?? "(none)"}\n'
      '  Gemini Status: ${info.geminiStatus ?? "(none)"}\n'
      '  Model: ${info.modelName ?? "(none)"}\n'
      '  Hint: ${info.hint ?? "(none)"}\n'
      '  Response Body: ${info.responseBody ?? "(none)"}\n'
      '--------------------------------------------------',
    );

    log('ERROR: ${info.method} ${info.url} -> $statusStr | Gemini: ${info.geminiStatus ?? "N/A"} | Model: ${info.modelName ?? "N/A"} | Hint: ${info.hint ?? "N/A"}');
  }

  static Future<void> clearLastError() async {
    lastErrorNotifier.value = null;
    await StorageService.clearLastError();
    log('Cleared last error record.');
  }
}
