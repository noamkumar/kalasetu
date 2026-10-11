import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum CraftCategory {
  all,
  pottery,
  handloom,
  jewelry,
  wood,
  bamboo,
}

extension CraftCategoryExtension on CraftCategory {
  String get label {
    switch (this) {
      case CraftCategory.all:
        return 'All';
      case CraftCategory.pottery:
        return 'Pottery';
      case CraftCategory.handloom:
        return 'Handloom';
      case CraftCategory.jewelry:
        return 'Jewelry';
      case CraftCategory.wood:
        return 'Wood Craft';
      case CraftCategory.bamboo:
        return 'Bamboo';
    }
  }

  IconData get icon {
    switch (this) {
      case CraftCategory.all:
        return Icons.auto_awesome;
      case CraftCategory.pottery:
        return Icons.coffee_maker_outlined; // Ceramic shape
      case CraftCategory.handloom:
        return Icons.texture;
      case CraftCategory.jewelry:
        return Icons.diamond_outlined;
      case CraftCategory.wood:
        return Icons.forest_outlined;
      case CraftCategory.bamboo:
        return Icons.eco_outlined;
    }
  }
}

/// KalaSetu Craft Category Badge / Chip
/// Section 5.5 of Project Specification
/// Chip with craft icon; selected state in sage (#606C56)
class CraftCategoryBadge extends StatelessWidget {
  final CraftCategory category;
  final bool isSelected;
  final ValueChanged<CraftCategory>? onSelected;
  final String? customLabel;

  const CraftCategoryBadge({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onSelected,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = customLabel ?? category.label;
    final bgColor = isSelected ? AppColors.primary : AppColors.surface;
    final fgColor = isSelected ? AppColors.surface : AppColors.inkPrimary;
    final borderColor = isSelected ? AppColors.primary : AppColors.hairline;

    return Material(
      color: bgColor,
      borderRadius: AppRadii.chipRadius,
      child: InkWell(
        onTap: onSelected != null ? () => onSelected!(category) : null,
        borderRadius: AppRadii.chipRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: AppRadii.chipRadius,
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelMedium(color: fgColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
