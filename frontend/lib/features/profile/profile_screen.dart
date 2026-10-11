import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/language_picker.dart';
import '../../data/repositories/auth_repository.dart';
import 'developer_settings_dialog.dart';

/// KalaSetu Profile Screen
/// Visual Layout Matching Reference:
/// 1. Card with avatar, name, phone, craft chip
/// 2. Simple Mode controls and specialized hub actions
/// 3. Collapsible "More options" for advanced and developer settings
/// 4. Red outlined Sign Out button
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepo = AuthRepository();
  bool _showMoreOptions = false;

  void _showHandoverDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'handover_account_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'handover_account_msg'.tr(),
          style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await StorageService.clearAssistedHelper();
              if (mounted) {
                SimpleModeVoiceHelper.playSuccessFeedback(context, 'handover_success_spoken'.tr());
                setState(() {});
              }
            },
            child: Text('handover_confirm_btn'.tr()),
          ),
        ],
      ),
    );
  }

  void _openLanguagePicker() async {
    final currentCode = context.locale.languageCode;
    final selected = await LanguagePicker.showBottomSheet(
      context: context,
      currentCode: currentCode,
    );
    if (selected != null && mounted) {
      final newLocale = Locale(selected.code);
      await context.setLocale(newLocale);
      await StorageService.saveLocale(newLocale);
      VoiceService.instance.prefetchFixedPhrases(selected.code);
      setState(() {});
    }
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.school_outlined, color: AppColors.craftOchre, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'tutorial_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'tutorial_body'.tr(),
          style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('dialog_ok'.tr(), style: AppTextStyles.labelMedium(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.support_agent_outlined, color: AppColors.accentBlue, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'help_support_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'help_support_body'.tr(),
          style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('dialog_ok'.tr(), style: AppTextStyles.labelMedium(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'about_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'about_body'.tr(),
              style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.hairline),
            // Quick Developer settings link
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.developer_mode_rounded, color: AppColors.craftOchre, size: 20),
              title: Text('developer_settings_title'.tr(), style: AppTextStyles.bodySmall()),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.inkSecondary),
              onTap: () async {
                Navigator.of(ctx).pop();
                await DeveloperSettingsDialog.show(context);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('dialog_ok'.tr(), style: AppTextStyles.labelMedium(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('sign_out_confirm_title'.tr(), style: AppTextStyles.titleMedium()),
        content: Text('sign_out_confirm_msg'.tr(), style: AppTextStyles.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _authRepo.signOut();
              if (!mounted) return;
              context.go(RouteNames.authPhone);
            },
            child: Text('sign_out'.tr(), style: AppTextStyles.labelMedium(color: AppColors.statusError)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRole() async {
    final newRole = StorageService.isBuyer ? 'artisan' : 'buyer';
    await StorageService.setUserRole(newRole);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = StorageService.isBuyer;
    final displayName = isBuyer
        ? (StorageService.buyerName?.isNotEmpty == true ? StorageService.buyerName! : 'KalaSetu Buyer')
        : (StorageService.artisanName?.isNotEmpty == true ? StorageService.artisanName! : 'KalaSetu Artisan');
    final craftType = StorageService.craftType?.isNotEmpty == true
        ? StorageService.craftType!
        : 'profile_craft_chip'.tr();
    final phone = StorageService.artisanPhone ?? '9876543210';
    final currentLangCode = context.locale.languageCode;
    final currentLang = kSupportedLanguages.firstWhere(
      (l) => l.code == currentLangCode,
      orElse: () => kSupportedLanguages.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Profile Header Card: Avatar, Name, Phone, Role/Craft Chip
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isBuyer ? AppColors.accentBlue.withValues(alpha: 0.15) : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : (isBuyer ? 'B' : 'A'),
                      style: AppTextStyles.displaySmall(
                        color: isBuyer ? AppColors.accentBlue : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Name, Phone, Role/Craft Chip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.titleMedium(color: AppColors.inkPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+91 $phone',
                        style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                      ),
                      const SizedBox(height: 8),
                      // Role / Craft Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBuyer ? AppColors.primaryLight.withValues(alpha: 0.5) : AppColors.secondaryLight,
                          borderRadius: AppRadii.pillRadius,
                          border: Border.all(
                            color: isBuyer
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.secondary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBuyer ? Icons.shopping_bag_outlined : Icons.palette_outlined,
                              size: 14,
                              color: isBuyer ? AppColors.primary : AppColors.craftOchre,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isBuyer ? 'role_buyer'.tr() : craftType,
                                style: AppTextStyles.labelSmall(
                                  color: isBuyer ? AppColors.primary : AppColors.craftOchre,
                                ).copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assisted Mode Badge (If account was onboarded by an NGO/cluster helper)
          if (!isBuyer && StorageService.isAssisted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volunteer_activism_rounded, color: AppColors.craftTerracotta, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'assisted_mode_title'.tr(),
                          style: AppTextStyles.titleMedium(color: AppColors.craftTerracotta).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'assisted_by'.tr()}: ${StorageService.assistedBy} (${'helper_code_label'.tr()}: ${StorageService.helperCode})',
                    style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                      ),
                      icon: const Icon(Icons.handshake_rounded, size: 18),
                      label: Text('handover_account_title'.tr(), style: AppTextStyles.labelMedium(color: Colors.white)),
                      onPressed: _showHandoverDialog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Simple Mode Settings Card (Simple Mode, Auto-Speak, Large Text)
          if (!isBuyer) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    secondary: const Icon(Icons.accessibility_new_rounded, color: AppColors.primary, size: 28),
                    title: Text(
                      'simple_mode_title'.tr(),
                      style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'simple_mode_desc'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                    value: StorageService.isSimpleMode,
                    onChanged: (val) async {
                      await StorageService.setSimpleMode(val);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.hairline),
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    secondary: const Icon(Icons.volume_up_rounded, color: AppColors.craftOchre, size: 24),
                    title: Text(
                      'auto_speak_title'.tr(),
                      style: AppTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                    ),
                    value: StorageService.isAutoSpeakEnabled,
                    onChanged: (val) async {
                      await StorageService.setAutoSpeakEnabled(val);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.hairline),
                  SwitchListTile(
                    activeColor: AppColors.primary,
                    secondary: const Icon(Icons.format_size_rounded, color: AppColors.craftIndigo, size: 24),
                    title: Text(
                      'large_text_title'.tr(),
                      style: AppTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600),
                    ),
                    value: StorageService.isLargeTextEnabled,
                    onChanged: (val) async {
                      await StorageService.setLargeTextEnabled(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Simple Mode Quick Hub: My Earnings, Fair Mode, Business Orders, Marketplaces
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.secondaryLight, shape: BoxShape.circle),
                      child: const Icon(Icons.currency_rupee_rounded, color: AppColors.craftTerracotta, size: 22),
                    ),
                    title: Text('my_earnings_title'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('earnings_spoken_summary'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.inkSecondary),
                    onTap: () => context.push('/earnings'),
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.hairline),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.craftOchre.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.festival_rounded, color: AppColors.craftOchre, size: 22),
                    ),
                    title: Text('fair_mode_title'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('fair_mode_fast_add_desc'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.inkSecondary),
                    onTap: () => context.push('/fair-mode'),
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.hairline),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.craftIndigo.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.business_center_rounded, color: AppColors.craftIndigo, size: 22),
                    ),
                    title: Text('business_orders_title'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('business_inbox_instruction'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.inkSecondary),
                    onTap: () => context.push('/orders/business'),
                  ),
                  const Divider(height: 1, indent: 64, color: AppColors.hairline),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: const Icon(Icons.hub_rounded, color: AppColors.primary, size: 22),
                    ),
                    title: Text('connect_marketplaces_title'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('honest_marketplace_notice'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.inkSecondary),
                    onTap: () => context.push('/marketplaces'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. General Settings: Language Picker & More Options
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                // Language Settings
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52.0),
                  child: ListTile(
                    leading: const Icon(Icons.language, color: AppColors.primary),
                    title: Text('profile_nav_language'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      currentLang.nativeName,
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                    onTap: _openLanguagePicker,
                  ),
                ),

                // Collapsible More Options Header
                const Divider(height: 1, indent: 56, color: AppColors.hairline),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52.0),
                  child: ListTile(
                    leading: const Icon(Icons.tune_rounded, color: AppColors.inkSecondary),
                    title: Text('more_options_title'.tr(), style: AppTextStyles.bodyLarge().copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('more_options_sub'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: Icon(_showMoreOptions ? Icons.expand_less : Icons.expand_more, color: AppColors.inkSecondary),
                    onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
                  ),
                ),

                // Expanded Section: Role Switcher, Full Analytics, Assistant Reset, Tutorial, Help, About
                if (_showMoreOptions) ...[
                  const Divider(height: 1, indent: 56, color: AppColors.hairline),
                  ListTile(
                    leading: Icon(
                      isBuyer ? Icons.storefront_rounded : Icons.shopping_bag_rounded,
                      color: AppColors.craftOchre,
                    ),
                    title: Text(
                      isBuyer ? 'switch_to_artisan_mode'.tr() : 'switch_to_buyer_mode'.tr(),
                      style: AppTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isBuyer ? 'role_seller_sub'.tr() : 'role_buyer_sub'.tr(),
                      style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    ),
                    trailing: const Icon(Icons.swap_horiz_rounded, size: 22, color: AppColors.primary),
                    onTap: _toggleRole,
                  ),
                  if (!isBuyer) ...[
                    const Divider(height: 1, indent: 56, color: AppColors.hairline),
                    ListTile(
                      leading: const Icon(Icons.bar_chart_rounded, color: AppColors.craftIndigo),
                      title: Text('profile_nav_analytics'.tr(), style: AppTextStyles.bodyMedium()),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                      onTap: () => context.push('/analytics'),
                    ),
                    const Divider(height: 1, indent: 56, color: AppColors.hairline),
                    ListTile(
                      leading: const Icon(Icons.smart_toy_outlined, color: AppColors.accentBlue),
                      title: Text('kalamitra_assistant'.tr(), style: AppTextStyles.bodyMedium()),
                      subtitle: Text(
                        'kalamitra_reset_hint'.tr(),
                        style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await StorageService.resetKalaMitraPosition();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('kalamitra_position_reset'.tr()),
                                backgroundColor: AppColors.statusOnline,
                              ),
                            );
                          }
                        },
                        child: Text('reset_btn'.tr(), style: AppTextStyles.labelMedium(color: AppColors.primary)),
                      ),
                    ),
                  ],
                  const Divider(height: 1, indent: 56, color: AppColors.hairline),
                  ListTile(
                    leading: const Icon(Icons.school_outlined, color: AppColors.craftOchre),
                    title: Text('profile_nav_tutorial'.tr(), style: AppTextStyles.bodyMedium()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                    onTap: _showTutorialDialog,
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.hairline),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined, color: AppColors.accentBlue),
                    title: Text('profile_nav_help_support'.tr(), style: AppTextStyles.bodyMedium()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                    onTap: _showHelpDialog,
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.hairline),
                  ListTile(
                    leading: const Icon(Icons.developer_mode_rounded, color: AppColors.craftOchre),
                    title: Text('developer_settings_title'.tr(), style: AppTextStyles.bodyMedium()),
                    subtitle: Text('developer_settings_desc'.tr(), style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                    onTap: () => DeveloperSettingsDialog.show(context),
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.hairline),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.inkSecondary),
                    title: Text('profile_nav_about'.tr(), style: AppTextStyles.bodyMedium()),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.inkSecondary),
                    onTap: _showAboutDialog,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Sign Out Button
          Container(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                side: const BorderSide(color: AppColors.statusError, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                backgroundColor: AppColors.statusError.withValues(alpha: 0.03),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.statusError),
              label: Text(
                'sign_out'.tr(),
                style: AppTextStyles.labelLarge(color: AppColors.statusError).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _handleSignOut,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
