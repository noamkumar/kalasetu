/// KalaSetu Application Configuration
/// Configuration constants and defaults across the app
class AppConfig {
  AppConfig._();

  /// Estimated percentage payout that traditional middlemen pay to artisans.
  /// Used for calculating the Fair Wage premium vs Middleman comparisons.
  /// Typical middleman payout is ~45% of retail price.
  static const double middlemanRate = 0.45;
}
