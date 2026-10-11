import '../api/api_client.dart';
import '../local_db/app_database.dart';

class OrderRepository {
  final ApiClient _apiClient;
  final AppDatabase _db;

  OrderRepository({
    ApiClient? apiClient,
    AppDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? AppDatabase();

  Stream<List<LocalOrder>> watchOrders() => _db.watchOrders();

  Future<void> refreshOrders() async {
    try {
      final result = await _apiClient.get('/api/v1/orders');
      if (result is List) {
        for (final item in result) {
          if (item is Map<String, dynamic>) {
            final now = DateTime.now();
            final createdAt = item['created_at'] != null
                ? DateTime.tryParse(item['created_at'].toString()) ?? now
                : now;

            await _db.upsertOrder(
              LocalOrder(
                id: item['id'] as String,
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
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<void> acceptOrder(String orderId) async {
    await _db.updateOrderStatus(orderId, 'accepted');
    try {
      await _apiClient.patch('/api/v1/orders/$orderId/accept');
    } catch (_) {}
  }

  Future<void> declineOrder(String orderId) async {
    await _db.updateOrderStatus(orderId, 'declined');
    try {
      await _apiClient.patch('/api/v1/orders/$orderId/decline');
    } catch (_) {}
  }

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? trackingId,
    String? courierName,
  }) async {
    final norm = newStatus.toLowerCase().trim();
    await _db.updateOrderStatus(orderId, norm);
    try {
      final body = <String, dynamic>{'status': norm};
      if (trackingId != null) body['tracking_id'] = trackingId;
      if (courierName != null) body['courier_name'] = courierName;
      await _apiClient.patch('/api/v1/orders/$orderId/status', body: body);
    } catch (_) {
      // Offline mode: locally updated
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await _db.updateOrderStatus(orderId, 'cancelled');
    try {
      await _apiClient.patch('/api/v1/orders/$orderId/cancel');
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final res = await _apiClient.get('/api/v1/orders/$orderId');
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return null;
  }

  Future<List<LocalOrder>> getOrders() async {
    return await _db.watchOrders().first;
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _apiClient.get('/api/v1/orders/unread-count');
      if (res is Map && res.containsKey('unread_count')) {
        return (res['unread_count'] as num).toInt();
      }
    } catch (_) {}
    return await _db.getUnreadOrderCount();
  }
}
