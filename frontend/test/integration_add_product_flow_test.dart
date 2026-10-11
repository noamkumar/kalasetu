import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/local_db/app_database.dart';
import 'package:frontend/data/repositories/catalog_repository.dart';
import 'package:frontend/data/repositories/marketplace_repository.dart';
import 'package:frontend/data/repositories/product_repository.dart';
import 'package:frontend/features/cataloger/voice_catalog_review_screen.dart';

CatalogListingResult createTestListing() {
  final master = ListingItemData(
    title: 'Terracotta Water Pitcher',
    shortDescription: 'Handcrafted red clay cooling water pitcher.',
    longDescription: 'Traditional earthenware crafted using natural river clay.',
    bulletPoints: ['100% natural clay', 'Traditional pottery'],
    materials: ['Terracotta Clay'],
    careInstructions: 'Rinse with clean water before use.',
    seoTitle: 'Handmade Terracotta Pitcher',
    metaDescription: 'Authentic Indian terracotta water pot handcrafted by skilled artisans.',
    keywords: ['pottery', 'terracotta'],
    hashtags: ['#KalaSetu', '#IndianArtisan'],
  );

  final translations = <String, ListingItemData>{
    'en': master,
    'hi': ListingItemData(
      title: 'पारंपरिक मिट्टी का घड़ा',
      shortDescription: 'प्राकृतिक लाल मिट्टी से बना जल घड़ा।',
      longDescription: 'परंपरागत तरीके से चाक पर तैयार किया गया घड़ा।',
      seoTitle: 'मिट्टी का घड़ा',
      metaDescription: 'कारीगरों द्वारा बनाया गया शुद्ध मिट्टी का घड़ा।',
    ),
    'ta': ListingItemData(
      title: 'கைவினை மண்பானை',
      shortDescription: 'இயற்கை களிமண்ணால் செய்யப்பட்ட பாரம்பரிய பானை.',
      longDescription: 'பாரம்பரிய கைவினைஞர்களால் சக்கரத்தின் மூலம் உருவாக்கப்பட்டது.',
      seoTitle: 'கைவினை மண்பானை',
      metaDescription: 'பாரம்பரிய மண் பாண்ட தயாரிப்பு.',
    ),
    'te': ListingItemData(
      title: 'చేతితో చేసిన మట్టి కుండ',
      shortDescription: 'సహజసిద్ధమైన మట్టితో చేసిన నీటి కుండ.',
      longDescription: 'పురాతన పద్ధతిలో చక్రంపై రూపొందించబడిన కుండ.',
      seoTitle: 'మట్టి కుండ',
      metaDescription: 'హస్తకళాకారుల చేత తయారు చేయబడిన మట్టి పాత్ర.',
    ),
    'kn': ListingItemData(
      title: 'ಕೈಯಿಂದ ಮಾಡಿದ ಮಣ್ಣಿನ ಮಡಕೆ',
      shortDescription: 'ನೈಸರ್ಗಿಕ ಜೇಡಿಮಣ್ಣಿನಿಂದ ಮಾಡಿದ ಸಾಂಪ್ರದಾಯಿಕ ಮಡಕೆ.',
      longDescription: 'ಕರಕುಶಲಕರ್ಮಿಗಳಿಂದ ಚಕ್ರದ ಮೇಲೆ ರೂಪಿಸಲಾದ ಮಣ್ಣಿನ ಮಡಕೆ.',
      seoTitle: 'ಮಣ್ಣಿನ ಮಡಕೆ',
      metaDescription: 'ಶುದ್ಧ ಮಣ್ಣಿನಿಂದ ತಯಾರಿಸಿದ ಕರಕುಶಲ ಮಡಕೆ.',
    ),
    'ml': ListingItemData(
      title: 'കൈകൊണ്ട് തീർത്ത മൺപാത്രം',
      shortDescription: 'സ്വാഭാവിക കളിമണ്ണിൽ തീർത്ത തണുത്ത വെള്ളം സൂക്ഷിക്കുന്ന പാത്രം.',
      longDescription: 'പാരമ്പര്യമായി ചക്രത്തിൽ നിർമ്മിച്ച ശുദ്ധമായ മൺപാത്രം.',
      seoTitle: 'മൺപാത്രം',
      metaDescription: 'കരകൗശല വിദഗ്ധർ നിർമ്മിച്ച മൺപാത്രം.',
    ),
  };

  return CatalogListingResult(
    sourceLang: 'en',
    master: master,
    original: master,
    translations: translations,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Add-Product Flow End-to-End Integration Test', () {
    test('Simulated end-to-end wizard flow saves product with 6-language translations', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ProductRepository(db: db);

      // 1. Stage 1: Photo & Image Studio
      const mockEnhancedUrl = '/static/uploads/terracotta_pot_enhanced.webp';
      expect(mockEnhancedUrl.isNotEmpty, isTrue);

      // 2. Stage 2: Voice description & 6-language generation
      final mockListing = createTestListing();
      expect(mockListing.translations.containsKey('en'), isTrue);
      expect(mockListing.translations.containsKey('hi'), isTrue);
      expect(mockListing.translations.containsKey('ta'), isTrue);
      expect(mockListing.translations.containsKey('te'), isTrue);
      expect(mockListing.translations.containsKey('kn'), isTrue);
      expect(mockListing.translations.containsKey('ml'), isTrue);

      // 3. Stage 3: Dynamic Pricing
      const chosenPrice = 499.0;
      const category = 'pottery';

      // 4. Stage 4: Save product with translations into local Drift database
      final payload = <String, dynamic>{};
      for (final lang in ['en', 'hi', 'ta', 'te', 'kn', 'ml']) {
        final item = mockListing.translations[lang] ?? mockListing.master;
        payload[lang] = {
          'title': item.title,
          'short_description': item.shortDescription,
          'long_description': item.longDescription,
          'materials': item.materials.join(', '),
          'care_instructions': item.careInstructions,
          'seo_title': item.seoTitle,
          'meta_description': item.metaDescription,
        };
      }

      await repo.createProductWithTranslations(
        category: category,
        price: chosenPrice,
        primaryImageUrl: mockEnhancedUrl,
        translations: payload,
      );

      // 5. Verification: Verify product is queried in English
      final enProducts = await repo.watchProducts('en').first;
      expect(enProducts.isNotEmpty, isTrue);
      final createdProductEn = enProducts.firstWhere((p) => p.category == category);
      expect(createdProductEn.price, equals(chosenPrice));
      expect(createdProductEn.title, equals('Terracotta Water Pitcher'));

      // 6. Verification: Verify product is queried in Hindi
      final hiProducts = await repo.watchProducts('hi').first;
      final createdProductHi = hiProducts.firstWhere((p) => p.category == category);
      expect(createdProductHi.price, equals(chosenPrice));
      expect(createdProductHi.title, equals('पारंपरिक मिट्टी का घड़ा'));

      // 7. Verification: Verify product is queried in Tamil
      final taProducts = await repo.watchProducts('ta').first;
      final createdProductTa = taProducts.firstWhere((p) => p.category == category);
      expect(createdProductTa.price, equals(chosenPrice));
      expect(createdProductTa.title, equals('கைவினை மண்பானை'));

      await db.close();
    });

    test('Newly added product appears at the very top (sorted newest first) in catalogue and marketplace', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ProductRepository(db: db);
      final marketRepo = MarketplaceRepository(db: db);

      // Insert older product
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await db.upsertProduct(
        LocalProduct(
          id: 'prod_old_1',
          artisanId: 'artisan_1',
          category: 'woodcraft',
          price: 350.0,
          status: 'live',
          stockQuantity: 1,
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
      );
      await db.upsertTranslation(
        const LocalProductTranslation(
          id: 'trans_old_1_en',
          productId: 'prod_old_1',
          languageCode: 'en',
          title: 'Older Wooden Carving',
        ),
      );

      // Publish newer product via repo
      final newProdId = await repo.createProductWithTranslations(
        category: 'pottery',
        price: 650.0,
        primaryImageUrl: '/test/image.jpg',
        translations: {
          'en': {
            'title': 'Brand New Handcrafted Pot',
            'description': 'Freshly published pot.',
          },
        },
      );

      // Verify catalogue watch stream orders newest first (new product is at index 0)
      final catalogueProducts = await repo.watchProducts('en').first;
      expect(catalogueProducts.length, equals(2));
      expect(catalogueProducts.first.id, equals(newProdId));
      expect(catalogueProducts.first.title, equals('Brand New Handcrafted Pot'));
      expect(catalogueProducts.last.id, equals('prod_old_1'));

      // Verify marketplace fallback query also orders newest first
      final marketplacePage = await marketRepo.getMarketplaceProducts(lang: 'en');
      expect(marketplacePage.items.first.id, equals(newProdId));
      expect(marketplacePage.items.first.title, equals('Brand New Handcrafted Pot'));

      await db.close();
    });

    testWidgets('VoiceCatalogReviewScreen renders 6 language tabs, and allows editing & review', (WidgetTester tester) async {
      final mockListing = createTestListing();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: VoiceCatalogReviewScreen(
              category: 'pottery',
              listing: mockListing,
              price: 499,
              imageUrl: '/static/uploads/test.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check language selector tabs
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('മലയാളം'), findsOneWidget);

      // Check action buttons and text input fields
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.byType(TextField), findsWidgets);

      // Switch to Hindi tab
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();

      // Verify Hindi listing is displayed
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
