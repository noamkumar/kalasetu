import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_text_styles.dart';

/// KalaMitra Draggable Floating Action Button
///
/// Section 5.5 of Project Specification & User Requirements:
/// 1. Default size: 52 dp round icon-only button (avatar), no label. Tapping opens assistant sheet.
/// 2. Draggable anywhere; on release snaps to nearest screen edge (left or right).
/// 3. Clamped within safe area, above bottom nav and below header.
/// 4. Remembers position in Hive via [StorageService] and restores it.
/// 5. Long press menu with:
///    - "Hide for now": shrinks to a small edge tab that can be pulled back out.
///    - "Reset position": restores default bottom-right position.
/// 6. Fades to 50% opacity while scrolling ([isScrolling] = true).
/// 7. Hides on screens with primary bottom buttons ([hide] = true).
/// 8. Accessibility labels for screen readers.
class KalaMitraFab extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isScrolling;
  final bool hide;
  final VoidCallback? onResetPosition;

  // Kept for backward compatibility with existing callers
  final String? label;
  final bool isExtended;

  static const double buttonSize = 52.0;
  static const double edgeTabWidth = 24.0;
  static const double edgeTabHeight = 52.0;
  static const double edgeMargin = 12.0;

  const KalaMitraFab({
    super.key,
    this.onTap,
    this.isScrolling = false,
    this.hide = false,
    this.onResetPosition,
    this.label,
    this.isExtended = false,
  });

  @override
  State<KalaMitraFab> createState() => _KalaMitraFabState();
}

class _KalaMitraFabState extends State<KalaMitraFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  double? _currentX;
  double? _currentY;
  bool _isDockedOnRight = true;
  bool _isDockedTab = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _isDockedOnRight = StorageService.kalaMitraIsRight;
    _isDockedTab = StorageService.isKalaMitraHidden;
    StorageService.kalaMitraResetNotifier.addListener(_onResetFromStorage);
  }

  void _onResetFromStorage() {
    if (mounted) {
      setState(() {
        _isDockedTab = false;
        _isDockedOnRight = true;
        _currentX = null;
        _currentY = null;
      });
    }
  }

  @override
  void dispose() {
    StorageService.kalaMitraResetNotifier.removeListener(_onResetFromStorage);
    _snapController.dispose();
    super.dispose();
  }

  void _snapToNearestEdge(
    double width,
    double height,
    double leftBound,
    double rightBound,
    double topBound,
    double bottomBound,
  ) {
    final curX = _currentX ?? rightBound;
    final curY = _currentY ?? (bottomBound - 16.0);
    final midX = width / 2.0;
    final snapToRight = (curX + KalaMitraFab.buttonSize / 2.0) >= midX;
    final targetX = snapToRight ? rightBound : leftBound;

    // Immediately persist and update docked state
    _isDockedOnRight = snapToRight;
    final yRatio = curY / height;
    StorageService.saveKalaMitraPosition(
      yRatio: yRatio,
      isRight: snapToRight,
    );

    _snapAnimation = Tween<double>(begin: curX, end: targetX).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _currentX = _snapAnimation!.value;
          });
        }
      });

    _snapController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentX = targetX;
        });
      }
    });
  }

  void _expandFromTab() {
    setState(() {
      _isDockedTab = false;
    });
    StorageService.setKalaMitraHidden(false);
  }

  Future<void> _handleReset() async {
    await StorageService.resetKalaMitraPosition();
    if (mounted) {
      setState(() {
        _isDockedTab = false;
        _isDockedOnRight = true;
        _currentX = null;
        _currentY = null;
      });
    }
    widget.onResetPosition?.call();
  }

  Future<void> _showLongPressMenu(
    BuildContext context,
    double canvasWidth,
    double canvasHeight,
    double buttonX,
    double buttonY,
  ) async {
    final position = RelativeRect.fromLTRB(
      math.max(0.0, buttonX - 160.0),
      math.max(0.0, buttonY - 80.0),
      math.max(0.0, canvasWidth - buttonX),
      math.max(0.0, canvasHeight - buttonY),
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      elevation: 6,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      items: [
        PopupMenuItem<String>(
          value: 'hide',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_off_outlined,
                  color: AppColors.inkSecondary, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'kalamitra_hide_tab'.tr(),
                  style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'reset',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'kalamitra_reset_pos'.tr(),
                  style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;
    if (selected == 'hide') {
      setState(() => _isDockedTab = true);
      await StorageService.setKalaMitraHidden(true);
    } else if (selected == 'reset') {
      _handleReset();
    }
  }

  Widget _buildAvatarIcon({double size = 22.0}) {
    return Container(
      width: 32.0,
      height: 32.0,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }

  static const List<BoxShadow> _dragShadow = [
    BoxShadow(
      color: Color.fromRGBO(43, 46, 42, 0.14),
      blurRadius: 28.0,
      offset: Offset(0, 12),
      spreadRadius: -2,
    ),
  ];

  Widget _buildRoundButton() {
    return Semantics(
      button: true,
      label: 'kalamitra_assistant'.tr(),
      hint: 'kalamitra_drag_hint'.tr(),
      child: AnimatedScale(
        scale: _isDragging ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: KalaMitraFab.buttonSize,
          height: KalaMitraFab.buttonSize,
          decoration: BoxDecoration(
            color: AppColors.accentBlue,
            shape: BoxShape.circle,
            boxShadow: _isDragging ? _dragShadow : AppElevation.floatingShadow,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: Center(
              child: _buildAvatarIcon(size: 22.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeTab() {
    final borderRadius = _isDockedOnRight
        ? const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
          );

    return Semantics(
      button: true,
      label: 'kalamitra_show_tab'.tr(),
      hint: 'kalamitra_reset_hint'.tr(),
      child: Container(
        width: KalaMitraFab.edgeTabWidth,
        height: KalaMitraFab.edgeTabHeight,
        decoration: BoxDecoration(
          color: AppColors.accentBlue,
          borderRadius: borderRadius,
          boxShadow: AppElevation.floatingShadow,
        ),
        child: Center(
          child: Icon(
            _isDockedOnRight
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: Colors.white,
            size: 20.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hide) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // In constrained/small containers (e.g. standalone test or small box)
        if (width <= 80 || height <= 80) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isScrolling ? 0.5 : 1.0,
            child: GestureDetector(
              onTap: widget.onTap,
              onLongPress: () => _showLongPressMenu(
                context,
                width,
                height,
                0.0,
                0.0,
              ),
              child: _buildRoundButton(),
            ),
          );
        }

        final safe = MediaQuery.paddingOf(context);
        final leftBound = safe.left + KalaMitraFab.edgeMargin;
        final rightBound =
            math.max(leftBound, width - KalaMitraFab.buttonSize - safe.right - KalaMitraFab.edgeMargin);
        final topBound = safe.top + 8.0;
        final bottomBound = math.max(
            topBound,
            height - KalaMitraFab.buttonSize - (safe.bottom > 0 ? safe.bottom : 16.0));

        // Restore or initialize positions
        if (_currentY == null) {
          final savedYRatio = StorageService.kalaMitraYRatio;
          if (savedYRatio != null) {
            _currentY = (savedYRatio * height).clamp(topBound, bottomBound);
          } else {
            // Default position near bottom right
            _currentY = (bottomBound - 16.0).clamp(topBound, bottomBound);
          }
        } else {
          _currentY = _currentY!.clamp(topBound, bottomBound);
        }

        _currentX ??= _isDockedOnRight ? rightBound : leftBound;

        final double currentYClamped = (_currentY ?? bottomBound).clamp(topBound, bottomBound);
        final double currentXClamped = (_currentX ?? rightBound).clamp(leftBound, rightBound);

        Widget interactiveChild;
        if (_isDockedTab) {
          interactiveChild = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _expandFromTab,
            onPanUpdate: (details) {
              final pullingInward = _isDockedOnRight
                  ? details.delta.dx < -3.0
                  : details.delta.dx > 3.0;
              if (pullingInward) {
                _expandFromTab();
              }
            },
            child: _buildEdgeTab(),
          );
        } else {
          interactiveChild = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              final newX = ((_currentX ?? rightBound) + details.delta.dx)
                  .clamp(leftBound, rightBound);
              final newY = ((_currentY ?? bottomBound) + details.delta.dy)
                  .clamp(topBound, bottomBound);
              setState(() {
                _currentX = newX;
                _currentY = newY;
              });
            },
            onPanEnd: (details) {
              _isDragging = false;
              _snapToNearestEdge(
                width,
                height,
                leftBound,
                rightBound,
                topBound,
                bottomBound,
              );
            },
            onTap: widget.onTap,
            onLongPress: () => _showLongPressMenu(
              context,
              width,
              height,
              currentXClamped,
              currentYClamped,
            ),
            child: _buildRoundButton(),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _isDockedTab
                  ? (_isDockedOnRight ? null : 0.0)
                  : currentXClamped,
              right: _isDockedTab && _isDockedOnRight ? 0.0 : null,
              top: currentYClamped,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.isScrolling ? 0.5 : 1.0,
                child: interactiveChild,
              ),
            ),
          ],
        );
      },
    );
  }
}
