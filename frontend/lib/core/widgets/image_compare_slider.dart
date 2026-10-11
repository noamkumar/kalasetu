import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Before/After Image Comparison Slider
/// Interactive drag slider comparing original and AI-enhanced photos
/// Section 5.5 of Project Specification
class ImageCompareSlider extends StatefulWidget {
  final Widget beforeWidget;
  final Widget afterWidget;
  final double initialPosition; // 0.0 to 1.0 (defaults to 0.5)
  final double height;
  final String beforeLabel;
  final String afterLabel;

  const ImageCompareSlider({
    super.key,
    required this.beforeWidget,
    required this.afterWidget,
    this.initialPosition = 0.5,
    this.height = 320.0,
    this.beforeLabel = 'Original',
    this.afterLabel = 'AI Enhanced',
  });

  @override
  State<ImageCompareSlider> createState() => _ImageCompareSliderState();
}

class _ImageCompareSliderState extends State<ImageCompareSlider> {
  late double _dividerPosition;

  @override
  void initState() {
    super.initState();
    _dividerPosition = widget.initialPosition.clamp(0.05, 0.95);
  }

  void _updatePosition(double globalDx, double width) {
    setState(() {
      _dividerPosition = (globalDx / width).clamp(0.05, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: AppElevation.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final splitX = width * _dividerPosition;

          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              _updatePosition(details.localPosition.dx, width);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. After (Enhanced) Image - Full width behind
                widget.afterWidget,

                // 2. Before (Original) Image - Clipped to split position
                ClipRect(
                  clipper: _RectSliderClipper(splitX),
                  child: widget.beforeWidget,
                ),

                // 3. Before Label Pill (Top Left)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: Text(
                      widget.beforeLabel,
                      style: AppTextStyles.labelSmall(color: Colors.white),
                    ),
                  ),
                ),

                // 4. After Label Pill (Top Right)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: Text(
                      widget.afterLabel,
                      style: AppTextStyles.labelSmall(color: Colors.white),
                    ),
                  ),
                ),

                // 5. Divider Line
                Positioned(
                  left: splitX - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.0,
                    color: Colors.white,
                  ),
                ),

                // 6. Center Drag Handle Thumb
                Positioned(
                  left: splitX - 18,
                  top: (widget.height / 2) - 18,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_left, size: 16, color: AppColors.inkPrimary),
                          Icon(Icons.arrow_right, size: 16, color: AppColors.inkPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RectSliderClipper extends CustomClipper<Rect> {
  final double width;

  _RectSliderClipper(this.width);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, width, size.height);
  }

  @override
  bool shouldReclip(covariant _RectSliderClipper oldClipper) =>
      oldClipper.width != width;
}
