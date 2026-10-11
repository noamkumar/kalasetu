library;

import '../../../core/widgets/price_suggestion_card.dart';

/// KalaSetu Dynamic Pricing Result Model
/// Section 9 of Project Specification

class PriceSuggestionResult {
  final int floor;
  final int budget;
  final int recommended;
  final int premium;
  final double confidence;
  final String label;
  final bool hasComparables;
  final Map<String, dynamic> breakdown;
  final List<PriceFactor> factors;
  final List<ComparableItem> comparables;
  final Map<String, String> explanation;
  final String? warning;
  final String? impactMessage;
  final String? evidenceLevel;
  final Map<String, dynamic>? attributes;
  final Map<String, dynamic>? marketTrends;

  const PriceSuggestionResult({
    required this.floor,
    required this.budget,
    required this.recommended,
    required this.premium,
    required this.confidence,
    required this.label,
    required this.hasComparables,
    required this.breakdown,
    required this.factors,
    required this.comparables,
    required this.explanation,
    this.warning,
    this.impactMessage,
    this.evidenceLevel,
    this.attributes,
    this.marketTrends,
  });

  factory PriceSuggestionResult.fromJson(Map<String, dynamic> json) {
    final factorsList = (json['factors'] as List<dynamic>?)
            ?.map((f) => PriceFactor(
                  name: f['name']?.toString() ?? '',
                  value: f['value']?.toString() ?? '',
                ))
            .toList() ??
        [];

    final comparablesList = (json['comparables'] as List<dynamic>?)
            ?.map((c) => ComparableItem(
                  title: c['title']?.toString() ?? '',
                  price: (c['price'] as num?)?.toInt() ?? 0,
                  similarity: (c['similarity'] as num?)?.toDouble() ?? 0.8,
                ))
            .toList() ??
        [];

    final expMap = <String, String>{};
    if (json['explanation'] is Map) {
      (json['explanation'] as Map<String, dynamic>).forEach((k, v) {
        expMap[k] = v.toString();
      });
    }

    return PriceSuggestionResult(
      floor: (json['floor'] as num?)?.toInt() ?? 0,
      budget: (json['budget'] as num?)?.toInt() ?? 0,
      recommended: (json['recommended'] as num?)?.toInt() ?? 0,
      premium: (json['premium'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      label: json['label']?.toString() ?? 'Market benchmarked',
      hasComparables: json['has_comparables'] as bool? ?? true,
      breakdown: (json['breakdown'] as Map<String, dynamic>?) ?? {},
      factors: factorsList,
      comparables: comparablesList,
      explanation: expMap,
      warning: json['warning']?.toString(),
      impactMessage: json['impact_message']?.toString(),
      evidenceLevel: json['evidence_level']?.toString(),
      attributes: (json['attributes'] as Map<String, dynamic>?),
      marketTrends: (json['market_trends'] as Map<String, dynamic>?),
    );
  }

  String getExplanationForLang(String lang) {
    if (explanation.containsKey(lang)) {
      return explanation[lang]!;
    }
    return explanation['en'] ?? '';
  }
}
