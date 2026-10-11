import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Accessible Big Numeric Keypad
/// Principles: 56-64 dp touch targets, large text, high contrast, tactile haptic feedback.
/// Used across Phone login, OTP, and Price input to eliminate tedious keyboard typing.
class BigNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;
  final VoidCallback? onVoicePressed;

  const BigNumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    required this.onClearPressed,
    this.onVoicePressed,
  });

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
    String? semanticsLabel,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Semantics(
          button: true,
          label: semanticsLabel,
          child: Material(
            color: backgroundColor ?? AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitKey(String digit) {
    return _buildKey(
      semanticsLabel: 'Number $digit',
      onTap: () => onDigitPressed(digit),
      child: Text(
        digit,
        style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildDigitKey('1'),
            _buildDigitKey('2'),
            _buildDigitKey('3'),
          ],
        ),
        Row(
          children: [
            _buildDigitKey('4'),
            _buildDigitKey('5'),
            _buildDigitKey('6'),
          ],
        ),
        Row(
          children: [
            _buildDigitKey('7'),
            _buildDigitKey('8'),
            _buildDigitKey('9'),
          ],
        ),
        Row(
          children: [
            // Voice or Clear
            if (onVoicePressed != null)
              _buildKey(
                semanticsLabel: 'Speak numbers',
                backgroundColor: AppColors.primaryLight,
                onTap: onVoicePressed!,
                child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 28),
              )
            else
              _buildKey(
                semanticsLabel: 'Clear input',
                backgroundColor: AppColors.background,
                onTap: onClearPressed,
                child: const Icon(Icons.clear_all_rounded, color: AppColors.inkSecondary, size: 26),
              ),
            _buildDigitKey('0'),
            _buildKey(
              semanticsLabel: 'Backspace',
              backgroundColor: AppColors.background,
              onTap: onBackspacePressed,
              child: const Icon(Icons.backspace_outlined, color: AppColors.inkPrimary, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}
