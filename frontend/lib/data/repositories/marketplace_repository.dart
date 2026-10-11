import '../api/api_client.dart';
import '../local_db/app_database.dart';
import 'product_repository.dart';

class MarketplacePage {
  final List<DisplayProduct> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const MarketplacePage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}

class MarketplaceRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;

  MarketplaceRepository({
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase();

  /// Fetch public paginated products localized for buyer
  Future<MarketplacePage> getMarketplaceProducts({
    String? category,
    String? search,
    String lang = 'en',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'lang': lang,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final res = await _apiClient.get(
        '/api/v1/marketplace/products',
        queryParams: queryParams,
      );

      if (res is Map<String, dynamic>) {
        final rawItems = res['items'] as List? ?? [];
        final items = rawItems.map((item) {
          final m = item as Map<String, dynamic>;
          final now = DateTime.now();
          return DisplayProduct(
            id: m['id']?.toString() ?? '',
            artisanId: m['artisan_id']?.toString() ?? '',
            category: m['category']?.toString() ?? 'Pottery',
            price: (m['price'] as num?)?.toDouble() ?? 0.0,
            costPrice: (m['cost_price'] as num?)?.toDouble(),
            status: m['status']?.toString() ?? 'live',
            stockQuantity: (m['stock_quantity'] as num?)?.toInt() ?? 1,
            primaryImageUrl: m['primary_image_url']?.toString(),
            enhancedImageUrl: m['enhanced_image_url']?.toString(),
            title: m['title']?.toString() ?? 'Craft Item',
            description: m['description']?.toString(),
            materials: m['materials']?.toString(),
            careInstructions: m['care_instructions']?.toString(),
            createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) ?? now : now,
          );
        }).toList();

        return MarketplacePage(
          items: items,
          total: (res['total'] as num?)?.toInt() ?? items.length,
          page: (res['page'] as num?)?.toInt() ?? page,
          limit: (res['limit'] as num?)?.toInt() ?? limit,
          totalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (_) {
      // Offline fallback: load from local Drift products
    }

    // Offline Drift query
    final localProds = await _db.getAllProducts();
    final items = <DisplayProduct>[];
    for (final p in localProds) {
      if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
        if (!p.category.toLowerCase().contains(category.toLowerCase())) continue;
      }
      final transList = await _db.getTranslationsForProduct(p.id);
      LocalProductTranslation? target;
      for (final t in transList) {
        if (t.languageCode == lang) {
          target = t;
          break;
        }
      }
      final chosen = target ?? (transList.isNotEmpty ? transList.first : null);
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        final title = chosen?.title.toLowerCase() ?? '';
        final desc = chosen?.description?.toLowerCase() ?? '';
        if (!title.contains(query) && !desc.contains(query)) continue;
      }

      items.add(DisplayProduct(
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

    return MarketplacePage(
      items: items,
      total: items.length,
      page: 1,
      limit: items.length,
      totalPages: 1,
    );
  }

  /// Get single marketplace product by ID
  Future<DisplayProduct?> getMarketplaceProductById(String id, String lang) async {
    try {
      final res = await _apiClient.get(
        '/api/v1/marketplace/products/$id',
        queryParams: {'lang': lang},
      );
      if (res is Map<String, dynamic>) {
        final now = DateTime.now();
        return DisplayProduct(
          id: res['id']?.toString() ?? id,
          artisanId: res['artisan_id']?.toString() ?? '',
          category: res['category']?.toString() ?? 'Pottery',
          price: (res['price'] as num?)?.toDouble() ?? 0.0,
          costPrice: (res['cost_price'] as num?)?.toDouble(),
          status: res['status']?.toString() ?? 'live',
          stockQuantity: (res['stock_quantity'] as num?)?.toInt() ?? 1,
          primaryImageUrl: res['primary_image_url']?.toString(),
          enhancedImageUrl: res['enhanced_image_url']?.toString(),
          title: res['title']?.toString() ?? 'Handmade Craft',
          description: res['description']?.toString(),
          materials: res['materials']?.toString(),
          careInstructions: res['care_instructions']?.toString(),
          createdAt: res['created_at'] != null ? DateTime.tryParse(res['created_at'].toString()) ?? now : now,
        );
      }
    } catch (_) {}

    return ProductRepository(apiClient: _apiClient, db: _db).getProductById(id, lang);
  }

  /// Place a new Buy Now order
  Future<Map<String, dynamic>> placeOrder({
    required String productId,
    required int quantity,
    required double unitPrice,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String paymentMethod,
  }) async {
    final body = {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'payment_method': paymentMethod,
    };

    final res = await _apiClient.post('/api/v1/orders', body: body);
    if (res is Map<String, dynamic>) {
      // Store into local Drift DB for offline tracking
      final now = DateTime.now();
      final createdAt = res['created_at'] != null ? DateTime.tryParse(res['created_at'].toString()) ?? now : now;
      await _db.upsertOrder(
        LocalOrder(
          id: res['id']?.toString() ?? 'order_${now.millisecondsSinceEpoch}',
          artisanId: res['artisan_id']?.toString() ?? '',
          customerName: customerName,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          totalAmount: (res['total_amount'] as num?)?.toDouble() ?? (unitPrice * quantity),
          status: res['status']?.toString() ?? 'new',
          createdAt: createdAt,
        ),
      );
      return res;
    }
    throw const ApiException(message: 'Failed to place order');
  }

  /// Get buyer's orders
  Future<List<Map<String, dynamic>>> getBuyerOrders() async {
    try {
      final res = await _apiClient.get('/api/v1/orders/buyer');
      if (res is List) {
        final list = <Map<String, dynamic>>[];
        for (final item in res) {
          if (item is Map<String, dynamic>) {
            list.add(item);
            final now = DateTime.now();
            final createdAt = item['created_at'] != null ? DateTime.tryParse(item['created_at'].toString()) ?? now : now;
            await _db.upsertOrder(
              LocalOrder(
                id: item['id']?.toString() ?? '',
                artisanId: item['artisan_id']?.toString() ?? '',
                customerName: item['customer_name']?.toString() ?? '',
                customerPhone: item['customer_phone']?.toString() ?? '',
                customerAddress: item['customer_address']?.toString() ?? '',
                totalAmount: (item['total_amount'] as num?)?.toDouble() ?? 0.0,
                status: item['status']?.toString() ?? 'new',
                createdAt: createdAt,
              ),
            );
          }
        }
        return list;
      }
    } catch (_) {}

    // Offline fallback from Drift
    final orders = await _db.getAllOrders();
    return orders.map((o) => {
      'id': o.id,
      'artisan_id': o.artisanId,
      'customer_name': o.customerName,
      'customer_phone': o.customerPhone,
      'customer_address': o.customerAddress,
      'total_amount': o.totalAmount,
      'status': o.status,
      'created_at': o.createdAt.toIso8601String(),
    }).toList();
  }

  /// Fetch order details including events timeline
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final res = await _apiClient.get('/api/v1/orders/$orderId');
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return null;
  }

  /// Cancel order before shipping
  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final res = await _apiClient.patch('/api/v1/orders/$orderId/cancel');
    if (res is Map<String, dynamic>) {
      await _db.updateOrderStatus(orderId, 'cancelled');
      return res;
    }
    throw const ApiException(message: 'Failed to cancel order');
  }
}
