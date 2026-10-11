import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'speaker_affordance.dart';

class PriceFactor {
  final String name;
  final String value;

  const PriceFactor({required this.name, required this.value});
}

class ComparableItem {
  final String title;
  final int price;
  final double similarity;

  const ComparableItem({
    required this.title,
    required this.price,
    required this.similarity,
  });
}

/// KalaSetu Price Suggestion Card
/// Displays AI recommended price, range, confidence, breakdown, comparables, and speaker button
/// Section 5.5 and Section 9 of Project Specification
class PriceSuggestionCard extends StatelessWidget {
  final int recommendedPrice;
  final int floorPrice;
  final int budgetPrice;
  final int premiumPrice;
  final double confidence;
  final String? statusLabel;
  final String? evidenceLevel;
  final String? impactMessage;
  final String explanation;
  final List<PriceFactor> factors;
  final List<ComparableItem> comparables;
  final bool isBelowFloor;
  final bool? isSpeaking;
  final ValueChanged<int>? onSelectPrice;
  final VoidCallback? onAccept;
  final VoidCallback? onEdit;
  final VoidCallback? onSpeak;

  const PriceSuggestionCard({
    super.key,
    required this.recommendedPrice,
    required this.floorPrice,
    required this.budgetPrice,
    required this.premiumPrice,
    this.confidence = 0.85,
    this.statusLabel,
    this.evidenceLevel,
    this.impactMessage,
    required this.explanation,
    this.factors = const [],
    this.comparables = const [],
    this.isBelowFloor = false,
    this.isSpeaking,
    this.onSelectPrice,
    this.onAccept,
    this.onEdit,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isEstimate = (statusLabel != null && statusLabel!.contains('Estimate')) || (evidenceLevel == 'thin');

    return Container(
      decoration: AppElevation.cardDecoration(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Confidence Badge & Speaker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEstimate ? AppColors.craftOchre.withValues(alpha: 0.18) : AppColors.primaryLight,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEstimate ? Icons.info_outline_rounded : Icons.bolt,
                        size: 14,
                        color: isEstimate ? AppColors.craftOchre : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isEstimate ? 'Estimate (${(confidence * 100).toInt()}%)' : 'AI Price (${(confidence * 100).toInt()}% conf)',
                          style: AppTextStyles.labelSmall(
                            color: isEstimate ? AppColors.craftOchre : AppColors.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpeakerAffordance(
                isCompact: true,
                textToSpeak: explanation,
                isPlaying: isSpeaking,
                onTap: onSpeak,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Recommended Price
          Text(
            'Recommended Price',
            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '₹$recommendedPrice',
                style: AppTextStyles.displayLarge(color: AppColors.inkPrimary).copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Fair Artisan Value',
                style: AppTextStyles.labelMedium(color: AppColors.primary),
              ),
            ],
          ),

          // Floor warning if applicable
          if (isBelowFloor) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.statusError.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.statusError, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This price is below your cost floor (₹$floorPrice).',
                      style: AppTextStyles.labelSmall(color: AppColors.statusError),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Budget / Premium Range Indicators (One-Tap Selection)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSelectPrice != null ? () => onSelectPrice!(budgetPrice) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _buildRangeCol('Budget', '₹$budgetPrice', AppColors.inkSecondary),
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.hairline),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSelectPrice != null ? () => onSelectPrice!(recommendedPrice) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _buildRangeCol('Recommended', '₹$recommendedPrice', AppColors.primary),
                    ),
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.hairline),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onSelectPrice != null ? () => onSelectPrice!(premiumPrice) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _buildRangeCol('Premium', '₹$premiumPrice', AppColors.craftOchre),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Simple 'Fair Price for Your Work' Impact Message
          if (impactMessage != null && impactMessage!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.handshake_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      impactMessage!,
                      style: AppTextStyles.bodySmall(color: AppColors.inkPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Plain-Language Spoken Explanation
          Text(
            'Why this price?',
            style: AppTextStyles.titleSmall(),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
          ),

          // Cost Breakdown factors
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Cost & Market Breakdown',
              style: AppTextStyles.titleSmall(),
            ),
            const SizedBox(height: 8),
            ...factors.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Expanded(child: Text(f.name, style: AppTextStyles.bodySmall(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(
                      f.value,
                      style: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Comparables
          if (comparables.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Market Comparables',
              style: AppTextStyles.titleSmall(),
            ),
            const SizedBox(height: 8),
            ...comparables.map(
              (c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: AppTextStyles.bodySmall(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${c.price}',
                      style: AppTextStyles.labelSmall(color: AppColors.inkPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Actions
          if (onAccept != null || onEdit != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onEdit != null)
                  SizedBox(
                    width: 105,
                    child: AppButton(
                      label: 'Adjust',
                      variant: AppButtonVariant.outlined,
                      onPressed: onEdit,
                      isFullWidth: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                if (onAccept != null)
                  SizedBox(
                    width: 135,
                    child: AppButton(
                      label: 'Accept Price',
                      variant: AppButtonVariant.primary,
                      onPressed: onAccept,
                      isFullWidth: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeCol(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.titleSmall(color: color).copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
