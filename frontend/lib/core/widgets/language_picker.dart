import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class SupportedLanguage {
  final String code;
  final String englishName;
  final String nativeName;
  final String ttsLocale;

  const SupportedLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.ttsLocale,
  });
}

const List<SupportedLanguage> kSupportedLanguages = [
  SupportedLanguage(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    ttsLocale: 'en-IN',
  ),
  SupportedLanguage(
    code: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    ttsLocale: 'hi-IN',
  ),
  SupportedLanguage(
    code: 'ta',
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
    ttsLocale: 'ta-IN',
  ),
  SupportedLanguage(
    code: 'te',
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
    ttsLocale: 'te-IN',
  ),
  SupportedLanguage(
    code: 'kn',
    englishName: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    ttsLocale: 'kn-IN',
  ),
  SupportedLanguage(
    code: 'ml',
    englishName: 'Malayalam',
    nativeName: 'മലയാളം',
    ttsLocale: 'ml-IN',
  ),
];

/// KalaSetu Language Picker
/// Displays large native-script buttons for the 6 supported languages
/// Section 5.5 and Section 6 of Project Specification
class LanguagePicker extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<SupportedLanguage> onLanguageSelected;
  final bool isCompact;

  const LanguagePicker({
    super.key,
    required this.selectedCode,
    required this.onLanguageSelected,
    this.isCompact = false,
  });

  /// Displays the LanguagePicker in a modal bottom sheet
  static Future<SupportedLanguage?> showBottomSheet({
    required BuildContext context,
    required String currentCode,
  }) {
    return showModalBottomSheet<SupportedLanguage>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.sheetRadius,
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose your language',
                  style: AppTextStyles.displaySmall(),
                ),
                const SizedBox(height: 6),
                Text(
                  'अपनी भाषा चुनें / உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
                  style: AppTextStyles.bodySmall(),
                ),
                const SizedBox(height: 20),
                LanguagePicker(
                  selectedCode: currentCode,
                  onLanguageSelected: (lang) => Navigator.of(context).pop(lang),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = isCompact || screenWidth < 360;
    final cols = isNarrow ? 1 : 2;
    final aspect = isNarrow ? 3.2 : 1.5;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kSupportedLanguages.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10.0,
        crossAxisSpacing: 10.0,
        childAspectRatio: aspect,
      ),
      itemBuilder: (context, index) {
        final lang = kSupportedLanguages[index];
        final isSelected = lang.code == selectedCode;

        return Material(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => onLanguageSelected(lang),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.hairline,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.nativeName,
                          style: AppTextStyles.titleMedium(
                            color: isSelected ? AppColors.primaryDark : AppColors.inkPrimary,
                          ).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
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
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
