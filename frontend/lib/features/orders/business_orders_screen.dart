import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/speaker_affordance.dart';

class BusinessInquiry {
  final String id;
  final String buyerName;
  final String businessType;
  final String craftName;
  final int quantity;
  final int unitPrice;
  final String buyerPhone;
  String status; // 'pending', 'accepted', 'called', 'declined'

  BusinessInquiry({
    required this.id,
    required this.buyerName,
    required this.businessType,
    required this.craftName,
    required this.quantity,
    required this.unitPrice,
    required this.buyerPhone,
    this.status = 'pending',
  });

  int get totalAmount => quantity * unitPrice;
}

/// Simple Business Orders Inbox for bulk inquiries from B2B buyers
/// Requirement 13: Big Accept / Call Back / Not Now buttons,
/// quantity and price offered shown with icons and spoken aloud.
class BusinessOrdersScreen extends StatefulWidget {
  const BusinessOrdersScreen({super.key});

  @override
  State<BusinessOrdersScreen> createState() => _BusinessOrdersScreenState();
}

class _BusinessOrdersScreenState extends State<BusinessOrdersScreen> {
  final List<BusinessInquiry> _inquiries = [
    BusinessInquiry(
      id: 'biz_01',
      buyerName: 'Dilli Haat Crafts Emporium',
      businessType: 'Retail Emporium',
      craftName: 'Terracotta Tea Kulhar Sets',
      quantity: 50,
      unitPrice: 380,
      buyerPhone: '+919876543210',
    ),
    BusinessInquiry(
      id: 'biz_02',
      buyerName: 'Heritage Palace Hotel, Jaipur',
      businessType: 'Boutique Hotel',
      craftName: 'Hand-Carved Wooden Table Lamps',
      quantity: 25,
      unitPrice: 1250,
      buyerPhone: '+919811122233',
    ),
    BusinessInquiry(
      id: 'biz_03',
      buyerName: 'Gramin FabIndia Partner Store',
      businessType: 'Craft Cooperative',
      craftName: 'Handloom Cotton Stoles',
      quantity: 100,
      unitPrice: 420,
      buyerPhone: '+919844455566',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'business_inbox_instruction'.tr(),
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

  void _speakInquiry(BusinessInquiry item) {
    final lang = _safeLang(context);
    final text = 'business_inquiry_spoken'.tr(args: [
      item.buyerName,
      '${item.quantity}',
      item.craftName,
      '${item.unitPrice}',
      '${item.totalAmount}',
    ]);
    VoiceService.instance.speak(text: text, languageCode: lang);
  }

  void _acceptInquiry(BusinessInquiry item) {
    HapticFeedback.mediumImpact();
    setState(() => item.status = 'accepted');
    SimpleModeVoiceHelper.playSuccessFeedback(
      context,
      'bulk_order_accepted_spoken'.tr(args: [item.buyerName]),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('bulk_order_accepted_msg'.tr(args: [item.buyerName])),
        backgroundColor: AppColors.statusOnline,
      ),
    );
  }

  void _callBuyer(BusinessInquiry item) {
    HapticFeedback.lightImpact();
    setState(() => item.status = 'called');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('call_buyer_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'buyer_label'.tr()}: ${item.buyerName}'),
            const SizedBox(height: 8),
            Text('${'phone_label'.tr()}: ${item.buyerPhone}', style: AppTextStyles.titleMedium()),
            const SizedBox(height: 12),
            Text('call_buyer_hint'.tr(), style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
            label: Text('call_now'.tr()),
          ),
        ],
      ),
    );
  }

  void _declineInquiry(BusinessInquiry item) {
    HapticFeedback.lightImpact();
    setState(() => item.status = 'declined');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('inquiry_postponed'.tr()),
        backgroundColor: AppColors.inkSecondary,
      ),
    );
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
          'business_orders_title'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SpeakerAffordance(
              textToSpeak: 'business_inbox_instruction'.tr(),
              languageCode: lang,
              label: 'listen_instruction'.tr(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          itemCount: _inquiries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final item = _inquiries[index];
            final isAccepted = item.status == 'accepted';
            final isDeclined = item.status == 'declined';

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: isAccepted ? AppColors.statusOnline : AppColors.hairline,
                  width: isAccepted ? 2 : 1,
                ),
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
                  // Buyer Name & Badge & Speaker Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.buyerName,
                              style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.businessType,
                                style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 28),
                        tooltip: 'read_aloud'.tr(),
                        onPressed: () => _speakInquiry(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Craft Item Name
                  Text(
                    item.craftName,
                    style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 14),

                  // Big Quantity and Price Metrics
                  Row(
                    children: [
                      // Quantity
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadii.inputRadius,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded, color: AppColors.secondary, size: 24),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('quantity'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkSecondary)),
                                  Text(
                                    '${item.quantity} pcs',
                                    style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Price Offered
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: AppRadii.inputRadius,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: AppColors.craftTerracotta, size: 24),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('total_offer'.tr(), style: AppTextStyles.labelSmall(color: AppColors.inkSecondary)),
                                  Text(
                                    '₹${item.totalAmount}',
                                    style: AppTextStyles.titleMedium(color: AppColors.craftTerracotta).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (isAccepted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Center(
                        child: Text(
                          'bulk_order_accepted'.tr(),
                          style: AppTextStyles.labelLarge(color: AppColors.statusOnline).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else if (isDeclined)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Center(
                        child: Text(
                          'postponed_for_now'.tr(),
                          style: AppTextStyles.labelMedium(color: AppColors.inkSecondary),
                        ),
                      ),
                    )
                  else
                    // Three Big Action Buttons: Accept / Call Back / Not Now
                    Column(
                      children: [
                        Row(
                          children: [
                            // Accept (56 dp)
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.statusOnline,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                                    elevation: 2,
                                  ),
                                  onPressed: () => _acceptInquiry(item),
                                  icon: const Icon(Icons.check_circle_rounded, size: 24),
                                  label: Text('accept_order_btn'.tr(), style: AppTextStyles.titleSmall(color: Colors.white)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Call Back (56 dp)
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                                    elevation: 2,
                                  ),
                                  onPressed: () => _callBuyer(item),
                                  icon: const Icon(Icons.phone_rounded, size: 20),
                                  label: Text('call_back_btn'.tr(), style: AppTextStyles.labelMedium(color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Not Now (52 dp)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            onPressed: () => _declineInquiry(item),
                            child: Text(
                              'not_now_btn'.tr(),
                              style: AppTextStyles.labelLarge(color: AppColors.inkSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
