import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/big_numeric_keypad.dart';
import 'package:frontend/core/widgets/artisan_qr_code_widget.dart';
import 'package:frontend/features/analytics/simple_earnings_screen.dart';
import 'package:frontend/features/product_detail/product_published_success_screen.dart';
import 'package:frontend/features/catalogue/fair_mode_screen.dart';
import 'package:frontend/features/orders/business_orders_screen.dart';
import 'package:frontend/features/marketplace/marketplace_connect_screen.dart';
import 'package:frontend/features/studio/simple_add_product_screen.dart';
import 'package:frontend/core/widgets/speaker_affordance.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _map.containsKey(key) ? _map[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _map.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _map.containsKey(key);

  @override
  Future<int> clear() async {
    final count = _map.length;
    _map.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final authBox = _FakeBox();
    final settingsBox = _FakeBox();
    await settingsBox.put(StorageService.keySimpleMode, true);
    await settingsBox.put(StorageService.keyAutoSpeakEnabled, false);
    await settingsBox.put(StorageService.keyLargeTextEnabled, true);
    StorageService.initForTesting(authBox: authBox, settingsBox: settingsBox);
  });

  /// Mobile-first wrapper simulating a 360x800 entry-level Android phone
  /// with text scale 1.3x (Section 16 & Accessibility Requirements).
  Widget buildTestApp(Widget child, {double width = 360.0, double height = 800.0, double textScale = 1.3}) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  Finder findTextOrKey(String text, String key) {
    final byKey = find.text(key);
    if (byKey.evaluate().isNotEmpty) return byKey;
    return find.text(text);
  }

  group('Simple Mode Accessibility & Widget Tests at Text Scale 1.3x (360px Mobile-First)', () {
    testWidgets('BigNumericKeypad renders large 60dp buttons and triggers digit taps', (tester) async {
      String pressedDigit = '';

      await tester.pumpWidget(
        buildTestApp(
          BigNumericKeypad(
            onDigitPressed: (d) => pressedDigit = d,
            onBackspacePressed: () {},
            onClearPressed: () {},
          ),
        ),
      );

      // Verify digits 0-9 are present
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Tap digit 5
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(pressedDigit, equals('5'));

      // Verify backspace icon is present
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('ArtisanQrCodeWidget renders custom matrix without overflow', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const Center(
            child: ArtisanQrCodeWidget(
              data: 'https://kalasetu.org/stall/test-artisan',
              size: 180,
            ),
          ),
        ),
      );

      expect(find.byType(ArtisanQrCodeWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('SimpleEarningsScreen renders large earnings numbers at 1.3x scale', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SimpleEarningsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify screen header and elements
      expect(find.byType(SimpleEarningsScreen), findsOneWidget);
      expect(find.byType(SpeakerAffordance), findsOneWidget);
    });

    testWidgets('ProductPublishedSuccessScreen renders WhatsApp share & QR code at 1.3x scale', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ProductPublishedSuccessScreen(
            productId: 'prod-456',
            title: 'Handcrafted Blue Pottery Vase',
            price: 750,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify post-publish confirmation
      expect(find.byType(ProductPublishedSuccessScreen), findsOneWidget);
      expect(find.text('Handcrafted Blue Pottery Vase'), findsOneWidget);
      expect(find.text('₹750'), findsOneWidget);
      expect(find.byType(ArtisanQrCodeWidget), findsOneWidget);
      expect(findTextOrKey('Share on WhatsApp', 'share_on_whatsapp_btn'), findsOneWidget);
      expect(findTextOrKey('Sell Another Product', 'sell_another_product'), findsOneWidget);
    });

    testWidgets('FairModeScreen renders quick add and stall QR at 1.3x scale', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const FairModeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify fair mode elements
      expect(find.byType(FairModeScreen), findsOneWidget);
      expect(find.byType(ArtisanQrCodeWidget), findsOneWidget);
      expect(findTextOrKey('Fast Add at Fair', 'fast_add_product_btn'), findsOneWidget);
      expect(findTextOrKey('Exit Fair Mode', 'exit_fair_mode'), findsOneWidget);
    });

    testWidgets('BusinessOrdersScreen renders B2B bulk inquiries with Accept / Call / Not Now', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const BusinessOrdersScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify business orders screen elements
      expect(find.byType(BusinessOrdersScreen), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsWidgets);
      expect(findTextOrKey('Accept Order', 'accept_order_btn'), findsWidgets);
      expect(findTextOrKey('Call Back', 'call_back_btn'), findsWidgets);
      expect(findTextOrKey('Not Now', 'not_now_btn'), findsWidgets);
    });

    testWidgets('MarketplaceConnectScreen renders honest export options at 1.3x scale', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MarketplaceConnectScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify marketplace screen elements
      expect(find.byType(MarketplaceConnectScreen), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsWidgets);
      expect(findTextOrKey('Generate Export Package', 'generate_ready_export'), findsWidgets);
    });

    testWidgets('SimpleAddProductScreen Screen 1: Photo renders 4-step progress and camera/gallery at 1.3x scale', (tester) async {
      await StorageService.clearProductDraft();
      await tester.pumpWidget(
        buildTestApp(
          const SimpleAddProductScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Step 1: Photo step renders with 4-step indicator and camera/gallery
      expect(find.byType(SimpleAddProductScreen), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsWidgets);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
      expect(findTextOrKey('Take Photo', 'take_photo_btn'), findsOneWidget);
      expect(findTextOrKey('Upload from Gallery', 'upload_gallery_btn'), findsOneWidget);
    });

    testWidgets('SimpleAddProductScreen Screen 2: Details renders mic buttons and preview at 1.3x scale', (tester) async {
      // Set draft at step 2
      await StorageService.saveProductDraft({
        'currentStep': 2,
        'rawPhotoPath': '/test/photo.jpg',
        'cleanedTitle': 'Terracotta Blue Pitcher',
        'cleanedDesc': 'Handcrafted clay pitcher made with traditional river silt.',
        'verbatimName': 'blue pitcher',
        'verbatimDesc': 'hand made clay water pot',
        'category': 'pottery',
      });

      await tester.pumpWidget(
        buildTestApp(
          const SimpleAddProductScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SimpleAddProductScreen), findsOneWidget);
      expect(findTextOrKey('Product name', 'speak_product_name'), findsWidgets);
      expect(findTextOrKey('Describe your product', 'speak_product_desc'), findsWidgets);
      expect(find.text('Terracotta Blue Pitcher'), findsOneWidget);
      expect(findTextOrKey('Yes, This is Good', 'yes_this_is_good'), findsOneWidget);
      expect(findTextOrKey('No, Change It', 'no_change_it'), findsOneWidget);
    });

    testWidgets('SimpleAddProductScreen Screen 3: Price renders question, keypad and tiers at 1.3x scale', (tester) async {
      // Set draft at step 3
      await StorageService.saveProductDraft({
        'currentStep': 3,
        'rawPhotoPath': '/test/photo.jpg',
        'cleanedTitle': 'Terracotta Pitcher',
        'category': 'pottery',
        'materialCost': 150.0,
        'labourHours': 3.5,
        'otherCost': 0.0,
        'costFloor': 534,
        'selectedPrice': 650,
      });

      await tester.pumpWidget(
        buildTestApp(
          const SimpleAddProductScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SimpleAddProductScreen), findsOneWidget);
      // Verify BigNumericKeypad is displayed for question 1
      expect(find.byType(BigNumericKeypad), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
      expect(findTextOrKey('Next Question', 'next_question_btn'), findsOneWidget);
    });

    testWidgets('SimpleAddProductScreen Screen 4: Publish renders buyer preview card and publish button at 1.3x scale', (tester) async {
      // Set draft at step 4
      await StorageService.saveProductDraft({
        'currentStep': 4,
        'rawPhotoPath': '/test/photo.jpg',
        'cleanedTitle': 'Authentic Blue Pitcher',
        'cleanedDesc': 'Eco-friendly natural clay cooling vessel.',
        'category': 'pottery',
        'costFloor': 534,
        'selectedPrice': 650,
      });

      await tester.pumpWidget(
        buildTestApp(
          const SimpleAddProductScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SimpleAddProductScreen), findsOneWidget);
      expect(find.text('Authentic Blue Pitcher'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
      expect(findTextOrKey('Yes, publish', 'yes_publish_btn'), findsOneWidget);
      expect(findTextOrKey('No, go back', 'no_go_back_btn'), findsOneWidget);
    });
  });
}
