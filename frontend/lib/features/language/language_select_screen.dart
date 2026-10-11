import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/language_picker.dart';

class LanguageSelectScreen extends StatefulWidget {
  final bool isFromSettings;

  const LanguageSelectScreen({super.key, this.isFromSettings = false});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late String _selectedCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedCode = context.locale.languageCode;
  }

  Future<void> _onLanguageSelected(SupportedLanguage lang) async {
    setState(() {
      _selectedCode = lang.code;
    });
    final newLocale = Locale(lang.code);
    await context.setLocale(newLocale);
    await StorageService.saveLocale(newLocale);
    await StorageService.setLanguageChosen(true);
    VoiceService.instance.prefetchFixedPhrases(lang.code);
  }

  void _onContinue() {
    if (widget.isFromSettings) {
      context.pop();
    } else {
      context.go(RouteNames.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'choose_language_title'.tr(),
                style: AppTextStyles.displayMedium(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'choose_language_subtitle'.tr(),
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: kSupportedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = kSupportedLanguages[index];
                    final isSelected = lang.code == _selectedCode;

                    return InkWell(
                      onTap: () => _onLanguageSelected(lang),
                      borderRadius: AppRadii.cardRadius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryLight : AppColors.surface,
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.hairline,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    lang.nativeName,
                                    style: AppTextStyles.titleMedium(
                                      color: isSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.englishName,
                              style: AppTextStyles.bodySmall(
                                color: isSelected ? AppColors.primary : AppColors.inkSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              AppButton(
                label: 'continue_btn'.tr(),
                variant: AppButtonVariant.primary,
                isFullWidth: true,
                onPressed: _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
