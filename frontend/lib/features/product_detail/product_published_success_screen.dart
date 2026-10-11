import 'dart:io';
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
import '../../core/widgets/app_button.dart';
import '../../core/widgets/artisan_qr_code_widget.dart';
import '../../core/widgets/speaker_affordance.dart';

/// Year-Round Selling Screen
/// Shown immediately after a product is published:
/// "Your product is now in the shop for everyone to see",
/// with WhatsApp Share button and a printable/scannable QR code.
class ProductPublishedSuccessScreen extends StatefulWidget {
  final String productId;
  final String title;
  final int price;
  final String? imageUrl;

  const ProductPublishedSuccessScreen({
    super.key,
    required this.productId,
    required this.title,
    required this.price,
    this.imageUrl,
  });

  @override
  State<ProductPublishedSuccessScreen> createState() =>
      _ProductPublishedSuccessScreenState();
}

class _ProductPublishedSuccessScreenState
    extends State<ProductPublishedSuccessScreen> {
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'published_success_instruction'.tr(args: [widget.title]),
      );
    });
  }

  String _safeLang(BuildContext context) {
    try {
      return context.locale.languageCode;
    } catch (_) {
      return Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    }
  }

  String _buildShareMessage() {
    final lang = _safeLang(context);
    switch (lang) {
      case 'hi':
        return 'नमस्ते! मेरा नया हस्तशिल्प उत्पाद कलासेतु पर देखें: "${widget.title}" - केवल ₹${widget.price}। शिल्पकार से सीधे खरीदने के लिए संपर्क करें!';
      case 'ta':
        return 'வணக்கம்! கலாசேதுவில் எனது புதிய கைவினைப் பொருளைப் பாருங்கள்: "${widget.title}" - ₹${widget.price} மட்டுமே!';
      case 'te':
        return 'నమస్కారం! కలాసేతులో నా కొత్త హస్తకళా ఉత్పత్తిని చూడండి: "${widget.title}" - కేవలం ₹${widget.price}!';
      case 'kn':
        return 'ನಮಸ್ಕಾರ! ಕಲಾಸೇತುನಲ್ಲಿ ನನ್ನ ಹೊಸ ಕರಕುಶಲ ಉತ್ಪನ್ನವನ್ನು ನೋಡಿ: "${widget.title}" - ಕೇವಲ ₹${widget.price}!';
      case 'ml':
        return 'നമസ്കാരം! കലാസേതുവിൽ എന്റെ പുതിയ കരകൗശല ഉൽപ്പന്നം കാണുക: "${widget.title}" - വെറും ₹${widget.price}!';
      default:
        return 'Hello! Check out my authentic handcrafted craft on KalaSetu: "${widget.title}" for ₹${widget.price}. Handcrafted with care!';
    }
  }

  void _shareViaWhatsApp() {
    final text = _buildShareMessage();
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    setState(() => _copied = true);

    SimpleModeVoiceHelper.playSuccessFeedback(
      context,
      'share_copied_spoken'.tr(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('whatsapp_message_copied'.tr()),
        backgroundColor: AppColors.statusOnline,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _safeLang(context);
    final instruction = 'published_success_instruction'.tr(args: [widget.title]);
    final shareQrData = 'https://kalasetu.org/craft/${widget.productId}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'in_the_shop_title'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SpeakerAffordance(
              textToSpeak: instruction,
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
              // Celebratory Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.statusOnline,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'product_in_shop_heading'.tr(),
                      style: AppTextStyles.displaySmall(color: AppColors.inkPrimary)
                          .copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'anyone_can_see_now'.tr(),
                      style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Product Thumbnail & Details
                    Row(
                      children: [
                        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.imageUrl!.startsWith('http')
                                ? Image.network(
                                    widget.imageUrl!,
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(widget.imageUrl!),
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                  ),
                          )
                        else
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront_rounded,
                                color: AppColors.primary),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: AppTextStyles.titleMedium(
                                    color: AppColors.inkPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${widget.price}',
                                style: AppTextStyles.titleLarge(
                                        color: AppColors.craftTerracotta)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // WhatsApp Share Button (60 dp)
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.buttonRadius),
                    elevation: 2,
                  ),
                  onPressed: _shareViaWhatsApp,
                  icon: const Icon(Icons.share_rounded, size: 26),
                  label: Text(
                    _copied ? 'shared_copied'.tr() : 'share_on_whatsapp_btn'.tr(),
                    style: AppTextStyles.titleMedium(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Printable / Fair Stall QR Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Text(
                      'fair_qr_title'.tr(),
                      style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'fair_qr_desc'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ArtisanQrCodeWidget(
                      data: shareQrData,
                      size: 190,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'craft_id_label'.tr(args: [widget.productId.substring(0, widget.productId.length > 8 ? 8 : widget.productId.length)]),
                      style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Primary Actions
              AppButton(
                label: 'sell_another_product'.tr(),
                variant: AppButtonVariant.primary,
                minHeight: 58.0,
                onPressed: () {
                  if (StorageService.isSimpleMode) {
                    context.go('/add/simple');
                  } else {
                    context.go(RouteNames.addStudio);
                  }
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'go_to_my_shop'.tr(),
                variant: AppButtonVariant.outlined,
                minHeight: 56.0,
                onPressed: () => context.go('${RouteNames.home}?tab=1'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
