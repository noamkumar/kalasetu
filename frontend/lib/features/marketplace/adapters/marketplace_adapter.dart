import 'dart:convert';
import '../../../data/local_db/app_database.dart';

/// Standardized export package for government and digital marketplaces
class MarketplaceExportPackage {
  final String marketplace;
  final String productId;
  final String titleEn;
  final String titleHi;
  final String descriptionEn;
  final String descriptionHi;
  final String category;
  final double price;
  final String hsnCode;
  final List<String> photoUrls;
  final String artisanName;
  final String clusterLocation;
  final DateTime preparedAt;

  const MarketplaceExportPackage({
    required this.marketplace,
    required this.productId,
    required this.titleEn,
    required this.titleHi,
    required this.descriptionEn,
    required this.descriptionHi,
    required this.category,
    required this.price,
    required this.hsnCode,
    required this.photoUrls,
    required this.artisanName,
    required this.clusterLocation,
    required this.preparedAt,
  });

  Map<String, dynamic> toJson() => {
        'marketplace': marketplace,
        'product_id': productId,
        'titles': {
          'en': titleEn,
          'hi': titleHi,
        },
        'descriptions': {
          'en': descriptionEn,
          'hi': descriptionHi,
        },
        'category': category,
        'price_inr': price,
        'hsn_code': hsnCode,
        'photos': photoUrls,
        'artisan': {
          'name': artisanName,
          'cluster': clusterLocation,
        },
        'prepared_at': preparedAt.toIso8601String(),
        'status': 'ready_for_submission',
      };

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Marketplace Adapter Interface
/// Requirement 14: Honest placeholder behind an interface (e.g. GeM or ONDC).
/// Produces a ready-to-submit listing export. Does NOT fake a live integration.
abstract class MarketplaceAdapter {
  String get marketplaceName;
  String get marketplaceCode;
  String get portalDescription;
  bool get isLiveIntegration;
  String get statusNote;

  Future<MarketplaceExportPackage> prepareExport({
    required LocalProduct product,
    required List<LocalProductTranslation> translations,
    required String artisanName,
    required String clusterLocation,
  });
}

/// GeM (Government e-Marketplace) Adapter
class GeMMarketplaceAdapter implements MarketplaceAdapter {
  @override
  String get marketplaceName => 'Government e-Marketplace (GeM)';

  @override
  String get marketplaceCode => 'gem';

  @override
  String get portalDescription =>
      'National procurement portal for central and state government departments, emporiums, and public offices.';

  @override
  bool get isLiveIntegration => false;

  @override
  String get statusNote => 'Coming soon — Listing export generator active';

  @override
  Future<MarketplaceExportPackage> prepareExport({
    required LocalProduct product,
    required List<LocalProductTranslation> translations,
    required String artisanName,
    required String clusterLocation,
  }) async {
    final transEn = translations.firstWhere(
      (t) => t.languageCode == 'en',
      orElse: () => translations.isNotEmpty
          ? translations.first
          : LocalProductTranslation(
              id: 'fallback',
              productId: product.id,
              languageCode: 'en',
              title: '${product.category} Craft',
            ),
    );

    final transHi = translations.firstWhere(
      (t) => t.languageCode == 'hi',
      orElse: () => transEn,
    );

    // Standard artisan HSN codes
    String hsn = '69120010'; // Pottery / ceramic
    if (product.category.toLowerCase().contains('handloom') ||
        product.category.toLowerCase().contains('textile')) {
      hsn = '50072010'; // Silk/cotton handloom
    } else if (product.category.toLowerCase().contains('wood')) {
      hsn = '44201000'; // Wooden statuettes/crafts
    } else if (product.category.toLowerCase().contains('jewelry')) {
      hsn = '71131910'; // Traditional jewellery
    } else if (product.category.toLowerCase().contains('bamboo')) {
      hsn = '46021100'; // Bamboo basketwork
    }

    final photos = <String>[];
    if (product.enhancedImageUrl != null && product.enhancedImageUrl!.isNotEmpty) {
      photos.add(product.enhancedImageUrl!);
    }
    if (product.primaryImageUrl != null && product.primaryImageUrl!.isNotEmpty) {
      photos.add(product.primaryImageUrl!);
    }

    return MarketplaceExportPackage(
      marketplace: 'GeM',
      productId: product.id,
      titleEn: transEn.title,
      titleHi: transHi.title,
      descriptionEn: transEn.description ?? 'Authentic handcrafted product.',
      descriptionHi: transHi.description ?? 'प्रामाणिक हस्तशिल्प उत्पाद।',
      category: product.category,
      price: product.price,
      hsnCode: hsn,
      photoUrls: photos,
      artisanName: artisanName,
      clusterLocation: clusterLocation,
      preparedAt: DateTime.now(),
    );
  }
}

/// ONDC (Open Network for Digital Commerce) Adapter
class ONDCMarketplaceAdapter implements MarketplaceAdapter {
  @override
  String get marketplaceName => 'ONDC (Open Network for Digital Commerce)';

  @override
  String get marketplaceCode => 'ondc';

  @override
  String get portalDescription =>
      'Interoperable network linking Indian artisans directly to buyer apps like Paytm, Magicpin, and pincode-based sellers.';

  @override
  bool get isLiveIntegration => false;

  @override
  String get statusNote => 'Coming soon — Ready-to-submit schema export';

  @override
  Future<MarketplaceExportPackage> prepareExport({
    required LocalProduct product,
    required List<LocalProductTranslation> translations,
    required String artisanName,
    required String clusterLocation,
  }) async {
    final gemAdapter = GeMMarketplaceAdapter();
    final base = await gemAdapter.prepareExport(
      product: product,
      translations: translations,
      artisanName: artisanName,
      clusterLocation: clusterLocation,
    );

    return MarketplaceExportPackage(
      marketplace: 'ONDC',
      productId: base.productId,
      titleEn: base.titleEn,
      titleHi: base.titleHi,
      descriptionEn: base.descriptionEn,
      descriptionHi: base.descriptionHi,
      category: base.category,
      price: base.price,
      hsnCode: base.hsnCode,
      photoUrls: base.photoUrls,
      artisanName: base.artisanName,
      clusterLocation: base.clusterLocation,
      preparedAt: DateTime.now(),
    );
  }
}
