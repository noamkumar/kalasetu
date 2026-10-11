import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outlined,
  text,
}

/// KalaSetu Capsule Action Button
/// Variants: Primary (Sage), Secondary (Linen Sand), Outlined, Text
/// Section 5.5 of Project Specification
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final bool isFullWidth;
  final double minHeight;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.minHeight = 48.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = minHeight < 48.0 ? 48.0 : minHeight;
    final effectivePadding = padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget content;
    if (isLoading) {
      Color progressColor;
      switch (variant) {
        case AppButtonVariant.primary:
          progressColor = AppColors.surface;
          break;
        case AppButtonVariant.secondary:
          progressColor = AppColors.inkPrimary;
          break;
        case AppButtonVariant.outlined:
        case AppButtonVariant.text:
          progressColor = AppColors.primary;
          break;
      }
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        ),
      );
    } else {
      final textStyle = _getTextStyle();
      if (icon != null) {
        content = Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon!,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      } else {
        content = Text(
          label,
          style: textStyle,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            minimumSize: Size(isFullWidth ? double.infinity : 0, effectiveHeight),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            elevation: 0,
            padding: effectivePadding,
          ),
          child: content,
        );
        break;

      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.inkPrimary,
            disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.5),
            minimumSize: Size(isFullWidth ? double.infinity : 0, effectiveHeight),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            elevation: 0,
            padding: effectivePadding,
          ),
          child: content,
        );
        break;

      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.primary.withValues(alpha: 0.4),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: Size(isFullWidth ? double.infinity : 0, effectiveHeight),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            padding: effectivePadding,
          ),
          child: content,
        );
        break;

      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: Size(isFullWidth ? double.infinity : 0, effectiveHeight),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
            padding: effectivePadding,
          ),
          child: content,
        );
        break;
    }

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      child: button,
    );
  }

  TextStyle _getTextStyle() {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppTextStyles.labelLarge(color: AppColors.surface);
      case AppButtonVariant.secondary:
        return AppTextStyles.labelLarge(color: AppColors.inkPrimary);
      case AppButtonVariant.outlined:
        return AppTextStyles.labelLarge(color: AppColors.primary);
      case AppButtonVariant.text:
        return AppTextStyles.labelLarge(color: AppColors.primary);
    }
  }
}
