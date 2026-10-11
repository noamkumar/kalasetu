import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../data/repositories/marketplace_repository.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MarketplaceRepository _marketRepo = MarketplaceRepository();
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    final res = await _marketRepo.getOrderDetails(widget.orderId);
    if (mounted) {
      setState(() {
        _order = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('cancel_order_confirm_title'.tr(), style: AppTextStyles.titleMedium()),
        content: Text('cancel_order_confirm_msg'.tr(), style: AppTextStyles.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('cancel_order_btn'.tr(), style: AppTextStyles.labelMedium(color: AppColors.statusError)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isCancelling = true);
      try {
        await _marketRepo.cancelOrder(widget.orderId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('order_cancelled_notice'.tr()),
            backgroundColor: AppColors.statusOnline,
          ),
        );
        _loadOrder();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('ApiException: ', '')),
            backgroundColor: AppColors.statusError,
          ),
        );
      } finally {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.statusError),
              const SizedBox(height: 12),
              Text('no_orders_title'.tr(), style: AppTextStyles.titleLarge()),
              const SizedBox(height: 16),
              AppButton(label: 'retry'.tr(), onPressed: _loadOrder),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final status = (order['status'] as String? ?? 'new').toLowerCase();
    final trackingId = order['tracking_id'] as String?;
    final courierName = order['courier_name'] as String?;
    final paymentMethod = order['payment_method'] as String? ?? 'cash_on_delivery';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final customerName = order['customer_name'] as String? ?? '';
    final customerAddress = order['customer_address'] as String? ?? '';
    final customerPhone = order['customer_phone'] as String? ?? '';

    final canCancel = status == 'new' || status == 'pending' || status == 'accepted' || status == 'packed';
    final isShippedOrDelivered = status == 'shipped' || status == 'delivered';
    final isCancelled = status == 'cancelled';
    final isDeclined = status == 'declined';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'track_order_title'.tr(),
          style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
        ),
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh, color: AppColors.inkSecondary),
            tooltip: 'retry'.tr(),
            onPressed: _loadOrder,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              Container(
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
                        Text(
                          'Order #${widget.orderId.substring(0, 8.clamp(0, widget.orderId.length))}',
                          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.hairline),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.inkSecondary),
                        const SizedBox(width: 8),
                        Text(customerName, style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: AppColors.inkSecondary),
                        const SizedBox(width: 8),
                        Text(customerPhone, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.inkSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customerAddress,
                            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.hairline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paymentMethod == 'cash_on_delivery'
                                  ? 'payment_cod'.tr()
                                  : 'payment_pay_later'.tr(),
                              style: AppTextStyles.labelSmall(color: AppColors.primary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('total_amount_label'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                          ],
                        ),
                        Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: AppTextStyles.titleLarge(color: AppColors.primary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Courier Tracking Card (if shipped)
              if (trackingId != null && trackingId.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courierName != null && courierName.isNotEmpty
                                  ? courierName
                                  : 'Courier Partner',
                              style: AppTextStyles.labelMedium(color: AppColors.primaryDark).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Tracking ID: $trackingId',
                              style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                        tooltip: 'Copy Tracking ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: trackingId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tracking ID copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Vertical Timeline
              Text(
                'tracking_timeline_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 12),
              _buildVerticalTimeline(status, trackingId, courierName),
              const SizedBox(height: 28),

              // Cancel Before Shipping Action Button
              if (canCancel) ...[
                AppButton(
                  label: 'cancel_order_btn'.tr(),
                  variant: AppButtonVariant.outlined,
                  isLoading: _isCancelling,
                  isFullWidth: true,
                  onPressed: _handleCancelOrder,
                ),
              ] else if (isShippedOrDelivered) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'cannot_cancel_shipped'.tr(),
                          style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isCancelled || isDeclined) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.statusError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCancelled ? 'order_cancelled_notice'.tr() : 'order_declined_notice'.tr(),
                    style: AppTextStyles.labelMedium(color: AppColors.statusError),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'new':
      case 'pending':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        text = 'NEW';
        break;
      case 'accepted':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        text = 'ACCEPTED';
        break;
      case 'packed':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        text = 'PACKED';
        break;
      case 'shipped':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        text = 'SHIPPED';
        break;
      case 'delivered':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        text = 'DELIVERED';
        break;
      case 'cancelled':
      case 'declined':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        text = status.toUpperCase();
        break;
      default:
        bg = AppColors.hairline;
        fg = AppColors.inkSecondary;
        text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall(color: fg).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVerticalTimeline(String currentStatus, String? trackingId, String? courierName) {
    if (currentStatus == 'cancelled' || currentStatus == 'declined') {
      return Column(
        children: [
          _buildTimelineNode(
            title: 'timeline_order_placed'.tr(),
            subtitle: 'timeline_completed'.tr(),
            isCompleted: true,
            isCurrent: false,
            icon: Icons.check_circle_rounded,
            color: AppColors.primary,
            showLine: true,
          ),
          _buildTimelineNode(
            title: currentStatus == 'cancelled' ? 'order_cancelled_notice'.tr() : 'order_declined_notice'.tr(),
            subtitle: 'timeline_completed'.tr(),
            isCompleted: true,
            isCurrent: true,
            icon: Icons.cancel_rounded,
            color: AppColors.statusError,
            showLine: false,
          ),
        ],
      );
    }

    final steps = [
      {'key': 'new', 'title': 'timeline_order_placed'.tr(), 'icon': Icons.shopping_bag_outlined},
      {'key': 'accepted', 'title': 'timeline_accepted'.tr(), 'icon': Icons.thumb_up_alt_outlined},
      {'key': 'packed', 'title': 'timeline_handcrafted_packed'.tr(), 'icon': Icons.inventory_2_outlined},
      {
        'key': 'shipped',
        'title': trackingId != null
            ? '${'timeline_shipped_transit'.tr()} (${courierName ?? 'Courier'}: $trackingId)'
            : 'timeline_shipped_transit'.tr(),
        'icon': Icons.local_shipping_outlined
      },
      {'key': 'delivered', 'title': 'timeline_delivered'.tr(), 'icon': Icons.home_outlined},
    ];

    final orderSequence = ['new', 'accepted', 'packed', 'shipped', 'delivered'];
    final norm = (currentStatus == 'pending') ? 'new' : currentStatus;
    final currIdx = orderSequence.indexOf(norm);

    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isCompleted = i <= currIdx;
        final isCurrent = i == currIdx;
        final isLast = i == steps.length - 1;

        Color nodeColor = AppColors.hairline;
        IconData nodeIcon = step['icon'] as IconData;

        if (isCurrent) {
          nodeColor = AppColors.craftOchre;
        } else if (isCompleted) {
          nodeColor = AppColors.primary;
          nodeIcon = Icons.check_circle_rounded;
        }

        return _buildTimelineNode(
          title: step['title'] as String,
          subtitle: isCurrent
              ? 'timeline_current_status'.tr()
              : (isCompleted ? 'timeline_completed'.tr() : 'timeline_pending_step'.tr()),
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          icon: nodeIcon,
          color: nodeColor,
          showLine: !isLast,
        );
      }),
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required IconData icon,
    required Color color,
    required bool showLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? color.withValues(alpha: 0.15) : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted || isCurrent ? color : AppColors.hairline,
                  width: isCurrent ? 2 : 1.5,
                ),
              ),
              child: Icon(icon, size: 16, color: isCompleted || isCurrent ? color : AppColors.inkSecondary),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? AppColors.primary : AppColors.hairline,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLarge(
                    color: isCompleted || isCurrent ? AppColors.inkPrimary : AppColors.inkSecondary,
                  ).copyWith(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall(
                    color: isCurrent ? AppColors.craftOchre : AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
