import 'package:flutter/material.dart';

/// KalaSetu Design System - Linen and Olive Palette
/// Section 5.1 of Project Specification
class AppColors {
  AppColors._();

  // Background & Surface
  static const Color background = Color(0xFFFAF6F0); // Travertine off-white
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards & sheets
  
  // Borders & Dividers
  static const Color hairline = Color(0x142B2E2A); // #2B2E2A at 8% opacity (1px border)
  
  // Typography
  static const Color inkPrimary = Color(0xFF2B2E2A); // Espresso charcoal
  static const Color inkSecondary = Color(0xFF6A6E67); // Muted secondary text
  
  // Primary: Sage Greens
  static const Color primary = Color(0xFF606C56); // Sage
  static const Color primaryDark = Color(0xFF454E3E); // Deep sage
  static const Color primaryLight = Color(0xFFE8ECE4); // Pale sage wash
  
  // Secondary: Linen Sand & Ochre
  static const Color secondary = Color(0xFFC7A379); // Linen sand / ochre
  static const Color secondaryLight = Color(0xFFF6EFE6); // Pale linen wash
  
  // Accent Blue: KalaMitra Assistant
  static const Color accentBlue = Color(0xFF4A6572); // Slate blue
  static const Color accentBlueLight = Color(0xFFE5EDF0);
  
  // Status & Craft Identifiers
  static const Color statusOnline = Color(0xFF2E7D32); // Forest green
  static const Color statusSyncing = Color(0xFFE65100); // Deep amber
  static const Color statusOffline = Color(0xFF757575); // Neutral grey
  static const Color statusError = Color(0xFFC62828); // Error red
  
  static const Color craftTerracotta = Color(0xFFC85A32); // Warm terracotta
  static const Color craftOchre = Color(0xFFD9822B); // Vibrant ochre
  static const Color craftIndigo = Color(0xFF2A4D69); // Traditional indigo
  static const Color craftWood = Color(0xFF8B5A2B); // Natural wood
  static const Color craftBamboo = Color(0xFF556B2F); // Earthy bamboo olive
}
