import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// KalaSetu Artisan Product Card
/// Visual style matching reference: Image with status badge overlay,
/// 2-line serif title, price, and Social Media Helper action.
class ArtisanCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? price;
  final double? rating;
  final int? ratingCount;
  final String? imageUrl;
  final Widget? imageWidget;
  final String? category;
  final String? status; // 'live', 'pending_sync', 'draft', 'sold_out'
  final VoidCallback? onTap;
  final VoidCallback? onSocialMediaHelperTap;
  final Widget? trailing;
  final bool isDense;

  const ArtisanCard({
    super.key,
    required this.title,
    this.subtitle,
    this.price,
    this.rating,
    this.ratingCount,
    this.imageUrl,
    this.imageWidget,
    this.category,
    this.status,
    this.onTap,
    this.onSocialMediaHelperTap,
    this.trailing,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppElevation.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Header with Status Badge Overlay
              _buildImageHeader(context),

              // Content Details
              Padding(
                padding: EdgeInsets.all(isDense ? 10.0 : 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null && category!.isNotEmpty) ...[
                      Text(
                        category!.toUpperCase(),
                        style: AppTextStyles.labelSmall(color: AppColors.primary).copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],

                    // 2-Line Serif Title
                    Text(
                      title,
                      style: AppTextStyles.serifCardTitle(color: AppColors.inkPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Price & Social Media Helper Action Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (price != null)
                          Expanded(
                            child: Text(
                              price!,
                              style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Social Media Helper Action
                        Semantics(
                          button: true,
                          label: 'social_media_helper'.tr(),
                          child: InkWell(
                            onTap: onSocialMediaHelperTap ??
                                () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('social_share_success'.tr()),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.craftOchre,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: AppTextStyles.labelSmall(color: AppColors.inkPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ratingCount != null) ...[
                            const SizedBox(width: 2),
                            Text(
                              '($ratingCount)',
                              style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],

                    if (trailing != null) ...[
                      const SizedBox(height: 4),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: Container(
              color: AppColors.secondaryLight.withValues(alpha: 0.6),
              child: imageWidget ?? _buildImageContent(),
            ),
          ),
        ),

        // Status Badge Overlay
        Positioned(
          top: 10,
          left: 10,
          child: _buildStatusBadge(),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final effectiveStatus = (status ?? 'live').toLowerCase();
    Color badgeColor;
    String badgeText;

    if (effectiveStatus.contains('pending')) {
      badgeColor = AppColors.statusSyncing;
      badgeText = 'status_pending_sync'.tr();
    } else if (effectiveStatus.contains('draft')) {
      badgeColor = AppColors.statusOffline;
      badgeText = 'status_draft'.tr();
    } else if (effectiveStatus.contains('sold')) {
      badgeColor = AppColors.craftTerracotta;
      badgeText = 'status_sold_out'.tr();
    } else if (effectiveStatus.contains('new')) {
      badgeColor = AppColors.secondary;
      badgeText = 'new_badge'.tr();
    } else {
      badgeColor = AppColors.statusOnline;
      badgeText = 'status_live'.tr();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholderIcon();
    }
    final url = imageUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
      );
    }
    if (url.startsWith('/static/')) {
      final fullUrl = ApiClient().resolveMediaUrl(url);
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
      );
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.palette_outlined,
          size: 26,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}
