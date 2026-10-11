import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../data/repositories/marketplace_repository.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  final MarketplaceRepository _marketRepo = MarketplaceRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filter = 'all'; // 'all', 'active', 'delivered', 'cancelled'

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final list = await _marketRepo.getBuyerOrders();
    if (mounted) {
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      final st = (o['status'] as String? ?? 'new').toLowerCase();
      if (_filter == 'all') return true;
      if (_filter == 'active') {
        return st == 'new' || st == 'pending' || st == 'accepted' || st == 'packed' || st == 'shipped';
      }
      if (_filter == 'delivered') return st == 'delivered';
      if (_filter == 'cancelled') return st == 'cancelled' || st == 'declined';
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadOrders,
      child: CustomScrollView(
        slivers: [
          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('order_filter_all'.tr(), 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('order_filter_active'.tr(), 'active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('order_filter_delivered'.tr(), 'delivered'),
                    const SizedBox(width: 8),
                    _buildFilterChip('order_filter_cancelled'.tr(), 'cancelled'),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyCraftState(
                  title: 'no_orders_title'.tr(),
                  subtitle: 'no_orders_desc'.tr(),
                  buttonLabel: 'tab_marketplace'.tr(),
                  onAction: () => context.go('/home?tab=0'),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
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
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final status = (order['status'] as String? ?? 'new').toLowerCase();
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final customerAddress = order['customer_address']?.toString() ?? '';

    Color statusBg;
    Color statusColor;
    String displayStatus;

    switch (status) {
      case 'new':
      case 'pending':
        statusBg = const Color(0xFFFFF3E0);
        statusColor = const Color(0xFFE65100);
        displayStatus = 'NEW';
        break;
      case 'accepted':
        statusBg = const Color(0xFFE8F5E9);
        statusColor = const Color(0xFF2E7D32);
        displayStatus = 'ACCEPTED';
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
      case 'declined':
        statusBg = const Color(0xFFFFEBEE);
        statusColor = const Color(0xFFC62828);
        displayStatus = status.toUpperCase();
        break;
      default:
        statusBg = const Color(0xFFF5F5F5);
        statusColor = AppColors.inkSecondary;
        displayStatus = status.toUpperCase();
    }

    return Container(
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
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Order #$shortId',
                    style: AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
          const SizedBox(height: 8),
          if (customerAddress.isNotEmpty) ...[
            Text(
              customerAddress,
              style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 16, color: AppColors.hairline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('total_amount_label'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                  Text(
                    '₹${totalAmount.toStringAsFixed(0)}',
                    style: AppTextStyles.titleMedium(color: AppColors.primary).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.timeline_rounded, size: 16),
                label: Text('track_order_btn'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => context.push('/order/track/$orderId'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
