import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// KalaSetu Design System - Typography Tokens
/// Section 5.2 of Project Specification: Fraunces (Serif) + Manrope (Sans) + Indic Fallbacks
class AppTextStyles {
  AppTextStyles._();

  static const List<String> indicFontFallbacks = [
    'Noto Sans Devanagari',
    'Noto Sans Tamil',
    'Noto Sans Telugu',
    'Noto Sans Kannada',
    'Noto Sans Malayalam',
    'sans-serif',
  ];

  // Headings & Display: Fraunces (variable serif), letter-spacing -0.02em, height >= 1.2
  static TextStyle displayLarge({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 34.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 34.0,
        height: 1.25,
        color: color,
      );

  static TextStyle displayMedium({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 28.0,
        height: 1.25,
        color: color,
      );

  static TextStyle displaySmall({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 24.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * 24.0,
        height: 1.25,
        color: color,
      );

  static TextStyle headlineMedium({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * 20.0,
        height: 1.25,
        color: color,
      );

  // Titles: Manrope
  static TextStyle titleLarge({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 18.0,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: color,
      );

  static TextStyle titleMedium({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle titleSmall({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  // Body: Manrope (weights 300, 400, 500)
  static TextStyle bodyLarge({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static TextStyle bodyMedium({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static TextStyle bodySmall({Color color = AppColors.inkSecondary}) =>
      GoogleFonts.manrope(
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  // Labels, Buttons & Badges: Manrope 500 / 700
  static TextStyle labelLarge({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: color,
      );

  static TextStyle labelMedium({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.manrope(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.25,
        color: color,
      );

  static TextStyle labelSmall({Color color = AppColors.inkSecondary}) =>
      GoogleFonts.manrope(
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.25,
        color: color,
      );

  // Price Display
  static TextStyle priceDisplay({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 26.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: color,
      );

  // Serif Card Title for 2-line product card titles
  static TextStyle serifCardTitle({Color color = AppColors.inkPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.25,
        color: color,
      );
}
