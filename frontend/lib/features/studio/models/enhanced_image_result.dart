library;

/// KalaSetu AI Image Studio - Enhanced Image Result Model
/// Section 7 of Project Specification

class EnhancedImageResult {
  final String originalUrl;
  final String heroUrl;
  final String socialUrl;
  final String thumbnailUrl;
  final String canvasStyle;
  final int qualityScore;
  final Map<String, dynamic> metrics;
  final List<String> tips;
  final Map<String, dynamic> visualTags;
  final String status;
  final bool aiPolishApplied;

  const EnhancedImageResult({
    required this.originalUrl,
    required this.heroUrl,
    required this.socialUrl,
    required this.thumbnailUrl,
    required this.canvasStyle,
    required this.qualityScore,
    required this.metrics,
    required this.tips,
    required this.visualTags,
    required this.status,
    required this.aiPolishApplied,
  });

  bool get isFallback => status == 'partial_fallback';

  factory EnhancedImageResult.fromJson(Map<String, dynamic> json) {
    return EnhancedImageResult(
      originalUrl: json['original_url']?.toString() ?? '',
      heroUrl: json['hero_url']?.toString() ?? '',
      socialUrl: json['social_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      canvasStyle: json['canvas_style']?.toString() ?? 'white',
      qualityScore: (json['quality_score'] as num?)?.toInt() ?? 75,
      metrics: (json['metrics'] as Map<String, dynamic>?) ?? {},
      tips: (json['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      visualTags: (json['visual_tags'] as Map<String, dynamic>?) ?? {},
      status: json['status']?.toString() ?? 'enhanced',
      aiPolishApplied: json['ai_polish_applied'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'original_url': originalUrl,
    'hero_url': heroUrl,
    'social_url': socialUrl,
    'thumbnail_url': thumbnailUrl,
    'canvas_style': canvasStyle,
    'quality_score': qualityScore,
    'metrics': metrics,
    'tips': tips,
    'visual_tags': visualTags,
    'status': status,
    'ai_polish_applied': aiPolishApplied,
  };
}
