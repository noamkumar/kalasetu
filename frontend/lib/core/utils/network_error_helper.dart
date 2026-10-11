import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import '../services/connectivity_service.dart';
import '../widgets/connectivity_pill.dart';
import '../../data/api/api_client.dart';

class ResolvedNetworkError {
  final String title;
  final String message;
  final ApiErrorType type;
  final int? statusCode;

  const ResolvedNetworkError({
    required this.title,
    required this.message,
    required this.type,
    this.statusCode,
  });
}

class NetworkErrorHelper {
  NetworkErrorHelper._();

  /// Resolves any network or API error into distinct user-friendly, spoken messages:
  /// (a) No internet
  /// (b) Server not reachable
  /// (c) Server error (500/validation)
  static ResolvedNetworkError resolve(
    dynamic error, {
    ConnectivityState? connectivityState,
  }) {
    if (error is ApiException) {
      if (error.statusCode != null) {
        if (error.statusCode == 400 || error.statusCode == 422) {
          final isFriendly = error.message.isNotEmpty &&
              !error.message.startsWith('Server error') &&
              !error.message.contains('{');
          return ResolvedNetworkError(
            title: 'check_phone_title'.tr(),
            message: isFriendly ? error.message : 'error_validation_msg'.tr(),
            type: ApiErrorType.validationError,
            statusCode: error.statusCode,
          );
        } else if (error.statusCode! >= 500) {
          return ResolvedNetworkError(
            title: 'error_server_error_title'.tr(),
            message: 'error_server_error_msg'.tr(),
            type: ApiErrorType.serverError,
            statusCode: error.statusCode,
          );
        } else {
          return ResolvedNetworkError(
            title: 'error_server_error_title'.tr(),
            message: 'error_server_error_msg'.tr(),
            type: ApiErrorType.serverError,
            statusCode: error.statusCode,
          );
        }
      }

      if (error.errorType == ApiErrorType.noInternet) {
        return ResolvedNetworkError(
          title: 'error_no_internet_title'.tr(),
          message: 'error_no_internet_msg'.tr(),
          type: ApiErrorType.noInternet,
        );
      }

      if (error.errorType == ApiErrorType.serverUnreachable || error.isNetworkError || error.isTimeout) {
        bool isPhysicallyOffline = false;
        if (connectivityState != null) {
          isPhysicallyOffline = connectivityState == ConnectivityState.noInternet;
        } else {
          try {
            isPhysicallyOffline =
                ConnectivityService.instance.state == ConnectivityState.noInternet;
          } catch (_) {}
        }
        if (isPhysicallyOffline) {
          return ResolvedNetworkError(
            title: 'error_no_internet_title'.tr(),
            message: 'error_no_internet_msg'.tr(),
            type: ApiErrorType.noInternet,
          );
        }
        return ResolvedNetworkError(
          title: 'error_server_unreachable_title'.tr(),
          message: 'error_server_unreachable_msg'.tr(),
          type: ApiErrorType.serverUnreachable,
        );
      }
    }

    if (error is SocketException) {
      bool isPhysicallyOffline = false;
      if (connectivityState != null) {
        isPhysicallyOffline = connectivityState == ConnectivityState.noInternet;
      } else {
        try {
          isPhysicallyOffline =
              ConnectivityService.instance.state == ConnectivityState.noInternet;
        } catch (_) {}
      }
      if (isPhysicallyOffline) {
        return ResolvedNetworkError(
          title: 'error_no_internet_title'.tr(),
          message: 'error_no_internet_msg'.tr(),
          type: ApiErrorType.noInternet,
        );
      }
      return ResolvedNetworkError(
        title: 'error_server_unreachable_title'.tr(),
        message: 'error_server_unreachable_msg'.tr(),
        type: ApiErrorType.serverUnreachable,
      );
    }

    if (error is TimeoutException) {
      return ResolvedNetworkError(
        title: 'error_server_unreachable_title'.tr(),
        message: 'error_server_unreachable_msg'.tr(),
        type: ApiErrorType.serverUnreachable,
      );
    }

    return ResolvedNetworkError(
      title: 'error_server_error_title'.tr(),
      message: 'error_server_error_msg'.tr(),
      type: ApiErrorType.serverError,
    );
  }
}
