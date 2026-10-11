import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/local_db/app_database.dart';
import 'adapters/marketplace_adapter.dart';

/// Marketplace Connection Screen
/// Requirement 14: Honest placeholder behind MarketplaceAdapter (GeM & ONDC).
/// Produces a ready-to-submit listing export. Shows "Coming soon" status.
class MarketplaceConnectScreen extends StatefulWidget {
  const MarketplaceConnectScreen({super.key});

  @override
  State<MarketplaceConnectScreen> createState() => _MarketplaceConnectScreenState();
}

class _MarketplaceConnectScreenState extends State<MarketplaceConnectScreen> {
  final GeMMarketplaceAdapter _gemAdapter = GeMMarketplaceAdapter();
  final ONDCMarketplaceAdapter _ondcAdapter = ONDCMarketplaceAdapter();
  final AppDatabase _db = AppDatabase();

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'marketplace_connect_instruction'.tr(),
      );
    });
  }

  Future<void> _generateExport(MarketplaceAdapter adapter) async {
    setState(() => _isGenerating = true);

    try {
      final products = await _db.getAllProducts();
      final product = products.isNotEmpty
          ? products.first
          : LocalProduct(
              id: 'demo_01',
              artisanId: StorageService.artisanId ?? 'artisan_demo',
              category: 'Pottery',
              price: 450.0,
              costPrice: 200.0,
              status: 'live',
              stockQuantity: 10,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      final translations = await _db.getTranslationsForProduct(product.id);

      final package = await adapter.prepareExport(
        product: product,
        translations: translations,
        artisanName: StorageService.artisanName ?? 'Master Artisan',
        clusterLocation: StorageService.deliveryAddress.isNotEmpty
            ? StorageService.deliveryAddress
            : 'Kumhar Gram, Delhi',
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        SimpleModeVoiceHelper.playSuccessFeedback(
          context,
          'export_prepared_spoken'.tr(args: [adapter.marketplaceName]),
        );

        _showExportDialog(package);
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showExportDialog(MarketplaceExportPackage package) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.inventory_rounded, color: AppColors.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${package.marketplace} Listing Export',
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text(
                  'ready_to_submit_badge'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 12),
              Text('${'english_title'.tr()}: ${package.titleEn}', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 4),
              Text('${'hindi_title'.tr()}: ${package.titleHi}', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 8),
              Text('HSN Code: ${package.hsnCode}', style: AppTextStyles.bodyMedium()),
              Text('Price: ₹${package.price}', style: AppTextStyles.bodyMedium(color: AppColors.craftTerracotta)),
              const SizedBox(height: 14),
              Text('JSON Package Payload:', style: AppTextStyles.labelSmall(color: AppColors.inkSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  package.toFormattedJson(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('close'.tr()),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: package.toFormattedJson()));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('export_copied_clipboard'.tr()),
                  backgroundColor: AppColors.statusOnline,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text('copy_export'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCard(MarketplaceAdapter adapter) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  adapter.marketplaceName,
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: AppRadii.pillRadius,
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'coming_soon'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.secondary).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            adapter.portalDescription,
            style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    adapter.statusNote,
                    style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              ),
              onPressed: _isGenerating ? null : () => _generateExport(adapter),
              icon: const Icon(Icons.file_download_outlined, size: 22),
              label: Text(
                'generate_ready_export'.tr(),
                style: AppTextStyles.titleSmall(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeLang(BuildContext context) {
    try {
      return context.locale.languageCode;
    } catch (_) {
      return Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _safeLang(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkPrimary),
          onPressed: () => context.go(RouteNames.home),
        ),
        title: Text(
          'connect_marketplaces_title'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SpeakerAffordance(
              textToSpeak: 'marketplace_connect_instruction'.tr(),
              languageCode: lang,
              label: 'listen_instruction'.tr(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.primaryDark, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'honest_marketplace_notice'.tr(),
                        style: AppTextStyles.bodyMedium(color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // GeM Card
              _buildPortalCard(_gemAdapter),
              const SizedBox(height: 20),

              // ONDC Card
              _buildPortalCard(_ondcAdapter),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
