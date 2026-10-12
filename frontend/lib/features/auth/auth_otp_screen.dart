import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/big_numeric_keypad.dart';
import '../../core/utils/network_error_helper.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/repositories/auth_repository.dart';

class AuthOtpScreen extends StatefulWidget {
  final String phone;
  final String? debugOtp;

  const AuthOtpScreen({
    super.key,
    required this.phone,
    this.debugOtp,
  });

  @override
  State<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends State<AuthOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository();
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isDemo =>
      (widget.debugOtp != null && widget.debugOtp!.isNotEmpty) ||
      AuthRepository.isDemoPhone(widget.phone);

  String get _displayPhone {
    final raw = widget.phone.trim();
    if (raw.startsWith('+91')) {
      final digits = raw.substring(3);
      return '+91 $digits';
    }
    return '+91 $raw';
  }

  @override
  void initState() {
    super.initState();
    if (widget.debugOtp != null && widget.debugOtp!.isNotEmpty) {
      _otpController.text = widget.debugOtp!;
    } else if (AuthRepository.isDemoPhone(widget.phone)) {
      _otpController.text = '123456';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'enter_otp_instruction'.tr(),
      );
    });
  }

  void _appendDigit(String digit) {
    if (_otpController.text.length < 6) {
      setState(() {
        _otpController.text += digit;
        _errorMessage = null;
      });
      // Auto-submit when 6 digits reached in Simple Mode
      if (_otpController.text.length == 6) {
        _handleVerify();
      }
    }
  }

  void _backspaceDigit() {
    if (_otpController.text.isNotEmpty) {
      setState(() {
        _otpController.text = _otpController.text
            .substring(0, _otpController.text.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _clearDigits() {
    setState(() {
      _otpController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'invalid_otp'.tr());
      SimpleModeVoiceHelper.showFriendlyErrorDialog(
        context,
        title: 'check_otp_title'.tr(),
        message: 'invalid_otp'.tr(),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isNewUser = await _authRepo.verifyOtp(widget.phone, otp);
      if (!mounted) return;
      SimpleModeVoiceHelper.playSuccessFeedback(context, 'sign_in_success_spoken'.tr());
      if (isNewUser) {
        context.go(RouteNames.authProfile);
      } else {
        context.go(RouteNames.home);
      }
    } catch (e) {
      if (!mounted) return;
      final resolved = NetworkErrorHelper.resolve(e);
      setState(() => _errorMessage = resolved.message);
      SimpleModeVoiceHelper.showFriendlyErrorDialog(
        context,
        title: resolved.title,
        message: resolved.message,
        onRetry: _handleVerify,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.maybeLocaleOf(context)?.languageCode ??
        'en';
    final isSimple = StorageService.isSimpleMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
          onPressed: () => context.go(RouteNames.authPhone),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SpeakerAffordance(
              textToSpeak: 'enter_otp_instruction'.tr(),
              languageCode: currentLang,
              label: 'listen_instruction'.tr(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'verify_phone_title'.tr(),
                style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                '${'verify_phone_subtitle'.tr()} $_displayPhone',
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 16),

              // Demo hint banner (shown ONLY for demo accounts or when debug_otp is present)
              if (_isDemo) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: AppRadii.inputRadius,
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'debug_otp_hint'.tr(),
                          style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Large OTP Input Container
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.inputRadius,
                  border: Border.all(
                    color: _errorMessage != null ? AppColors.statusError : AppColors.hairline,
                    width: _errorMessage != null ? 2.0 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _otpController,
                  readOnly: isSimple,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(
                    letterSpacing: 10.0,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall(color: AppColors.statusError),
                  textAlign: TextAlign.center,
                ),
              ],

              // Big Numeric Keypad in Simple Mode
              if (isSimple) ...[
                const SizedBox(height: 12),
                BigNumericKeypad(
                  onDigitPressed: _appendDigit,
                  onBackspacePressed: _backspaceDigit,
                  onClearPressed: _clearDigits,
                ),
              ],

              const SizedBox(height: 18),
              AppButton(
                label: 'verify_btn'.tr(),
                variant: AppButtonVariant.primary,
                isLoading: _isLoading,
                minHeight: 58.0,
                isFullWidth: true,
                onPressed: _handleVerify,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
