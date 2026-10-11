import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// StorageService manages persistent key-value storage using Hive
/// Spec Section 2 (Settings and cache in Hive)
class StorageService {
  static const String authBoxName = 'kalasetu_auth';
  static const String settingsBoxName = 'kalasetu_settings';

  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyArtisanId = 'artisan_id';
  static const String keyArtisanPhone = 'artisan_phone';
  static const String keyArtisanName = 'artisan_name';
  static const String keyUserRole = 'user_role'; // 'artisan' or 'buyer'
  static const String keyDeliveryAddress = 'delivery_address';
  static const String keyCraftType = 'craft_type';
  static const String keyLocation = 'cluster_location';
  static const String keyState = 'state';

  static const String keyLocale = 'locale';
  static const String keyLanguageChosen = 'language_chosen';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  static Box? _authBox;
  static Box? _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _authBox = await Hive.openBox(authBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
    userRoleNotifier.value = userRole;
    simpleModeNotifier.value = isSimpleMode;
    autoSpeakNotifier.value = isAutoSpeakEnabled;
    largeTextNotifier.value = isLargeTextEnabled;
    fairModeNotifier.value = isFairModeActive;
    assistedNotifier.value = assistedBy;
    developerModeNotifier.value = isDeveloperMode;
  }

  @visibleForTesting
  static void initForTesting({Box? authBox, Box? settingsBox}) {
    if (authBox != null) _authBox = authBox;
    if (settingsBox != null) _settingsBox = settingsBox;
  }

  // --- Auth Getters / Setters ---
  static bool get isLoggedIn =>
      _authBox?.containsKey(keyAccessToken) == true &&
      ((_authBox?.get(keyAccessToken) as String?)?.isNotEmpty ?? false);

  static String? get accessToken => _authBox?.get(keyAccessToken) as String?;
  static String? get refreshToken => _authBox?.get(keyRefreshToken) as String?;
  static String? get artisanId => _authBox?.get(keyArtisanId) as String?;
  static String? get artisanPhone => _authBox?.get(keyArtisanPhone) as String?;
  static String? get artisanName => _authBox?.get(keyArtisanName) as String?;
  static String? get craftType => _authBox?.get(keyCraftType) as String?;
  static String? get buyerName => artisanName;

  // Role: 'artisan' or 'buyer'
  static final ValueNotifier<String> userRoleNotifier =
      ValueNotifier<String>(userRole);

  static String get userRole =>
      _authBox?.get(keyUserRole, defaultValue: 'artisan') as String? ?? 'artisan';

  static bool get isBuyer => userRole == 'buyer';

  static Future<void> setUserRole(String role) async {
    final normalized = role.trim().toLowerCase();
    await _authBox?.put(keyUserRole, normalized);
    userRoleNotifier.value = '';
    userRoleNotifier.value = normalized;
  }

  // Buyer Delivery Address
  static String get deliveryAddress =>
      _authBox?.get(keyDeliveryAddress, defaultValue: '') as String? ?? '';

  static Future<void> setDeliveryAddress(String address) async {
    await _authBox?.put(keyDeliveryAddress, address.trim());
  }

  static Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
    String? artisanId,
    String? phone,
    String? role,
  }) async {
    await _authBox?.put(keyAccessToken, accessToken);
    await _authBox?.put(keyRefreshToken, refreshToken);
    if (artisanId != null) await _authBox?.put(keyArtisanId, artisanId);
    if (phone != null) await _authBox?.put(keyArtisanPhone, phone);
    if (role != null) await _authBox?.put(keyUserRole, role);
  }

  static Future<void> saveArtisanProfile({
    required String name,
    required String craftType,
    required String location,
    required String state,
  }) async {
    await _authBox?.put(keyArtisanName, name);
    await _authBox?.put(keyCraftType, craftType);
    await _authBox?.put(keyLocation, location);
    await _authBox?.put(keyState, state);
    await _authBox?.put(keyUserRole, 'artisan');
  }

  static Future<void> saveBuyerProfile({
    required String name,
    required String address,
    required String state,
  }) async {
    await _authBox?.put(keyArtisanName, name);
    await _authBox?.put(keyDeliveryAddress, address);
    await _authBox?.put(keyState, state);
    await _authBox?.put(keyUserRole, 'buyer');
  }

  static Future<void> clearAuth() async {
    await _authBox?.clear();
  }

  // --- Settings & Localization ---
  static bool get isLanguageChosen =>
      _settingsBox?.get(keyLanguageChosen, defaultValue: false) as bool? ?? false;

  static Future<void> setLanguageChosen(bool chosen) async {
    await _settingsBox?.put(keyLanguageChosen, chosen);
  }

  static String get savedLocaleCode =>
      _settingsBox?.get(keyLocale, defaultValue: 'en') as String? ?? 'en';

  static Future<void> saveLocale(Locale locale) async {
    await _settingsBox?.put(keyLocale, locale.languageCode);
  }

  static bool get isOnboardingCompleted =>
      _settingsBox?.get(keyOnboardingCompleted, defaultValue: false) as bool? ?? false;

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _settingsBox?.put(keyOnboardingCompleted, completed);
  }

  // --- Developer Settings ---
  static const String keyServerBaseUrl = 'server_base_url';

  static String get serverBaseUrl =>
      _settingsBox?.get(keyServerBaseUrl, defaultValue: '') as String? ?? '';

  static Future<void> setServerBaseUrl(String url) async {
    String clean = url.trim();
    if (clean.isEmpty) {
      await clearServerBaseUrl();
      return;
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.endsWith('/api/v1') && !clean.contains('/api/')) {
      clean = '$clean/api/v1';
    }
    await _settingsBox?.put(keyServerBaseUrl, clean);
  }

  static Future<void> clearServerBaseUrl() async {
    await _settingsBox?.delete(keyServerBaseUrl);
  }

  static const String keyDeveloperMode = 'developer_mode';
  static final ValueNotifier<bool> developerModeNotifier =
      ValueNotifier<bool>(isDeveloperMode);

  static bool get isDeveloperMode =>
      _settingsBox?.get(keyDeveloperMode, defaultValue: true) as bool? ?? true;

  static Future<void> setDeveloperMode(bool enabled) async {
    await _settingsBox?.put(keyDeveloperMode, enabled);
    developerModeNotifier.value = enabled;
  }

  static const String keyLastError = 'last_developer_error';

  static String? get lastErrorJson =>
      _settingsBox?.get(keyLastError) as String?;

  static Future<void> setLastErrorJson(String? json) async {
    if (json == null || json.isEmpty) {
      await clearLastError();
    } else {
      await _settingsBox?.put(keyLastError, json);
    }
  }

  static Future<void> clearLastError() async {
    await _settingsBox?.delete(keyLastError);
  }

  // --- KalaMitra Floating Button Position & Visibility ---
  static const String keyKalaMitraYRatio = 'kalamitra_y_ratio';
  static const String keyKalaMitraIsRight = 'kalamitra_is_right';
  static const String keyKalaMitraIsHidden = 'kalamitra_is_hidden';

  static double? _cachedKalaMitraYRatio;
  static bool? _cachedKalaMitraIsRight;
  static bool? _cachedKalaMitraIsHidden;

  static double? get kalaMitraYRatio =>
      _cachedKalaMitraYRatio ?? (_settingsBox?.get(keyKalaMitraYRatio) as double?);

  static bool get kalaMitraIsRight =>
      _cachedKalaMitraIsRight ??
      (_settingsBox?.get(keyKalaMitraIsRight, defaultValue: true) as bool? ?? true);

  static bool get isKalaMitraHidden =>
      _cachedKalaMitraIsHidden ??
      (_settingsBox?.get(keyKalaMitraIsHidden, defaultValue: false) as bool? ?? false);

  static Future<void> saveKalaMitraPosition({
    required double yRatio,
    required bool isRight,
  }) async {
    _cachedKalaMitraYRatio = yRatio;
    _cachedKalaMitraIsRight = isRight;
    await _settingsBox?.put(keyKalaMitraYRatio, yRatio);
    await _settingsBox?.put(keyKalaMitraIsRight, isRight);
  }

  static Future<void> setKalaMitraHidden(bool hidden) async {
    _cachedKalaMitraIsHidden = hidden;
    await _settingsBox?.put(keyKalaMitraIsHidden, hidden);
  }

  static final ValueNotifier<int> kalaMitraResetNotifier = ValueNotifier<int>(0);

  static Future<void> resetKalaMitraPosition() async {
    _cachedKalaMitraYRatio = null;
    _cachedKalaMitraIsRight = null;
    _cachedKalaMitraIsHidden = null;
    await _settingsBox?.delete(keyKalaMitraYRatio);
    await _settingsBox?.delete(keyKalaMitraIsRight);
    await _settingsBox?.delete(keyKalaMitraIsHidden);
    kalaMitraResetNotifier.value++;
  }

  // --- Simple Mode & Accessibility Settings ---
  static const String keySimpleMode = 'simple_mode';
  static const String keyAutoSpeakEnabled = 'auto_speak_enabled';
  static const String keyLargeTextEnabled = 'large_text_enabled';
  static const String keyFairModeActive = 'fair_mode_active';
  static const String keyAssistedBy = 'assisted_by';
  static const String keyHelperCode = 'helper_code';

  static final ValueNotifier<bool> simpleModeNotifier =
      ValueNotifier<bool>(isSimpleMode);
  static final ValueNotifier<bool> autoSpeakNotifier =
      ValueNotifier<bool>(isAutoSpeakEnabled);
  static final ValueNotifier<bool> largeTextNotifier =
      ValueNotifier<bool>(isLargeTextEnabled);
  static final ValueNotifier<bool> fairModeNotifier =
      ValueNotifier<bool>(isFairModeActive);
  static final ValueNotifier<String> assistedNotifier =
      ValueNotifier<String>(assistedBy);

  static bool get isSimpleMode =>
      _settingsBox?.get(keySimpleMode, defaultValue: true) as bool? ?? true;

  static Future<void> setSimpleMode(bool enabled) async {
    await _settingsBox?.put(keySimpleMode, enabled);
    simpleModeNotifier.value = enabled;
  }

  static bool get isAutoSpeakEnabled =>
      _settingsBox?.get(keyAutoSpeakEnabled, defaultValue: true) as bool? ?? true;

  static Future<void> setAutoSpeakEnabled(bool enabled) async {
    await _settingsBox?.put(keyAutoSpeakEnabled, enabled);
    autoSpeakNotifier.value = enabled;
  }

  static bool get isLargeTextEnabled =>
      _settingsBox?.get(keyLargeTextEnabled, defaultValue: false) as bool? ?? false;

  static Future<void> setLargeTextEnabled(bool enabled) async {
    await _settingsBox?.put(keyLargeTextEnabled, enabled);
    largeTextNotifier.value = enabled;
  }

  static bool get isFairModeActive =>
      _settingsBox?.get(keyFairModeActive, defaultValue: false) as bool? ?? false;

  static Future<void> setFairModeActive(bool active) async {
    await _settingsBox?.put(keyFairModeActive, active);
    fairModeNotifier.value = active;
  }

  static String get assistedBy =>
      _settingsBox?.get(keyAssistedBy, defaultValue: '') as String? ?? '';

  static String get helperCode =>
      _settingsBox?.get(keyHelperCode, defaultValue: '') as String? ?? '';

  static bool get isAssisted => assistedBy.isNotEmpty;

  static Future<void> setAssistedHelper({
    required String helperName,
    required String code,
  }) async {
    await _settingsBox?.put(keyAssistedBy, helperName.trim());
    await _settingsBox?.put(keyHelperCode, code.trim());
    assistedNotifier.value = helperName.trim();
  }

  static Future<void> clearAssistedHelper() async {
    await _settingsBox?.delete(keyAssistedBy);
    await _settingsBox?.delete(keyHelperCode);
    assistedNotifier.value = '';
  }

  static const String keyAcceptedPrices = 'accepted_prices_list';

  static List<int> getAcceptedPrices() {
    final raw = _settingsBox?.get(keyAcceptedPrices);
    if (raw is List) {
      return raw.map((e) => (e as num).toInt()).toList();
    }
    return [];
  }

  static Future<void> saveAcceptedPrice(int price) async {
    final list = getAcceptedPrices();
    list.add(price);
    await _settingsBox?.put(keyAcceptedPrices, list);
  }

  // --- Add Product Draft Persistence ---
  static const String keyProductDraft = 'add_product_draft';

  static Map<String, dynamic>? getProductDraft() {
    final raw = _settingsBox?.get(keyProductDraft);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveProductDraft(Map<String, dynamic> draft) async {
    await _settingsBox?.put(keyProductDraft, draft);
  }

  static Future<void> clearProductDraft() async {
    await _settingsBox?.delete(keyProductDraft);
  }
}

