import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_radii.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KalaSetu Design System - Tokens Unit Tests', () {
    test('AppColors matches Section 5.1 specification values', () {
      expect(AppColors.background, const Color(0xFFFAF6F0));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.hairline, const Color(0x142B2E2A));
      expect(AppColors.inkPrimary, const Color(0xFF2B2E2A));
      expect(AppColors.inkSecondary, const Color(0xFF6A6E67));
      expect(AppColors.primary, const Color(0xFF606C56));
      expect(AppColors.primaryDark, const Color(0xFF454E3E));
      expect(AppColors.primaryLight, const Color(0xFFE8ECE4));
      expect(AppColors.secondary, const Color(0xFFC7A379));
      expect(AppColors.secondaryLight, const Color(0xFFF6EFE6));
      expect(AppColors.accentBlue, const Color(0xFF4A6572));
    });

    test('AppRadii matches Section 5.3 specification values', () {
      expect(AppRadii.button, 999.0);
      expect(AppRadii.card, 28.0);
      expect(AppRadii.inputField, 16.0);
    });

    test('AppSpacing matches 8pt grid specification', () {
      expect(AppSpacing.xs, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxxl, 48.0);
      expect(AppSpacing.minTouchTarget, 48.0);
      expect(AppSpacing.mobileMaxWidth, 480.0);
      expect(AppSpacing.tabletMaxWidth, 900.0);
      expect(AppSpacing.desktopContainerMaxWidth, 1200.0);
    });

    test('AppTheme initializes with travertine background and sage primary', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.surface);
    });
  });
}
