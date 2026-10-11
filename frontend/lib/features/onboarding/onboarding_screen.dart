import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/speaker_affordance.dart';

/// Narrated First-Run Walkthrough
/// Requirement 7: 8 slides max, skippable, narrated audio on each slide,
/// persistent "Help me" / replay speaker button, large text toggle.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.storefront_rounded,
      'badgeKey': 'walkthrough_badge_1',
      'titleKey': 'walkthrough_title_1',
      'descKey': 'walkthrough_desc_1',
    },
    {
      'icon': Icons.camera_alt_rounded,
      'badgeKey': 'walkthrough_badge_2',
      'titleKey': 'walkthrough_title_2',
      'descKey': 'walkthrough_desc_2',
    },
    {
      'icon': Icons.mic_rounded,
      'badgeKey': 'walkthrough_badge_3',
      'titleKey': 'walkthrough_title_3',
      'descKey': 'walkthrough_desc_3',
    },
    {
      'icon': Icons.shield_rounded,
      'badgeKey': 'walkthrough_badge_4',
      'titleKey': 'walkthrough_title_4',
      'descKey': 'walkthrough_desc_4',
    },
    {
      'icon': Icons.qr_code_2_rounded,
      'badgeKey': 'walkthrough_badge_5',
      'titleKey': 'walkthrough_title_5',
      'descKey': 'walkthrough_desc_5',
    },
    {
      'icon': Icons.inventory_2_rounded,
      'badgeKey': 'walkthrough_badge_6',
      'titleKey': 'walkthrough_title_6',
      'descKey': 'walkthrough_desc_6',
    },
    {
      'icon': Icons.record_voice_over_rounded,
      'badgeKey': 'walkthrough_badge_7',
      'titleKey': 'walkthrough_title_7',
      'descKey': 'walkthrough_desc_7',
    },
    {
      'icon': Icons.rocket_launch_rounded,
      'badgeKey': 'walkthrough_badge_8',
      'titleKey': 'walkthrough_title_8',
      'descKey': 'walkthrough_desc_8',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentSlide();
    });
  }

  void _speakCurrentSlide() {
    final slide = _slides[_currentIndex];
    final narration = '${(slide['titleKey'] as String).tr()}. ${(slide['descKey'] as String).tr()}';
    SimpleModeVoiceHelper.autoSpeakScreenInstruction(context, narration);
  }

  Future<void> _completeOnboarding() async {
    VoiceService.instance.stop();
    await StorageService.setOnboardingCompleted(true);
    if (!mounted) return;
    context.go(RouteNames.authPhone);
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final currentSlide = _slides[_currentIndex];
    final narration = '${(currentSlide['titleKey'] as String).tr()}. ${(currentSlide['descKey'] as String).tr()}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ValueListenableBuilder<bool>(
          valueListenable: StorageService.largeTextNotifier,
          builder: (context, isLarge, _) {
            return IconButton(
              icon: Icon(
                isLarge ? Icons.text_fields_rounded : Icons.format_size_rounded,
                color: isLarge ? AppColors.primary : AppColors.inkSecondary,
              ),
              tooltip: 'large_text_toggle'.tr(),
              onPressed: () {
                StorageService.setLargeTextEnabled(!isLarge);
              },
            );
          },
        ),
        actions: [
          SpeakerAffordance(
            textToSpeak: narration,
            languageCode: lang,
            label: 'listen_instruction'.tr(),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'skip'.tr(),
              style: AppTextStyles.labelLarge(color: AppColors.inkSecondary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _speakCurrentSlide();
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            (slide['badgeKey'] as String).tr(),
                            style: AppTextStyles.labelSmall(color: AppColors.secondary)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (slide['titleKey'] as String).tr(),
                          style: AppTextStyles.displaySmall(color: AppColors.inkPrimary)
                              .copyWith(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (slide['descKey'] as String).tr(),
                          style: AppTextStyles.bodyLarge(color: AppColors.inkSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentIndex == index ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.primary
                              : AppColors.hairline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _currentIndex == _slides.length - 1
                        ? 'get_started'.tr()
                        : 'next'.tr(),
                    variant: AppButtonVariant.primary,
                    minHeight: 58.0,
                    isFullWidth: true,
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
