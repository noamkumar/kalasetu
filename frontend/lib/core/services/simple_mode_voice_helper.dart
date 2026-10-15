import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'storage_service.dart';
import 'voice_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Helper utility for Simple Mode voice-first affordances,
/// automatic instruction speaking, spoken success confirmations,
/// and friendly jargon-free error handling.
class SimpleModeVoiceHelper {
  SimpleModeVoiceHelper._();

  static String _resolveLang(BuildContext context) {
    try {
      return context.locale.languageCode;
    } catch (_) {
      return Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    }
  }

  static bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Speaks the screen instruction automatically if auto-speak is enabled
  static Future<void> autoSpeakScreenInstruction(
    BuildContext context,
    String instructionText,
  ) async {
    if (_isTest) return;
    if (!StorageService.isAutoSpeakEnabled) return;
    final lang = _resolveLang(context);
    // Small delay to allow transition animation to settle smoothly
    await Future.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    VoiceService.instance.speak(
      text: instructionText,
      languageCode: lang,
    );
  }

  /// Plays haptic feedback and speaks a cheerful confirmation message
  static Future<void> playSuccessFeedback(
    BuildContext context,
    String confirmationText,
  ) async {
    if (_isTest) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    if (!context.mounted) return;
    final lang = _resolveLang(context);
    VoiceService.instance.speak(
      text: confirmationText,
      languageCode: lang,
    );
  }

  /// Shows a friendly, jargon-free error dialog with a craft illustration,
  /// spoken voice explanation, and a single "Try Again" button.
  static Future<void> showFriendlyErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) async {
    final lang = _resolveLang(context);
    VoiceService.instance.speak(text: message, languageCode: lang);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 2),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 44,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodyLarge(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                  elevation: 2,
                ),
                onPressed: () {
                  VoiceService.instance.stop();
                  Navigator.of(ctx).pop();
                  onRetry?.call();
                },
                icon: const Icon(Icons.refresh_rounded, size: 26),
                label: Text(
                  'try_again'.tr(),
                  style: AppTextStyles.titleMedium(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
