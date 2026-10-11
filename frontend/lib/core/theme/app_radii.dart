import 'package:flutter/material.dart';

/// KalaSetu Design System - Border Radii Tokens
/// Section 5.3 of Project Specification
class AppRadii {
  AppRadii._();

  static const double button = 999.0; // Capsule
  static const double card = 28.0;
  static const double inputField = 16.0;
  static const double chip = 999.0;
  static const double pill = 999.0;
  static const double badge = 12.0;
  static const double dialog = 24.0;
  static const double sheet = 28.0;

  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(inputField));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(sheet));
}
