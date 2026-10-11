import 'package:flutter/material.dart';
import 'app_colors.dart';

/// KalaSetu Design System - Elevation & Shadows
/// Section 5.3 of Project Specification
class AppElevation {
  AppElevation._();

  /// Soft Luxury Ambient Card Shadow: rgba(43,46,42,0.03) with blur 40
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(43, 46, 42, 0.03),
      blurRadius: 40.0,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  /// Floating Action / Sheet Shadow
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color.fromRGBO(43, 46, 42, 0.06),
      blurRadius: 24.0,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color.fromRGBO(43, 46, 42, 0.03),
      blurRadius: 8.0,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// Subtle Border Decoration for Linen Cards
  static BoxDecoration cardDecoration({
    Color backgroundColor = AppColors.surface,
    BorderRadiusGeometry? borderRadius,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius ?? BorderRadius.circular(28),
      border: showBorder ? Border.all(color: AppColors.hairline, width: 1.0) : null,
      boxShadow: cardShadow,
    );
  }
}
