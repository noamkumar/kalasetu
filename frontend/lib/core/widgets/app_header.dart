import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'connectivity_pill.dart';
import 'global_voice_command_sheet.dart';

/// KalaSetu App Header
/// Section 5.5 of Project Specification
/// Title, unread notification badge, and ConnectivityPill
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final int unreadNotifications;
  final ConnectivityState connectivityState;
  final int syncCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onConnectivityTap;
  final VoidCallback? onVoiceTap;
  final Widget? leading;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.unreadNotifications = 0,
    this.connectivityState = ConnectivityState.online,
    this.syncCount = 0,
    this.onNotificationTap,
    this.onConnectivityTap,
    this.onVoiceTap,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 76.0 : 64.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: AppTextStyles.headlineMedium(),
                      maxLines: 1,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildVoiceMic(context),
            const SizedBox(width: 4),
            _buildNotificationBell(),
            const SizedBox(width: 6),
            if (connectivityState != ConnectivityState.online || syncCount > 0)
              ConnectivityPill(
                state: connectivityState,
                syncCount: syncCount,
                onTap: onConnectivityTap,
              )
            else
              LiveConnectivityPill(
                onTap: onConnectivityTap,
              ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMic(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voice Command',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 24),
          tooltip: 'Voice Command',
          onPressed: () {
            if (onVoiceTap != null) {
              onVoiceTap!();
            } else {
              GlobalVoiceCommandSheet.show(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.notifications_outlined, color: AppColors.inkPrimary),
          tooltip: 'Notifications',
          onPressed: onNotificationTap ?? () {},
        ),
        if (unreadNotifications > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.craftTerracotta,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
