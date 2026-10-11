import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/local_db/app_database.dart';
import '../../data/repositories/order_repository.dart';
import 'order_detail_sheet.dart';

class OrdersScreen extends StatefulWidget {
  final String initialFilter;
  final Stream<List<LocalOrder>>? ordersStream;
  final bool enableRefresh;

  const OrdersScreen({
    super.key,
    this.initialFilter = 'all',
    this.ordersStream,
    this.enableRefresh = true,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  late String _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter.toLowerCase().trim();
    if (widget.enableRefresh) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    await _orderRepo.refreshOrders();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: StreamBuilder<List<LocalOrder>>(
        initialData: const [],
        stream: widget.ordersStream ?? _orderRepo.watchOrders(),
        builder: (context, snapshot) {
          final allOrders = snapshot.data ?? [];
          final filtered = allOrders.where((o) {
            final st = o.status.toLowerCase().trim();
            if (_statusFilter == 'all') return true;
            if (_statusFilter == 'new') return st == 'new' || st == 'pending';
            return st == _statusFilter;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('order_filter_all'.tr(), 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('order_filter_new'.tr(), 'new'),
                        const SizedBox(width: 8),
                        _buildFilterChip('order_filter_packed'.tr(), 'packed'),
                        const SizedBox(width: 8),
                        _buildFilterChip('order_filter_shipped'.tr(), 'shipped'),
                        const SizedBox(width: 8),
                        _buildFilterChip('order_filter_delivered'.tr(), 'delivered'),
                        const SizedBox(width: 8),
                        _buildFilterChip('order_filter_cancelled'.tr(), 'cancelled'),
                      ],
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.inkSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'no_orders_title'.tr(),
                            style: AppTextStyles.headlineMedium(),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'no_orders_desc'.tr(),
                              style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = filtered[index];
                        return _buildOrderCard(order);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: AppTextStyles.labelSmall(
          color: isSelected ? Colors.white : AppColors.inkPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.hairline,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }

  Widget _buildOrderCard(LocalOrder order) {
    final normStatus = order.status.toLowerCase().trim();
    Color statusBg;
    Color statusColor;
    String displayStatus;

    switch (normStatus) {
      case 'new':
      case 'pending':
        statusBg = const Color(0xFFFFF3E0);
        statusColor = const Color(0xFFE65100);
        displayStatus = 'NEW';
        break;
      case 'packed':
        statusBg = const Color(0xFFFFF8E1);
        statusColor = const Color(0xFFF57F17);
        displayStatus = 'PACKED';
        break;
      case 'shipped':
        statusBg = const Color(0xFFE3F2FD);
        statusColor = const Color(0xFF1565C0);
        displayStatus = 'SHIPPED';
        break;
      case 'delivered':
        statusBg = const Color(0xFFE8F5E9);
        statusColor = const Color(0xFF2E7D32);
        displayStatus = 'DELIVERED';
        break;
      case 'cancelled':
        statusBg = const Color(0xFFFFEBEE);
        statusColor = const Color(0xFFC62828);
        displayStatus = 'CANCELLED';
        break;
      default:
        statusBg = const Color(0xFFF5F5F5);
        statusColor = AppColors.inkSecondary;
        displayStatus = normStatus.toUpperCase();
    }

    return InkWell(
      onTap: () => OrderDetailSheet.show(context, order, onStatusChanged: _refresh),
      borderRadius: BorderRadius.circular(AppRadii.cardRadius.topLeft.x),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Order #${order.id.substring(0, 8.clamp(0, order.id.length))}',
                          style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    displayStatus,
                    style: AppTextStyles.labelSmall(color: statusColor).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              order.customerName,
              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              order.customerAddress,
              style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 20, color: AppColors.hairline),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'total_amount_label'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: AppTextStyles.titleMedium(color: AppColors.primary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.timeline_rounded, size: 16),
                  label: Text(
                    'track_order_btn'.tr(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => OrderDetailSheet.show(context, order, onStatusChanged: _refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
