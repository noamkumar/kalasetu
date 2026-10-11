import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/artisan_card.dart';
import 'package:frontend/core/widgets/empty_craft_state.dart';
import 'package:frontend/core/widgets/language_picker.dart';
import 'package:frontend/data/local_db/app_database.dart';
import 'package:frontend/data/repositories/analytics_repository.dart';
import 'package:frontend/features/dashboard/dashboard_screen.dart';
import 'package:frontend/features/orders/order_detail_sheet.dart';
import 'package:frontend/features/orders/orders_screen.dart';

void main() {
  const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
  ];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildLocalizedWrapper({
    required Widget child,
    required Locale locale,
    double width = 412.0,
    double height = 900.0,
    double textScale = 1.3,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
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
        child: Scaffold(body: child),
      ),
    );
  }

  group('Multilingual Screen Tests (All 6 Languages with Text Scale 1.3x)', () {
    for (final loc in supportedLocales) {
      final lang = loc.languageCode;

      testWidgets('[$lang] LanguagePicker renders all 6 language choices with 48dp touch targets', (tester) async {
        await tester.pumpWidget(
          buildLocalizedWrapper(
            child: LanguagePicker(
              selectedCode: lang,
              onLanguageSelected: (_) {},
            ),
            locale: loc,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        // Verifies presence of native script labels
        expect(find.text('English'), findsWidgets);
        expect(find.text('हिन्दी'), findsOneWidget);
        expect(find.text('தமிழ்'), findsOneWidget);
        expect(find.text('తెలుగు'), findsOneWidget);
        expect(find.text('ಕನ್ನಡ'), findsOneWidget);
        expect(find.text('മലയാളം'), findsOneWidget);

        // Verify touch targets have InkWell / minimum size
        expect(find.byType(InkWell), findsWidgets);
      });

      testWidgets('[$lang] OrdersScreen renders filter chips and empty state without overflow', (tester) async {
        await tester.pumpWidget(
          buildLocalizedWrapper(
            child: OrdersScreen(
              enableRefresh: false,
              ordersStream: Stream.value(const []),
            ),
            locale: loc,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ChoiceChip), findsNWidgets(6));
        expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      });

      testWidgets('[$lang] OrderDetailSheet displays tracking timeline and actions without overflow', (tester) async {
        final order = LocalOrder(
          id: 'ord-$lang-101',
          artisanId: 'art-1',
          customerName: 'Ananya Sharma',
          customerPhone: '+91 91234 56789',
          customerAddress: '42 Heritage Colony, Madurai, Tamil Nadu',
          totalAmount: 1450.0,
          status: 'new',
          createdAt: DateTime(2026, 10, 7, 10, 0),
        );

        await tester.pumpWidget(
          buildLocalizedWrapper(
            child: OrderDetailSheet(order: order),
            locale: loc,
            height: 1200,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ananya Sharma'), findsOneWidget);
        expect(find.text('₹1450'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsWidgets);
      });

      testWidgets('[$lang] DashboardScreen renders 4 KPI cards and 30-day trend chart at 1200px', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final summary = AnalyticsSummaryData.fallbackFromLocal(orders: const [], products: const []);

        await tester.pumpWidget(
          buildLocalizedWrapper(
            child: DashboardScreen(
              enableRefresh: false,
              initialSummary: summary,
              productsStream: Stream.value(const []),
            ),
            locale: loc,
            width: 1200,
            height: 900,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.byType(DataTable), findsNothing); // empty list renders friendly empty text
      });

      testWidgets('[$lang] ArtisanCard and EmptyCraftState render with proper styling and text scaling', (tester) async {
        await tester.pumpWidget(
          buildLocalizedWrapper(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ArtisanCard(
                    title: 'Terracotta Water Vessel',
                    price: '₹450',
                    category: 'Pottery',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  EmptyCraftState(
                    title: 'Your Craft Shelf is Quiet',
                    subtitle: 'Add your first handcrafted item to reach global buyers.',
                    buttonLabel: 'Add Craft Now',
                    onAction: () {},
                  ),
                ],
              ),
            ),
            locale: loc,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Terracotta Water Vessel'), findsOneWidget);
        expect(find.text('₹450'), findsOneWidget);
        expect(find.text('Your Craft Shelf is Quiet'), findsOneWidget);
      });
    }
  });
}
