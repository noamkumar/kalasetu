import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../data/local_db/app_database.dart';
import '../../data/repositories/order_repository.dart';

class OrderDetailSheet extends StatefulWidget {
  final LocalOrder order;
  final VoidCallback? onStatusChanged;

  const OrderDetailSheet({
    super.key,
    required this.order,
    this.onStatusChanged,
  });

  static Future<void> show(BuildContext context, LocalOrder order, {VoidCallback? onStatusChanged}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailSheet(
        order: order,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final OrderRepository _orderRepo = OrderRepository();
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status.toLowerCase().trim();
  }

  Future<void> _updateStatus(String nextStatus, {String? trackingId, String? courierName}) async {
    setState(() => _isUpdating = true);
    await _orderRepo.updateOrderStatus(
      widget.order.id,
      nextStatus,
      trackingId: trackingId,
      courierName: courierName,
    );
    if (!mounted) return;
    setState(() {
      _currentStatus = nextStatus;
      _isUpdating = false;
    });
    widget.onStatusChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('order_status_updated'.tr(args: [nextStatus.toUpperCase()])),
        backgroundColor: AppColors.statusOnline,
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isUpdating = true);
    await _orderRepo.acceptOrder(widget.order.id);
    if (!mounted) return;
    setState(() {
      _currentStatus = 'accepted';
      _isUpdating = false;
    });
    widget.onStatusChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('order_accepted_notice'.tr()),
        backgroundColor: AppColors.statusOnline,
      ),
    );
  }

  Future<void> _handleDecline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('decline_order_confirm_title'.tr(), style: AppTextStyles.titleMedium()),
        content: Text('decline_order_confirm_msg'.tr(), style: AppTextStyles.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('decline_order_btn'.tr(), style: AppTextStyles.labelMedium(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isUpdating = true);
      await _orderRepo.declineOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        _currentStatus = 'declined';
        _isUpdating = false;
      });
      widget.onStatusChanged?.call();
    }
  }

  Future<void> _openShipDialog() async {
    final courierController = TextEditingController(text: 'India Post');
    final trackingController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('ship_order_title'.tr(), style: AppTextStyles.titleMedium()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('courier_name_label'.tr(), style: AppTextStyles.labelMedium()),
            const SizedBox(height: 6),
            TextField(
              controller: courierController,
              decoration: InputDecoration(
                hintText: 'courier_name_hint'.tr(),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            Text('tracking_id_label'.tr(), style: AppTextStyles.labelMedium()),
            const SizedBox(height: 6),
            TextField(
              controller: trackingController,
              decoration: InputDecoration(
                hintText: 'tracking_id_hint'.tr(),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
            ),
            onPressed: () {
              if (trackingController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text('confirm_shipment_btn'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateStatus(
        'shipped',
        trackingId: trackingController.text.trim(),
        courierName: courierController.text.trim(),
      );
    }
  }

  void _handleCancelConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('order_cancel_confirm_title'.tr(), style: AppTextStyles.titleMedium()),
        content: Text('order_cancel_confirm_msg'.tr(), style: AppTextStyles.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateStatus('cancelled');
            },
            child: Text('order_cancel_btn'.tr(), style: AppTextStyles.labelMedium(color: AppColors.statusError)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isCancelled = _currentStatus == 'cancelled';
    final isDeclined = _currentStatus == 'declined';
    final isDelivered = _currentStatus == 'delivered';

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8.clamp(0, order.id.length))}',
                        style: AppTextStyles.titleLarge(color: AppColors.inkPrimary),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
                        style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.inkSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Details Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(order.customerName, style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 18, color: AppColors.inkSecondary),
                        const SizedBox(width: 8),
                        Text(order.customerPhone, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: AppColors.inkSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.customerAddress,
                            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.hairline),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('total_payout_label'.tr(), style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary)),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(0)}',
                          style: AppTextStyles.titleLarge(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tracking Timeline Title
              Text(
                'tracking_timeline_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 12),

              // Tracking Timeline Stepper
              _buildTimelineStepper(),
              const SizedBox(height: 24),

              // Status Action Buttons
              if (_isUpdating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                if (_currentStatus == 'new' || _currentStatus == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'accept_order_btn'.tr(),
                          variant: AppButtonVariant.primary,
                          onPressed: _handleAccept,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'decline_order_btn'.tr(),
                          variant: AppButtonVariant.outlined,
                          onPressed: _handleDecline,
                        ),
                      ),
                    ],
                  ),
                ] else if (_currentStatus == 'accepted') ...[
                  AppButton(
                    label: 'mark_as_packed_btn'.tr(),
                    isFullWidth: true,
                    onPressed: () => _updateStatus('packed'),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'order_cancel_btn'.tr(),
                    variant: AppButtonVariant.outlined,
                    isFullWidth: true,
                    onPressed: _handleCancelConfirm,
                  ),
                ] else if (_currentStatus == 'packed') ...[
                  AppButton(
                    label: 'mark_as_shipped_btn'.tr(),
                    isFullWidth: true,
                    onPressed: _openShipDialog,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'order_cancel_btn'.tr(),
                    variant: AppButtonVariant.outlined,
                    isFullWidth: true,
                    onPressed: _handleCancelConfirm,
                  ),
                ] else if (_currentStatus == 'shipped') ...[
                  AppButton(
                    label: 'mark_as_delivered_btn'.tr(),
                    isFullWidth: true,
                    onPressed: () => _updateStatus('delivered'),
                  ),
                ] else if (isDelivered) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusOnline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'order_completed_notice'.tr(),
                        style: AppTextStyles.labelMedium(color: AppColors.statusOnline),
                      ),
                    ),
                  ),
                ] else if (isCancelled || isDeclined) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusError.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        isCancelled ? 'order_cancelled_notice'.tr() : 'order_declined_notice'.tr(),
                        style: AppTextStyles.labelMedium(color: AppColors.statusError),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStepper() {
    if (_currentStatus == 'cancelled' || _currentStatus == 'declined') {
      final isDeclined = _currentStatus == 'declined';
      return Column(
        children: [
          _buildTimelineNode(
            title: 'timeline_order_placed'.tr(),
            subtitle: DateFormat('dd MMM, hh:mm a').format(widget.order.createdAt),
            isCompleted: true,
            isCurrent: false,
            icon: Icons.check_circle_rounded,
            color: AppColors.primary,
            showLine: true,
          ),
          _buildTimelineNode(
            title: isDeclined ? 'timeline_order_declined'.tr() : 'timeline_order_cancelled'.tr(),
            subtitle: isDeclined ? 'order_declined_notice'.tr() : 'timeline_order_cancelled_sub'.tr(),
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
      {'key': 'accepted', 'title': 'timeline_accepted'.tr(), 'icon': Icons.check_circle_outline},
      {'key': 'packed', 'title': 'timeline_handcrafted_packed'.tr(), 'icon': Icons.inventory_2_outlined},
      {'key': 'shipped', 'title': 'timeline_shipped_transit'.tr(), 'icon': Icons.local_shipping_outlined},
      {'key': 'delivered', 'title': 'timeline_delivered'.tr(), 'icon': Icons.home_outlined},
    ];

    final orderSequence = ['new', 'accepted', 'packed', 'shipped', 'delivered'];
    final norm = (_currentStatus == 'pending') ? 'new' : _currentStatus;
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
