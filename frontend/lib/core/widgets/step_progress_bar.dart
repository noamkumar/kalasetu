import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Icon Step Progress Bar
/// 5 steps joined by dashed Tanka-stitch craft lines:
/// 1. Photo (camera)
/// 2. Voice (mic)
/// 3. AI Review (auto_awesome)
/// 4. Price (currency_rupee)
/// 5. Publish (rocket_launch)
/// Fully responsive without overflow from 260px to tablet/desktop.
class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1-indexed (1 to 5)
  final int totalSteps;
  final List<String>? stepLabels;
  final List<IconData>? stepIcons;
  final ValueChanged<int>? onStepTapped;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 5,
    this.stepLabels,
    this.stepIcons,
    this.onStepTapped,
  });

  static const List<IconData> defaultIcons = [
    Icons.camera_alt_outlined,
    Icons.mic_outlined,
    Icons.auto_awesome_outlined,
    Icons.currency_rupee,
    Icons.rocket_launch_outlined,
  ];

  static const List<IconData> fourStepIcons = [
    Icons.camera_alt_rounded,
    Icons.edit_note_rounded,
    Icons.currency_rupee_rounded,
    Icons.rocket_launch_rounded,
  ];

  static List<String> get defaultLabels => [
    'step_photo'.tr(),
    'step_voice'.tr(),
    'step_ai_review'.tr(),
    'step_price'.tr(),
    'step_publish'.tr(),
  ];

  static List<String> get fourStepLabels => [
    'step_photo'.tr(),
    'step_details'.tr(),
    'step_price'.tr(),
    'step_publish'.tr(),
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveLabels = stepLabels ?? (totalSteps == 4 ? fourStepLabels : defaultLabels);
    final effectiveIcons = stepIcons ?? (totalSteps == 4 ? fourStepIcons : defaultIcons);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Dynamically compute node width so connecting lines and labels always fit
        final nodeWidth = totalSteps == 4
            ? ((availableWidth - 16) / totalSteps * 0.78).clamp(36.0, 64.0)
            : ((availableWidth - 16) / totalSteps * 0.72).clamp(32.0, 50.0);
        final circleSize = totalSteps == 4
            ? (availableWidth < 300 ? 30.0 : 36.0)
            : (availableWidth < 300 ? 26.0 : 30.0);
        final iconSize = totalSteps == 4
            ? (availableWidth < 300 ? 16.0 : 20.0)
            : (availableWidth < 300 ? 14.0 : 16.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: List.generate(totalSteps * 2 - 1, (index) {
              if (index.isEven) {
                final stepIndex = index ~/ 2 + 1;
                final isCompleted = stepIndex < currentStep;
                final isActive = stepIndex == currentStep;
                final label = stepIndex - 1 < effectiveLabels.length
                    ? effectiveLabels[stepIndex - 1]
                    : '';
                final icon = stepIndex - 1 < effectiveIcons.length
                    ? effectiveIcons[stepIndex - 1]
                    : Icons.circle;

                return _buildStepNode(
                  stepNumber: stepIndex,
                  isCompleted: isCompleted,
                  isActive: isActive,
                  icon: icon,
                  label: label,
                  nodeWidth: nodeWidth,
                  circleSize: circleSize,
                  iconSize: iconSize,
                );
              } else {
                final leftStep = index ~/ 2 + 1;
                final isLinePassed = leftStep < currentStep;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                    child: SizedBox(
                      height: 16,
                      child: CustomPaint(
                        painter: TankaStitchPainter(
                          color: isLinePassed
                              ? AppColors.primary
                              : AppColors.secondary.withValues(alpha: 0.5),
                          isSolid: isLinePassed,
                        ),
                      ),
                    ),
                  ),
                );
              }
            }),
          ),
        );
      },
    );
  }

  Widget _buildStepNode({
    required int stepNumber,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
    required String label,
    required double nodeWidth,
    required double circleSize,
    required double iconSize,
  }) {
    Color circleBg;
    Color circleFg;
    Border? border;

    if (isActive) {
      circleBg = AppColors.primary;
      circleFg = Colors.white;
    } else if (isCompleted) {
      circleBg = AppColors.primaryLight;
      circleFg = AppColors.primaryDark;
    } else {
      circleBg = AppColors.surface;
      circleFg = AppColors.inkSecondary;
      border = Border.all(color: AppColors.hairline, width: 1.5);
    }

    return GestureDetector(
      onTap: onStepTapped != null ? () => onStepTapped!(stepNumber) : null,
      child: SizedBox(
        width: nodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: border,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, size: iconSize, color: circleFg)
                    : Icon(icon, size: iconSize, color: circleFg),
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall(
                  color: isActive ? AppColors.primaryDark : AppColors.inkSecondary,
                ).copyWith(
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the dashed Tanka-stitch craft line
class TankaStitchPainter extends CustomPainter {
  final Color color;
  final bool isSolid;

  const TankaStitchPainter({
    required this.color,
    this.isSolid = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    if (isSolid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    // Dashed running stitch (Kantha / Tanka embroidery style)
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double currentX = 0;

    while (currentX < size.width) {
      final endX = (currentX + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(currentX, y), Offset(endX, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant TankaStitchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSolid != isSolid;
}
