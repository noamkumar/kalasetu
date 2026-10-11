import 'dart:async';
import '../api/api_client.dart';

class TranscribeResult {
  final String text;
  final String detectedLang;
  final String clarity; // 'high' | 'medium' | 'low'

  const TranscribeResult({
    required this.text,
    required this.detectedLang,
    required this.clarity,
  });

  factory TranscribeResult.fromJson(Map<String, dynamic> json) {
    return TranscribeResult(
      text: json['text']?.toString() ?? '',
      detectedLang: json['detected_lang']?.toString() ?? 'en',
      clarity: json['clarity']?.toString() ?? 'high',
    );
  }
}

class ListingItemData {
  String title;
  String shortDescription;
  String longDescription;
  List<String> bulletPoints;
  List<String> materials;
  String careInstructions;
  String seoTitle;
  String metaDescription;
  List<String> keywords;
  List<String> hashtags;

  ListingItemData({
    required this.title,
    required this.shortDescription,
    required this.longDescription,
    this.bulletPoints = const [],
    this.materials = const [],
    this.careInstructions = '',
    required this.seoTitle,
    required this.metaDescription,
    this.keywords = const [],
    this.hashtags = const [],
  });

  factory ListingItemData.fromJson(Map<String, dynamic> json) {
    return ListingItemData(
      title: json['title']?.toString() ?? '',
      shortDescription: json['short_description']?.toString() ?? '',
      longDescription: json['long_description']?.toString() ?? '',
      bulletPoints: (json['bullet_points'] as List?)?.map((e) => e.toString()).toList() ?? [],
      materials: (json['materials'] as List?)?.map((e) => e.toString()).toList() ?? [],
      careInstructions: json['care_instructions']?.toString() ?? '',
      seoTitle: json['seo_title']?.toString() ?? '',
      metaDescription: json['meta_description']?.toString() ?? '',
      keywords: (json['keywords'] as List?)?.map((e) => e.toString()).toList() ?? [],
      hashtags: (json['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'short_description': shortDescription,
      'long_description': longDescription,
      'bullet_points': bulletPoints,
      'materials': materials,
      'care_instructions': careInstructions,
      'seo_title': seoTitle.length > 60 ? seoTitle.substring(0, 60) : seoTitle,
      'meta_description': metaDescription.length > 155 ? metaDescription.substring(0, 155) : metaDescription,
      'keywords': keywords,
      'hashtags': hashtags,
    };
  }
}

class CatalogListingResult {
  final String sourceLang;
  final ListingItemData master;
  final ListingItemData original;
  final String originalTranscript;
  final Map<String, ListingItemData> translations;

  const CatalogListingResult({
    required this.sourceLang,
    required this.master,
    required this.original,
    this.originalTranscript = '',
    required this.translations,
  });

  factory CatalogListingResult.fromJson(Map<String, dynamic> json) {
    final transMap = <String, ListingItemData>{};
    if (json['translations'] is Map) {
      final tRaw = json['translations'] as Map<String, dynamic>;
      tRaw.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          transMap[key] = ListingItemData.fromJson(val);
        }
      });
    }

    final masterItem = ListingItemData.fromJson(
      (json['master'] as Map<String, dynamic>?) ?? {},
    );
    final origItem = ListingItemData.fromJson(
      (json['original'] as Map<String, dynamic>?) ?? json['master'] ?? {},
    );

    return CatalogListingResult(
      sourceLang: json['source_lang']?.toString() ?? 'en',
      master: masterItem,
      original: origItem,
      originalTranscript: json['original_transcript']?.toString() ?? '',
      translations: transMap,
    );
  }
}

class CatalogRepository {
  final ApiClient _apiClient;

  CatalogRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Upload audio to POST /catalog/transcribe
  Future<TranscribeResult> transcribeAudio({
    required String filePath,
    String? languageHint,
  }) async {
    final fields = <String, String>{};
    if (languageHint != null && languageHint.isNotEmpty) {
      fields['language_hint'] = languageHint;
    }

    final res = await _apiClient.postMultipart(
      '/catalog/transcribe',
      fields: fields,
      fileField: 'audio',
      filePath: filePath,
    );

    if (res is Map<String, dynamic>) {
      return TranscribeResult.fromJson(res);
    }
    throw const ApiException(message: 'Invalid transcription response from server');
  }

  /// Generate 6-language listing from transcript
  Future<CatalogListingResult> generateCatalog({
    required String transcript,
    required String sourceLang,
    String? category,
    double? price,
    Map<String, dynamic>? imageTags,
  }) async {
    final body = {
      'transcript': transcript,
      'source_lang': sourceLang,
      'category': category ?? 'Pottery',
      'price': price,
      'image_tags': imageTags,
    };

    final res = await _apiClient.post('/catalog/generate', body: body);

    if (res is Map<String, dynamic>) {
      return CatalogListingResult.fromJson(res);
    }
    throw const ApiException(message: 'Invalid catalog generation response from server');
  }

  /// Refine existing listing using voice/text instructions with Gemini
  Future<CatalogListingResult> refineCatalog({
    required Map<String, dynamic> currentListing,
    required String feedback,
    required String sourceLang,
    String? category,
  }) async {
    final body = {
      'current_listing': currentListing,
      'feedback': feedback,
      'source_lang': sourceLang,
      'category': category ?? 'Pottery',
    };

    final res = await _apiClient.post('/catalog/refine', body: body);

    if (res is Map<String, dynamic>) {
      return CatalogListingResult.fromJson(res);
    }
    throw const ApiException(message: 'Invalid catalog refinement response from server');
  }
}
