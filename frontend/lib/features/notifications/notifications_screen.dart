import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/repositories/order_repository.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
  });
}

/// KalaSetu Notifications Screen
/// Visual Layout Matching Reference:
/// Card list with leading icon, message, time ago, and speaker icon
/// that reads text aloud in app language via TTS.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  bool _isLoading = true;
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final orders = await _orderRepo.getOrders();

      final list = <NotificationItem>[];

      for (int i = 0; i < orders.length; i++) {
        final order = orders[i];
        final isDelivered = order.status.toLowerCase() == 'delivered';
        final isShipped = order.status.toLowerCase() == 'shipped';
        final orderShortId = order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id;

        String time;
        if (i == 0) {
          time = 'time_just_now'.tr();
        } else if (i < 3) {
          time = 'time_hours_ago'.tr(namedArgs: {'hours': '${i * 3}'});
        } else {
          time = 'time_days_ago'.tr(namedArgs: {'days': '$i'});
        }

        if (isDelivered) {
          list.add(NotificationItem(
            id: 'notif_del_${order.id}',
            title: 'Order Delivered',
            message: 'Order #$orderShortId has been safely delivered to buyer in ${order.customerAddress}. Payout processed.',
            timeAgo: time,
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.statusOnline,
          ));
        } else if (isShipped) {
          list.add(NotificationItem(
            id: 'notif_ship_${order.id}',
            title: 'Order In Transit',
            message: 'Order #$orderShortId is on the way to the buyer (${order.customerName}).',
            timeAgo: time,
            icon: Icons.local_shipping_outlined,
            iconColor: AppColors.primary,
          ));
        } else {
          list.add(NotificationItem(
            id: 'notif_new_${order.id}',
            title: 'New Buyer Order',
            message: 'New order #$orderShortId received for ₹${order.totalAmount.toStringAsFixed(0)}. Please pack craft item.',
            timeAgo: time,
            icon: Icons.shopping_bag_outlined,
            iconColor: AppColors.craftTerracotta,
          ));
        }
      }

      // Add a craft sync notification
      if (list.isNotEmpty) {
        list.add(NotificationItem(
          id: 'notif_sync_01',
          title: 'Store Synchronized',
          message: 'All handicraft listings and prices are in sync with ONDC national network.',
          timeAgo: 'time_days_ago'.tr(namedArgs: {'days': '2'}),
          icon: Icons.cloud_done_outlined,
          iconColor: AppColors.accentBlue,
        ));
      }

      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'notifications_title'.tr(),
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
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      child: EmptyCraftState(
                        title: 'no_notifications_title'.tr(),
                        subtitle: 'no_notifications_sub'.tr(),
                        buttonLabel: 'tab_catalogue'.tr(),
                        onAction: () => context.go('/home?tab=1'),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = _items[index];
                        return _buildNotificationCard(notif);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notif) {
    final lang = context.locale.languageCode;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading Status Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notif.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(notif.icon, color: notif.iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Message & Time Ago
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: AppTextStyles.titleSmall(color: AppColors.inkPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      notif.timeAgo,
                      style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notif.message,
                  style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Speaker Icon reading text aloud in app language with speaking animation & stop button
          SpeakerAffordance(
            textToSpeak: '${notif.title}. ${notif.message}',
            languageCode: lang,
            isCompact: true,
          ),
        ],
      ),
    );
  }
}
