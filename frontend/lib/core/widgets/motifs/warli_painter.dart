import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Warli Geometric Watermark Pattern
/// Traditional Indian folk art motif rendered as a subtle background watermark
class WarliWatermarkPainter extends CustomPainter {
  final Color color;
  final double opacity;

  const WarliWatermarkPainter({
    this.color = AppColors.primaryDark,
    this.opacity = 0.035,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Draw repeating subtle motifs across the canvas
    const spacingX = 140.0;
    const spacingY = 120.0;

    for (double x = 30; x < size.width; x += spacingX) {
      for (double y = 40; y < size.height; y += spacingY) {
        // Draw Warli figure (two touching triangles + head circle)
        _drawWarliFigure(canvas, paint, fillPaint, Offset(x, y));
        
        // Offset alternate motif: concentric spiral or craft motif
        if ((x + y).toInt() % 2 == 0) {
          _drawCraftPot(canvas, paint, Offset(x + 60, y + 50));
        }
      }
    }
  }

  void _drawWarliFigure(Canvas canvas, Paint stroke, Paint fill, Offset center) {
    const scale = 0.8;
    // Head
    canvas.drawCircle(Offset(center.dx, center.dy - 20 * scale), 4.5 * scale, fill);

    // Torso (Upper triangle pointing down)
    final upperPath = Path()
      ..moveTo(center.dx - 10 * scale, center.dy - 14 * scale)
      ..lineTo(center.dx + 10 * scale, center.dy - 14 * scale)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(upperPath, fill);

    // Pelvis (Lower triangle pointing up)
    final lowerPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - 10 * scale, center.dy + 14 * scale)
      ..lineTo(center.dx + 10 * scale, center.dy + 14 * scale)
      ..close();
    canvas.drawPath(lowerPath, fill);

    // Legs
    canvas.drawLine(Offset(center.dx - 6 * scale, center.dy + 14 * scale),
        Offset(center.dx - 12 * scale, center.dy + 26 * scale), stroke);
    canvas.drawLine(Offset(center.dx + 6 * scale, center.dy + 14 * scale),
        Offset(center.dx + 12 * scale, center.dy + 26 * scale), stroke);

    // Arms
    canvas.drawLine(Offset(center.dx - 8 * scale, center.dy - 10 * scale),
        Offset(center.dx - 16 * scale, center.dy - 2 * scale), stroke);
    canvas.drawLine(Offset(center.dx + 8 * scale, center.dy - 10 * scale),
        Offset(center.dx + 16 * scale, center.dy - 2 * scale), stroke);
  }

  void _drawCraftPot(Canvas canvas, Paint stroke, Offset center) {
    // Elegant terracotta urn silhouette
    final path = Path()
      ..moveTo(center.dx - 8, center.dy - 10)
      ..lineTo(center.dx + 8, center.dy - 10)
      ..quadraticBezierTo(center.dx + 16, center.dy, center.dx + 8, center.dy + 12)
      ..lineTo(center.dx - 8, center.dy + 12)
      ..quadraticBezierTo(center.dx - 16, center.dy, center.dx - 8, center.dy - 10);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant WarliWatermarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
