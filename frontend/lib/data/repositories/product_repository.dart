import '../api/api_client.dart';
import '../local_db/app_database.dart';

class DisplayProduct {
  final String id;
  final String artisanId;
  final String category;
  final double price;
  final double? costPrice;
  final String status;
  final int stockQuantity;
  final String? primaryImageUrl;
  final String? enhancedImageUrl;
  final String title;
  final String? description;
  final String? materials;
  final String? careInstructions;
  final DateTime createdAt;

  const DisplayProduct({
    required this.id,
    required this.artisanId,
    required this.category,
    required this.price,
    this.costPrice,
    required this.status,
    required this.stockQuantity,
    this.primaryImageUrl,
    this.enhancedImageUrl,
    required this.title,
    this.description,
    this.materials,
    this.careInstructions,
    required this.createdAt,
  });
}

class ProductRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;

  ProductRepository({
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase();

  /// Watch local products mapped to current language
  Stream<List<DisplayProduct>> watchProducts(String languageCode) {
    return _db.watchAllProducts().asyncMap((products) async {
      final list = <DisplayProduct>[];
      for (final p in products) {
        final transList = await _db.getTranslationsForProduct(p.id);
        LocalProductTranslation? target;
        LocalProductTranslation? fallbackEn;

        for (final t in transList) {
          if (t.languageCode == languageCode) {
            target = t;
            break;
          }
          if (t.languageCode == 'en') {
            fallbackEn = t;
          }
        }
        final chosen = target ?? fallbackEn ?? (transList.isNotEmpty ? transList.first : null);

        list.add(DisplayProduct(
          id: p.id,
          artisanId: p.artisanId,
          category: p.category,
          price: p.price,
          costPrice: p.costPrice,
          status: p.status,
          stockQuantity: p.stockQuantity,
          primaryImageUrl: p.primaryImageUrl,
          enhancedImageUrl: p.enhancedImageUrl,
          title: chosen?.title ?? 'Product #${p.id.substring(0, 6.clamp(0, p.id.length))}',
          description: chosen?.description,
          materials: chosen?.materials,
          careInstructions: chosen?.careInstructions,
          createdAt: p.createdAt,
        ));
      }
      return list;
    });
  }

  /// Get single localized product by id
  Future<DisplayProduct?> getProductById(String id, String languageCode) async {
    final local = await _db.getProductById(id);
    if (local == null) {
      try {
        await refreshProducts(languageCode);
      } catch (_) {}
    }
    final p = await _db.getProductById(id);
    if (p == null) return null;

    final transList = await _db.getTranslationsForProduct(p.id);
    LocalProductTranslation? target;
    LocalProductTranslation? fallbackEn;

    for (final t in transList) {
      if (t.languageCode == languageCode) {
        target = t;
        break;
      }
      if (t.languageCode == 'en') fallbackEn = t;
    }
    final chosen = target ?? fallbackEn ?? (transList.isNotEmpty ? transList.first : null);

    return DisplayProduct(
      id: p.id,
      artisanId: p.artisanId,
      category: p.category,
      price: p.price,
      costPrice: p.costPrice,
      status: p.status,
      stockQuantity: p.stockQuantity,
      primaryImageUrl: p.primaryImageUrl,
      enhancedImageUrl: p.enhancedImageUrl,
      title: chosen?.title ?? 'Product #${p.id.substring(0, 6.clamp(0, p.id.length))}',
      description: chosen?.description,
      materials: chosen?.materials,
      careInstructions: chosen?.careInstructions,
      createdAt: p.createdAt,
    );
  }

  /// Refresh products and store in Drift DB
  Future<void> refreshProducts(String languageCode) async {
    try {
      final result = await _apiClient.get('/api/v1/products', queryParams: {'lang': languageCode});
      if (result is List) {
        for (final item in result) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String;
            final now = DateTime.now();
            final createdAt = item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ?? now
                : now;
            final updatedAt = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString()) ?? now
                : now;

            await _db.upsertProduct(
              LocalProduct(
                id: id,
                artisanId: item['artisan_id']?.toString() ?? '',
                category: item['category']?.toString() ?? 'Pottery',
                price: (item['price'] as num?)?.toDouble() ?? 0.0,
                costPrice: (item['cost_price'] as num?)?.toDouble(),
                status: item['status']?.toString() ?? 'active',
                stockQuantity: (item['stock_quantity'] as num?)?.toInt() ?? 1,
                primaryImageUrl: item['primary_image_url']?.toString(),
                enhancedImageUrl: item['enhanced_image_url']?.toString(),
                originalAudioUrl: item['original_audio_url']?.toString(),
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
            );

            // Store current translation
            final title = item['title']?.toString() ?? '';
            final desc = item['description']?.toString();
            final mats = item['materials']?.toString();
            final care = item['care_instructions']?.toString();

            await _db.upsertTranslation(
              LocalProductTranslation(
                id: '${id}_$languageCode',
                productId: id,
                languageCode: languageCode,
                title: title,
                description: desc,
                materials: mats,
                careInstructions: care,
              ),
            );

            // If extra translations exist in payload, upsert them too
            if (item['translations'] is List) {
              for (final t in item['translations'] as List) {
                if (t is Map<String, dynamic>) {
                  final tLang = t['language_code']?.toString() ?? 'en';
                  await _db.upsertTranslation(
                    LocalProductTranslation(
                      id: '${id}_$tLang',
                      productId: id,
                      languageCode: tLang,
                      title: t['title']?.toString() ?? title,
                      description: t['description']?.toString() ?? desc,
                      materials: t['materials']?.toString() ?? mats,
                      careInstructions: t['care_instructions']?.toString() ?? care,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // In offline mode, silent fallback to local Drift cache
    }
  }

  /// Create and persist a new product with full 6-language translations
  Future<String> createProductWithTranslations({
    required String category,
    required double price,
    double? costPrice,
    String? primaryImageUrl,
    required Map<String, dynamic> translations,
  }) async {
    final productId = 'prod_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // 1. Save to local Drift DB initially as pending_sync
    await _db.upsertProduct(
      LocalProduct(
        id: productId,
        artisanId: 'artisan_local',
        category: category,
        price: price,
        costPrice: costPrice,
        status: 'pending_sync',
        stockQuantity: 1,
        primaryImageUrl: primaryImageUrl,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Save translations locally in Drift
    final transPayload = <Map<String, dynamic>>[];
    for (final entry in translations.entries) {
      final lang = entry.key;
      final data = entry.value;

      String title = '';
      String desc = '';
      String mats = '';
      String care = '';

      if (data is Map) {
        title = data['title']?.toString() ?? '';
        desc = (data['short_description'] ?? data['description'])?.toString() ?? '';
        mats = data['materials'] is List
            ? (data['materials'] as List).join(', ')
            : (data['materials']?.toString() ?? '');
        care = data['care_instructions']?.toString() ?? '';
      } else {
        try {
          title = (data.title as String?) ?? '';
          desc = (data.shortDescription as String?) ?? '';
          mats = (data.materials is List)
              ? (data.materials as List).join(', ')
              : '';
          care = (data.careInstructions as String?) ?? '';
        } catch (_) {}
      }

      await _db.upsertTranslation(
        LocalProductTranslation(
          id: '${productId}_$lang',
          productId: productId,
          languageCode: lang,
          title: title.isNotEmpty ? title : 'Handmade $category',
          description: desc,
          materials: mats,
          careInstructions: care,
        ),
      );

      transPayload.add({
        'language_code': lang,
        'title': title.isNotEmpty ? title : 'Handmade $category',
        'description': desc,
        'materials': mats,
        'care_instructions': care,
      });
    }

    // 3. Attempt server sync
    try {
      final res = await _apiClient.post(
        '/products',
        body: {
          'category': category,
          'price': price,
          'cost_price': costPrice,
          'status': 'live',
          'stock_quantity': 1,
          'primary_image_url': primaryImageUrl,
          'translations': transPayload,
        },
      );

      if (res is Map && res['id'] != null) {
        // Successfully published & synced! Update local Drift status to 'live'
        await _db.upsertProduct(
          LocalProduct(
            id: productId,
            artisanId: res['artisan_id']?.toString() ?? 'artisan_local',
            category: category,
            price: price,
            costPrice: costPrice,
            status: 'live',
            stockQuantity: 1,
            primaryImageUrl: primaryImageUrl,
            createdAt: now,
            updatedAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {
      // In offline mode: remains 'pending_sync' with badge in artisan catalogue
    }

    return productId;
  }
}
