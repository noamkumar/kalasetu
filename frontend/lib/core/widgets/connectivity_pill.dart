import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/connectivity_service.dart';
import '../../features/profile/developer_settings_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum ConnectivityState {
  online,
  syncing,
  serverUnreachable,
  noInternet,
  offline,
}

/// KalaSetu Connectivity Pill
/// Section 5.5 of Project Specification
/// Displays current network state & queued sync items count.
/// Distinguishes "No Internet" from "Server Not Reachable".
class ConnectivityPill extends StatelessWidget {
  final ConnectivityState state;
  final int syncCount;
  final VoidCallback? onTap;

  const ConnectivityPill({
    super.key,
    this.state = ConnectivityState.online,
    this.syncCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color bgColor;
    Color textColor;
    String label;

    String trOr(String key, String fallback) {
      try {
        final val = key.tr();
        if (val.isNotEmpty && val != key) {
          return val;
        }
      } catch (_) {}
      return fallback;
    }

    switch (state) {
      case ConnectivityState.online:
        dotColor = AppColors.statusOnline;
        bgColor = const Color(0xFFE8F5E9); // Pale green wash
        textColor = const Color(0xFF1B5E20);
        label = trOr('online', 'Online');
        break;
      case ConnectivityState.syncing:
        dotColor = AppColors.statusSyncing;
        bgColor = const Color(0xFFFFF3E0); // Pale amber wash
        textColor = const Color(0xFFE65100);
        final base = trOr('syncing', 'Syncing');
        label = syncCount > 0 ? '$base ($syncCount)' : base;
        break;
      case ConnectivityState.serverUnreachable:
        dotColor = AppColors.craftOchre;
        bgColor = const Color(0xFFFFF8E1); // Pale warm amber wash
        textColor = const Color(0xFFB78103);
        label = trOr('server_unreachable', 'Server Not Reachable');
        break;
      case ConnectivityState.noInternet:
        dotColor = AppColors.statusOffline;
        bgColor = const Color(0xFFEEEEEE); // Pale grey wash
        textColor = const Color(0xFF616161);
        label = trOr('no_internet', 'No Internet');
        break;
      case ConnectivityState.offline:
        dotColor = AppColors.statusOffline;
        bgColor = const Color(0xFFEEEEEE); // Pale grey wash
        textColor = const Color(0xFF616161);
        label = trOr('offline', 'Offline');
        break;
    }

    final pillWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: dotColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall(color: textColor).copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (state == ConnectivityState.serverUnreachable) {
          DeveloperSettingsDialog.show(context);
        }
      },
      child: pillWidget,
    );
  }
}

/// Live Connectivity Pill that reacts in real-time to ConnectivityService
class LiveConnectivityPill extends StatelessWidget {
  final VoidCallback? onTap;

  const LiveConnectivityPill({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final service = ConnectivityService.instance;
        return ConnectivityPill(
          state: service.state,
          syncCount: service.pendingSyncCount,
          onTap: onTap,
        );
      },
    );
  }
}

