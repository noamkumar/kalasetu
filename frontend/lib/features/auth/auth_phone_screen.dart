import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/big_numeric_keypad.dart';
import '../../core/widgets/language_picker.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../core/utils/network_error_helper.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../profile/developer_settings_dialog.dart';
import 'widgets/assisted_mode_dialog.dart';

class AuthPhoneScreen extends StatefulWidget {
  const AuthPhoneScreen({super.key});

  @override
  State<AuthPhoneScreen> createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends State<AuthPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  bool _isTestingConnection = false;
  int _logoTapCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'enter_phone_instruction'.tr(),
      );
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _appendDigit(String digit) {
    if (_phoneController.text.length < 10) {
      setState(() {
        _phoneController.text += digit;
        _errorMessage = null;
      });
    }
  }

  void _backspaceDigit() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text = _phoneController.text
            .substring(0, _phoneController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _clearDigits() {
    setState(() {
      _phoneController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMessage = 'phone_invalid'.tr());
      SimpleModeVoiceHelper.showFriendlyErrorDialog(
        context,
        title: 'check_phone_title'.tr(),
        message: 'phone_invalid'.tr(),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final debugOtp = await _authRepo.sendOtp(phone);
      if (!mounted) return;
      SimpleModeVoiceHelper.playSuccessFeedback(context, 'otp_sent_spoken'.tr());
      context.go('${RouteNames.authOtp}?phone=$phone&debug_otp=${debugOtp ?? ""}');
    } catch (e) {
      if (!mounted) return;
      final resolved = NetworkErrorHelper.resolve(e);
      setState(() => _errorMessage = resolved.message);
      SimpleModeVoiceHelper.showFriendlyErrorDialog(
        context,
        title: resolved.title,
        message: resolved.message,
        onRetry: _handleSendOtp,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTestConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final info = await _apiClient.testConnection();
      if (!mounted) return;
      final appName = info['app'] ?? 'KalaSetu';
      final version = info['version'] ?? '1.0.0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'connection_healthy_msg'.tr()} ($appName v$version)'),
          backgroundColor: AppColors.statusOnline,
        ),
      );
      setState(() {
        _isTestingConnection = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTestingConnection = false);
      final resolved = NetworkErrorHelper.resolve(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolved.message),
          backgroundColor: AppColors.statusError,
          action: SnackBarAction(
            label: 'open_dev_settings'.tr(),
            textColor: Colors.white,
            onPressed: () => DeveloperSettingsDialog.show(context),
          ),
        ),
      );
    }
  }

  void _onLogoTapped() async {
    _logoTapCount++;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      final newMode = !StorageService.isDeveloperMode;
      await StorageService.setDeveloperMode(newMode);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newMode ? 'Developer Mode Enabled' : 'Developer Mode Disabled'),
          backgroundColor: newMode ? AppColors.craftOchre : AppColors.inkPrimary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _changeLanguage(String code) async {
    final newLocale = Locale(code);
    await context.setLocale(newLocale);
    await StorageService.saveLocale(newLocale);
    VoiceService.instance.prefetchFixedPhrases(code);
    if (mounted) {
      setState(() {});
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'enter_phone_instruction'.tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLangCode = context.locale.languageCode;
    final currentLang = kSupportedLanguages.firstWhere(
      (l) => l.code == currentLangCode,
      orElse: () => kSupportedLanguages.first,
    );

    final hasError = _errorMessage != null;
    final isSimple = StorageService.isSimpleMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Language Dropdown + Speaker Affordance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: SpeakerAffordance(
                      textToSpeak: 'enter_phone_instruction'.tr(),
                      languageCode: currentLangCode,
                      label: 'listen_instruction'.tr(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 48.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.pillRadius,
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentLang.code,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.inkPrimary, size: 20),
                        items: kSupportedLanguages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang.code,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  lang.nativeName,
                                  style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newCode) {
                          if (newCode != null && newCode != currentLangCode) {
                            _changeLanguage(newCode);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Logo Card with secret 5-tap developer mode toggle
              GestureDetector(
                onTap: _onLogoTapped,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/app_logo_transparent.png',
                      height: 50,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KalaSetu',
                      style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'sign_in_subtitle'.tr(),
                      style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (StorageService.isAssisted) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: AppRadii.pillRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volunteer_activism, size: 16, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text(
                              '${'assisted_by'.tr()}: ${StorageService.assistedBy}',
                              style: AppTextStyles.labelSmall(color: AppColors.secondary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
              const SizedBox(height: 16),

              // Phone Field Header
              Text(
                'phone_label'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 56.0),
                decoration: BoxDecoration(
                  color: hasError
                      ? AppColors.statusError.withValues(alpha: 0.04)
                      : AppColors.surface,
                  borderRadius: AppRadii.inputRadius,
                  border: Border.all(
                    color: hasError ? AppColors.statusError : AppColors.hairline,
                    width: hasError ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: hasError ? AppColors.statusError : AppColors.hairline,
                          ),
                        ),
                      ),
                      child: Text(
                        '🇮🇳 +91',
                        style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        readOnly: isSimple,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: _onPhoneChanged,
                        style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(
                          fontSize: 24,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'phone_hint'.tr(),
                          hintStyle: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (hasError) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.statusError),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyMedium(color: AppColors.statusError),
                      ),
                    ),
                  ],
                ),
                if (StorageService.isDeveloperMode) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('test_connection_btn'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(color: AppColors.craftOchre),
                            shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                            backgroundColor: AppColors.surface,
                          ),
                          onPressed: _isTestingConnection ? null : _handleTestConnection,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.craftOchre,
                                  ),
                                )
                              : const Icon(Icons.wifi_find_rounded, size: 18, color: AppColors.craftOchre),
                          label: Text(
                            'test_connection_btn'.tr(),
                            style: AppTextStyles.labelMedium(color: AppColors.craftOchre).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'open_dev_settings'.tr(),
                        icon: const Icon(Icons.tune_rounded, color: AppColors.craftOchre),
                        onPressed: () => DeveloperSettingsDialog.show(context),
                      ),
                    ],
                  ),
                ],
              ],

              // Big Numeric Keypad in Simple Mode
              if (isSimple) ...[
                const SizedBox(height: 14),
                BigNumericKeypad(
                  onDigitPressed: _appendDigit,
                  onBackspacePressed: _backspaceDigit,
                  onClearPressed: _clearDigits,
                ),
              ],

              const SizedBox(height: 18),

              // 56-64 dp Big Continue Button
              AppButton(
                label: 'continue_btn'.tr(),
                variant: AppButtonVariant.primary,
                isLoading: _isLoading,
                minHeight: 58.0,
                isFullWidth: true,
                onPressed: _handleSendOtp,
              ),
              const SizedBox(height: 14),

              // Assisted Mode Button (NGO / Cluster Helper)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.8)),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                  backgroundColor: AppColors.surface,
                ),
                onPressed: () {
                  AssistedModeDialog.show(
                    context,
                    onHelperRegistered: () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.volunteer_activism_outlined, color: AppColors.secondary, size: 22),
                label: Text(
                  StorageService.isAssisted
                      ? '${'assisted_by'.tr()}: ${StorageService.assistedBy}'
                      : 'sign_in_ngo_assist'.tr(),
                  style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
