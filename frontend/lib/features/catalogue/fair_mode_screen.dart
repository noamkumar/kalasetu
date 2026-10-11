import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/artisan_qr_code_widget.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/local_db/app_database.dart';

/// Fair / Exhibition Mode Screen
/// Requirement 12: Quick "I am at a fair" mode:
/// - Lets the artisan add several products fast
/// - Keeps working 100% offline
/// - Shares one QR that opens their whole shop for visitors
class FairModeScreen extends StatefulWidget {
  const FairModeScreen({super.key});

  @override
  State<FairModeScreen> createState() => _FairModeScreenState();
}

class _FairModeScreenState extends State<FairModeScreen> {
  final ImagePicker _picker = ImagePicker();
  final AppDatabase _db = AppDatabase();

  int _fairAddedCount = 0;
  bool _isFastAdding = false;

  @override
  void initState() {
    super.initState();
    StorageService.setFairModeActive(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'fair_mode_instruction'.tr(),
      );
    });
  }

  Future<void> _fastAddProduct() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (photo == null || !mounted) return;

      // Ask for quick price in simple dialog
      final price = await _showQuickPriceDialog();
      if (price == null || !mounted) return;

      setState(() => _isFastAdding = true);

      final now = DateTime.now();
      final id = 'fair_${now.millisecondsSinceEpoch}';
      final category = StorageService.craftType ?? 'Craft';

      final localProd = LocalProduct(
        id: id,
        artisanId: StorageService.artisanId ?? 'artisan_local',
        category: category,
        price: price.toDouble(),
        costPrice: (price * 0.45),
        status: 'live',
        stockQuantity: 1,
        primaryImageUrl: photo.path,
        enhancedImageUrl: photo.path,
        createdAt: now,
        updatedAt: now,
      );

      final translation = LocalProductTranslation(
        id: 'fair_trans_${now.millisecondsSinceEpoch}',
        productId: id,
        languageCode: _safeLang(context),
        title: '$category Craft #$id',
        description: 'Authentic handmade craft added at exhibition stall.',
        tags: 'fair,stall,$category',
        materials: 'Natural materials',
        careInstructions: 'Handle with care',
      );

      await _db.upsertProduct(localProd);
      await _db.upsertTranslation(translation);

      if (mounted) {
        setState(() {
          _fairAddedCount++;
          _isFastAdding = false;
        });

        SimpleModeVoiceHelper.playSuccessFeedback(
          context,
          'product_saved_offline_spoken'.tr(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('product_saved_offline_msg'.tr()),
            backgroundColor: AppColors.statusOnline,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFastAdding = false);
      }
    }
  }

  Future<int?> _showQuickPriceDialog() async {
    int price = 400;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('quick_price_title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('set_stall_price'.tr(), style: AppTextStyles.bodyMedium()),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, size: 36, color: AppColors.primary),
                    onPressed: () {
                      if (price > 100) setDialogState(() => price -= 50);
                    },
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹$price',
                    style: AppTextStyles.displaySmall(color: AppColors.craftTerracotta).copyWith(fontSize: 36),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 36, color: AppColors.primary),
                    onPressed: () => setDialogState(() => price += 50),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(ctx).pop(price),
              child: Text('save_product'.tr()),
            ),
          ],
        ),
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
    final artisanId = StorageService.artisanId ?? 'artisan_stall';
    final shopQrUrl = 'https://kalasetu.org/shop/$artisanId';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.inkPrimary),
          onPressed: () {
            StorageService.setFairModeActive(false);
            context.go(RouteNames.home);
          },
        ),
        title: Text(
          'fair_mode_title'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SpeakerAffordance(
              textToSpeak: 'fair_mode_instruction'.tr(),
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
              // High Contrast Fair Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.secondary, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.festival_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'fair_active_badge'.tr(),
                            style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'fair_active_sub'.tr(),
                            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fast Add Product Button (64 dp)
              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                    elevation: 3,
                  ),
                  onPressed: _isFastAdding ? null : _fastAddProduct,
                  icon: const Icon(Icons.add_a_photo_rounded, size: 28),
                  label: Text(
                    'fast_add_product_btn'.tr(),
                    style: AppTextStyles.titleLarge(color: Colors.white),
                  ),
                ),
              ),

              if (_fairAddedCount > 0) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'added_at_fair_count'.tr(args: ['$_fairAddedCount']),
                    style: AppTextStyles.labelMedium(color: AppColors.statusOnline),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Whole Shop QR Code Container
              Container(
                padding: const EdgeInsets.all(22),
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
                  children: [
                    Text(
                      'my_whole_shop_qr'.tr(),
                      style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'show_qr_to_stall_visitors'.tr(),
                      style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ArtisanQrCodeWidget(
                      data: shopQrUrl,
                      size: 210,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'offline_ready_label'.tr(),
                            style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Exit Fair Mode Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: AppColors.hairline),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                ),
                onPressed: () {
                  StorageService.setFairModeActive(false);
                  context.go(RouteNames.home);
                },
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkPrimary),
                label: Text(
                  'exit_fair_mode'.tr(),
                  style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
