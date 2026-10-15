import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/native.dart';

import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/services/connectivity_service.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/api/api_client.dart';
import 'package:frontend/data/local_db/app_database.dart';
import 'package:frontend/features/catalogue/catalogue_screen.dart';
import 'package:frontend/features/home/home_shell.dart';
import 'package:frontend/features/product_detail/product_detail_screen.dart';
import 'package:frontend/features/product_detail/product_published_success_screen.dart';
import 'package:frontend/features/studio/simple_add_product_screen.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _map.containsKey(key) ? _map[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _map[key] = value;

  @override
  Future<void> delete(dynamic key) async => _map.remove(key);

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
    final memDb = AppDatabase(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(memDb);
    ConnectivityService.setInstanceForTesting(ConnectivityService.forTesting(db: memDb));

    final mockClient = MockClient((request) async {
      if (request.url.path.contains('unread-count')) {
        return http.Response(jsonEncode({'unread_count': 0}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path.contains('products')) {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'prod_test', 'artisan_id': 'artisan_local'}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });
    ApiClient.setClientForTesting(mockClient);

    final authBox = _FakeBox();
    final settingsBox = _FakeBox();
    await settingsBox.put(StorageService.keySimpleMode, true);
    await settingsBox.put(StorageService.keyAutoSpeakEnabled, false);
    await settingsBox.put(StorageService.keyLargeTextEnabled, false);
    await authBox.put(StorageService.keyAccessToken, 'test_token');
    await authBox.put(StorageService.keyUserRole, 'artisan');
    await settingsBox.put(StorageService.keyLanguageChosen, true);
    await settingsBox.put(StorageService.keyOnboardingCompleted, true);
    StorageService.initForTesting(authBox: authBox, settingsBox: settingsBox);
  });

  group('Product Publishing Navigation Bug Fix Tests', () {
    testWidgets('publishedSuccess route is not shadowed by /product/:id', (tester) async {
      // Navigate to /product/published-success
      appRouter.go(
        '${RouteNames.publishedSuccess}?product_id=prod_123&title=Handmade+Pot&price=500',
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Ensure ProductPublishedSuccessScreen is rendered, NOT ProductDetailScreen / "Product not found"
      expect(find.byType(ProductPublishedSuccessScreen), findsOneWidget);
      expect(find.byType(ProductDetailScreen), findsNothing);
      expect(find.text('Product not found'), findsNothing);
    });

    testWidgets('HomeShell updates active tab to Catalogue when initialTab changes to 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeShell(
            initialTab: 0,
            catalogueProductsStream: Stream.value(const []),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially on tab 0 (Add Product)
      expect(find.byType(SimpleAddProductScreen), findsOneWidget);

      // Rebuild with initialTab: 1 (Catalogue tab)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeShell(
            initialTab: 1,
            catalogueProductsStream: Stream.value(const []),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // didUpdateWidget switches _currentTab to 1, showing Catalogue instead of SimpleAddProductScreen
      expect(find.byType(SimpleAddProductScreen), findsNothing);
      expect(find.byType(CatalogueScreen), findsOneWidget);
    });

    testWidgets('SimpleAddProductScreen Publish button navigates to main Catalog screen', (tester) async {
      // Set draft on step 4 with valid publishing fields
      await StorageService.saveProductDraft({
        'currentStep': 4,
        'rawPhotoPath': '/test/photo.jpg',
        'cleanedTitle': 'Authentic Blue Pitcher',
        'cleanedDesc': 'Eco-friendly natural clay cooling vessel.',
        'category': 'pottery',
        'costFloor': 534,
        'selectedPrice': 650,
      });

      String? navigatedRoute;
      final testRouter = GoRouter(
        initialLocation: '/add/simple',
        routes: [
          GoRoute(
            path: '/add/simple',
            builder: (context, state) => const SimpleAddProductScreen(showAppBar: false),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return const Scaffold(body: Text('Catalog Page'));
            },
          ),
          GoRoute(
            path: '/product/:id',
            builder: (context, state) => const Scaffold(body: Text('Product Detail Error')),
          ),
        ],
      );

      testRouter.routerDelegate.addListener(() {
        navigatedRoute = testRouter.state.uri.toString();
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final publishBtn = find.byKey(const Key('yes_publish_btn'));
      expect(publishBtn, findsOneWidget);

      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);

      // Pump through async steps of _handlePublish and navigation
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Navigated to /home?tab=1 (main Catalog page)
      expect(navigatedRoute, equals('/home?tab=1'));
      expect(find.text('Catalog Page'), findsOneWidget);
      expect(find.text('Product Detail Error'), findsNothing);
      expect(find.text('Product not found'), findsNothing);
    });
  });
}
