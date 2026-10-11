import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

/// KalaSetu Empty Craft State
/// Features a handcrafted line-art potter's wheel illustration, title, subtitle, and action button
/// Section 5.5 of Project Specification
class EmptyCraftState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onAction;

  const EmptyCraftState({
    super.key,
    this.title = 'No Products Yet',
    this.subtitle = 'Start by adding your first craft product to reach more customers.',
    this.buttonLabel = 'Add First Craft',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom Line-art Potter's Wheel Illustration
            const SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: PottersWheelLineArtPainter(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.displaySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                subtitle,
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (buttonLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220, minWidth: 160),
                child: AppButton(
                  label: buttonLabel!,
                  onPressed: onAction,
                  isFullWidth: false,
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Handcrafted minimalist line-art potter's wheel illustration
class PottersWheelLineArtPainter extends CustomPainter {
  const PottersWheelLineArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillClayPaint = Paint()
      ..color = AppColors.craftTerracotta.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Wheel base ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 38), width: 96, height: 26),
      strokePaint,
    );
    // Inner wheel disc
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 38), width: 60, height: 16),
      strokePaint..strokeWidth = 1.2,
    );
    // Wheel shaft
    canvas.drawLine(Offset(cx, cy + 38), Offset(cx, cy + 54), strokePaint);

    // Clay Pot on the wheel
    final potPath = Path()
      ..moveTo(cx - 16, cy + 28) // base left
      ..lineTo(cx + 16, cy + 28) // base right
      ..quadraticBezierTo(cx + 28, cy + 6, cx + 18, cy - 14) // right waist & belly
      ..quadraticBezierTo(cx + 12, cy - 24, cx + 14, cy - 28) // neck
      ..lineTo(cx - 14, cy - 28) // rim
      ..quadraticBezierTo(cx - 12, cy - 24, cx - 18, cy - 14) // left neck
      ..quadraticBezierTo(cx - 28, cy + 6, cx - 16, cy + 28) // left waist & belly
      ..close();

    canvas.drawPath(potPath, fillClayPaint);
    canvas.drawPath(potPath, accentPaint);

    // Clay Rim ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 28), width: 28, height: 8),
      accentPaint,
    );

    // Artisan Hands subtle line contours shaping clay
    final leftHand = Path()
      ..moveTo(cx - 40, cy + 4)
      ..quadraticBezierTo(cx - 30, cy - 2, cx - 22, cy - 6);
    canvas.drawPath(leftHand, strokePaint..strokeWidth = 1.6);

    final rightHand = Path()
      ..moveTo(cx + 40, cy + 4)
      ..quadraticBezierTo(cx + 30, cy - 2, cx + 22, cy - 6);
    canvas.drawPath(rightHand, strokePaint);

    // Subtle motion / rotation arcs around wheel
    final arcRect = Rect.fromCenter(center: Offset(cx, cy + 38), width: 116, height: 34);
    canvas.drawArc(arcRect, 0.4, 0.8, false, strokePaint..strokeWidth = 1.0);
    canvas.drawArc(arcRect, math.pi + 0.4, 0.8, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
