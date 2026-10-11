import 'package:flutter/material.dart';

/// KalaSetu Design System - Spacing & Responsive Tokens
/// Section 5.3 & 5.4 of Project Specification
class AppSpacing {
  AppSpacing._();

  // 8pt Grid spacing steps
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
  static const double jumbo = 64.0;

  // Minimum interactive touch target
  static const double minTouchTarget = 48.0;

  // Responsive Breakpoints
  static const double mobileMaxWidth = 480.0;
  static const double tabletMaxWidth = 900.0;
  static const double desktopContainerMaxWidth = 1200.0;
  static const double desktopSidePadding = 48.0;

  /// Returns true if screen width is under 480 px (Mobile)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMaxWidth;

  /// Returns true if screen width is between 480 px and 899 px (Tablet)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  /// Returns true if screen width is 900 px or above (Desktop)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMaxWidth;

  /// Responsive font scale: 0.88x on small screens, 1.0x on tablet, 1.15x on large monitors.
  /// Honours system text scaling capped at 1.3x.
  static double getResponsiveFontScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final systemScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.8, 1.3);
    
    double breakpointScale = 1.0;
    if (width < mobileMaxWidth) {
      breakpointScale = 0.88;
    } else if (width >= tabletMaxWidth) {
      breakpointScale = 1.15;
    }
    return breakpointScale * systemScale;
  }
}
