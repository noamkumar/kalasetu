import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/local_db/app_database.dart';
import 'package:frontend/data/repositories/analytics_repository.dart';
import 'package:frontend/features/orders/order_detail_sheet.dart';
import 'package:frontend/features/orders/orders_screen.dart';
import 'package:frontend/features/dashboard/dashboard_screen.dart';
import 'package:frontend/features/kalamitra/services/kalamitra_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestWrapper(Widget child, {double width = 400.0, double height = 900.0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(body: child),
      ),
    );
  }

  group('Phase 6 Unit Tests - Analytics & Assistant', () {
    test('AnalyticsSummaryData fallback calculation aggregates metrics accurately', () {
      final now = DateTime.now();
      final orders = [
        LocalOrder(
          id: 'ord-1',
          artisanId: 'art-1',
          customerName: 'Aarav Sharma',
          customerPhone: '9876543210',
          customerAddress: 'Jaipur, Rajasthan',
          totalAmount: 1200.0,
          status: 'new',
          createdAt: now,
        ),
        LocalOrder(
          id: 'ord-2',
          artisanId: 'art-1',
          customerName: 'Priya Patel',
          customerPhone: '9876543211',
          customerAddress: 'Ahmedabad, Gujarat',
          totalAmount: 2400.0,
          status: 'delivered',
          createdAt: now,
        ),
        LocalOrder(
          id: 'ord-3',
          artisanId: 'art-1',
          customerName: 'Kavita Devi',
          customerPhone: '9876543212',
          customerAddress: 'Varanasi, UP',
          totalAmount: 800.0,
          status: 'cancelled',
          createdAt: now,
        ),
      ];

      final products = [
        LocalProduct(
          id: 'p-1',
          artisanId: 'art-1',
          category: 'Pottery',
          price: 1200.0,
          status: 'active',
          stockQuantity: 10,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = AnalyticsSummaryData.fallbackFromLocal(
        orders: orders,
        products: products,
      );

      // Cancelled orders are excluded from total revenue
      expect(summary.totalRevenue, equals(3600.0));
      expect(summary.totalOrders, equals(3));
      expect(summary.pendingOrders, equals(1));
      expect(summary.deliveredOrders, equals(1));
      expect(summary.activeProducts, equals(1));
      expect(summary.trend30Days.length, equals(30));
      expect(summary.popularCrafts.isNotEmpty, isTrue);
    });

    test('AnalyticsSummaryData.fromJson parses server API response correctly', () {
      final json = {
        'total_revenue': 54300.0,
        'total_orders': 42,
        'pending_orders': 4,
        'delivered_orders': 36,
        'active_products': 8,
        'popular_crafts': [
          {'category': 'Handloom', 'orders_count': 18, 'revenue': 22400.0},
          {'category': 'Pottery', 'orders_count': 12, 'revenue': 14200.0},
        ],
        'trend_30_days': [
          {'date': '2026-10-01', 'day': 1, 'revenue': 1400.0, 'orders': 2},
          {'date': '2026-10-02', 'day': 2, 'revenue': 1800.0, 'orders': 3},
        ],
      };

      final parsed = AnalyticsSummaryData.fromJson(json);
      expect(parsed.totalRevenue, equals(54300.0));
      expect(parsed.totalOrders, equals(42));
      expect(parsed.pendingOrders, equals(4));
      expect(parsed.deliveredOrders, equals(36));
      expect(parsed.popularCrafts.length, equals(2));
      expect(parsed.popularCrafts.first.category, equals('Handloom'));
      expect(parsed.trend30Days.length, equals(2));
    });

    test('KalaMitraService rule-based fallback detects intent and returns response', () {
      final service = KalaMitraService();
      
      final addResp = service.offlineFallback('I want to add a new terracotta vase', 'home', 'hi');
      expect(addResp.action, equals('navigate'));
      expect(addResp.route, contains('studio'));

      final orderResp = service.offlineFallback('Show my pending orders please', 'home', 'en');
      expect(orderResp.action, equals('navigate'));
      expect(orderResp.route, contains('orders'));

      final langResp = service.offlineFallback('Change language to Tamil', 'home', 'en');
      expect(langResp.action, equals('change_language'));
      expect(langResp.targetLang, equals('ta'));

      final explainResp = service.offlineFallback('Explain what this screen does', 'pricing', 'en');
      expect(explainResp.action, equals('explain'));
      expect(explainResp.reply.isNotEmpty, isTrue);
    });
  });

  group('Phase 6 Widget Tests - UI Components', () {
    testWidgets('OrderDetailSheet displays customer details, tracking timeline and action buttons', (WidgetTester tester) async {
      final testOrder = LocalOrder(
        id: 'ord-test-123456',
        artisanId: 'art-1',
        customerName: 'Meera Nambiar',
        customerPhone: '+91 98765 43210',
        customerAddress: '124 Temple Road, Thrissur, Kerala',
        totalAmount: 1850.0,
        status: 'new',
        createdAt: DateTime(2026, 10, 7, 10, 30),
      );

      await tester.pumpWidget(
        buildTestWrapper(
          OrderDetailSheet(order: testOrder),
          height: 1100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meera Nambiar'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('₹1850'), findsOneWidget);
      expect(find.text('timeline_order_placed'), findsOneWidget);
      expect(find.text('accept_order_btn'), findsOneWidget);
      expect(find.text('decline_order_btn'), findsOneWidget);
    });

    testWidgets('OrdersScreen renders filter chips for all 6 statuses', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWrapper(
          OrdersScreen(
            enableRefresh: false,
            ordersStream: Stream.value(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(6));
      expect(find.text('order_filter_all'), findsOneWidget);
      expect(find.text('order_filter_new'), findsOneWidget);
      expect(find.text('order_filter_packed'), findsOneWidget);
      expect(find.text('order_filter_shipped'), findsOneWidget);
      expect(find.text('order_filter_delivered'), findsOneWidget);
      expect(find.text('order_filter_cancelled'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders KPI cards, 30-day trend chart, and products table', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      final summary = AnalyticsSummaryData.fallbackFromLocal(orders: const [], products: const []);

      await tester.pumpWidget(
        buildTestWrapper(
          DashboardScreen(
            enableRefresh: false,
            initialSummary: summary,
            productsStream: Stream.value(const []),
          ),
          width: 1200,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('dashboard_nav_overview'), findsOneWidget);
      expect(find.text('dashboard_nav_products'), findsOneWidget);
      expect(find.text('dashboard_nav_analytics'), findsOneWidget);
      expect(find.text('kpi_revenue'), findsOneWidget);
      expect(find.text('kpi_orders'), findsOneWidget);
      expect(find.text('kpi_pending'), findsOneWidget);
      expect(find.text('kpi_products'), findsOneWidget);
      expect(find.text('trend_30_days_title'), findsOneWidget);
      expect(find.text('popular_crafts_title'), findsOneWidget);
      expect(find.text('products_table_title'), findsOneWidget);
    });
  });
}
