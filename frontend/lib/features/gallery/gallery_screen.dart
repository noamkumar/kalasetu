import 'package:flutter/material.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/artisan_card.dart';
import '../../core/widgets/connectivity_pill.dart';
import '../../core/widgets/craft_category_badge.dart';
import '../../core/widgets/empty_craft_state.dart';
import '../../core/widgets/image_compare_slider.dart';
import '../../core/widgets/kalamitra_fab.dart';
import '../../core/widgets/language_picker.dart';
import '../../core/widgets/price_suggestion_card.dart';
import '../../core/widgets/responsive_widgets.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../core/widgets/voice_recorder_button.dart';

/// KalaSetu Component Gallery Debug Screen
/// Renders every design token and reusable component in every variant
/// Fully responsive across 320px to desktop viewports with zero overflows
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  CraftCategory _selectedCategory = CraftCategory.pottery;
  int _currentStep = 2;
  String _selectedLang = 'en';
  bool _isSpeaking = false;
  bool _isRecording = false;
  int _sliderNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    String breakpointLabel;
    if (width < AppSpacing.mobileMaxWidth) {
      breakpointLabel = 'Mobile (<480px)';
    } else if (width < AppSpacing.tabletMaxWidth) {
      breakpointLabel = 'Tablet (480-899px)';
    } else {
      breakpointLabel = 'Desktop (≥900px)';
    }

    return AppScaffold(
      selectedNavIndex: _sliderNavIndex,
      onNavItemSelected: (i) => setState(() => _sliderNavIndex = i),
      sidebarItems: const [
        SidebarNavigationItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
        SidebarNavigationItem(icon: Icons.inventory_2_outlined, label: 'Products'),
        SidebarNavigationItem(icon: Icons.shopping_bag_outlined, label: 'Orders'),
        SidebarNavigationItem(icon: Icons.insights_outlined, label: 'Analytics'),
        SidebarNavigationItem(icon: Icons.auto_awesome_motion, label: 'Gallery'),
      ],
      header: AppHeader(
        title: 'Design System Gallery',
        subtitle: 'Linen & Olive Tokens • $breakpointLabel',
        unreadNotifications: 3,
        connectivityState: ConnectivityState.online,
        syncCount: 2,
        onNotificationTap: () {},
      ),
      floatingActionButton: KalaMitraFab(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KalaMitra voice assistant sheet triggered')),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: ResponsiveContainer(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreakpointBanner(breakpointLabel, width),
              const SizedBox(height: 20),

              // 1. Color Palette Tokens
              _buildSectionHeader('1. Color Tokens (Linen & Olive)', 'Section 5.1'),
              _buildColorPaletteSection(),
              const SizedBox(height: 32),

              // 2. Typography & Indic Fallbacks
              _buildSectionHeader('2. Typography & Indic Fallbacks', 'Section 5.2'),
              _buildTypographySection(),
              const SizedBox(height: 32),

              // 3. Buttons
              _buildSectionHeader('3. AppButton Variants & States', 'Section 5.5'),
              _buildButtonSection(),
              const SizedBox(height: 32),

              // 4. Connectivity Pills & Header
              _buildSectionHeader('4. Connectivity Pills & Badges', 'Section 5.5'),
              _buildConnectivitySection(),
              const SizedBox(height: 32),

              // 5. Craft Category Badges
              _buildSectionHeader('5. Craft Category Badges', 'Section 5.5'),
              _buildCategoryChipsSection(),
              const SizedBox(height: 32),

              // 6. Step Progress Bar (Tanka-Stitch)
              _buildSectionHeader('6. Step Progress Bar (Tanka-Stitch)', 'Section 5.5'),
              _buildStepProgressBarSection(),
              const SizedBox(height: 32),

              // 7. Speaker Affordance
              _buildSectionHeader('7. Speaker Affordance (Tap to Hear)', 'Section 5.5'),
              _buildSpeakerSection(),
              const SizedBox(height: 32),

              // 8. Artisan Product Cards
              _buildSectionHeader('8. Artisan Card (28px Radius & Shadow)', 'Section 5.5'),
              _buildArtisanCardsSection(),
              const SizedBox(height: 32),

              // 9. Image Compare Slider
              _buildSectionHeader('9. Image Compare Slider (Before/After)', 'Section 5.5'),
              _buildImageCompareSection(),
              const SizedBox(height: 32),

              // 10. Voice Recorder Button
              _buildSectionHeader('10. Voice Recorder Button (Waveform & Timer)', 'Section 5.5'),
              _buildVoiceRecorderSection(),
              const SizedBox(height: 32),

              // 11. Dynamic Pricing Assistant Card
              _buildSectionHeader('11. Price Suggestion Card (AI Pricing)', 'Section 5.5 & Section 9'),
              _buildPriceSuggestionSection(),
              const SizedBox(height: 32),

              // 12. Language Picker (6 Languages)
              _buildSectionHeader('12. Language Picker (Native Scripts)', 'Section 6'),
              _buildLanguagePickerSection(),
              const SizedBox(height: 32),

              // 13. Empty Craft State
              _buildSectionHeader('13. Empty Craft State (Potter\'s Wheel Line-Art)', 'Section 5.5'),
              _buildEmptyStateSection(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakpointBanner(String label, double width) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label (${width.toStringAsFixed(0)} px)',
              style: AppTextStyles.labelMedium(color: AppColors.primaryDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Linen & Olive',
            style: AppTextStyles.labelSmall(color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String specRef) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              title,
              style: AppTextStyles.titleMedium(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                specRef,
                style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildColorPaletteSection() {
    final colors = [
      {'name': 'Background', 'hex': '#FAF6F0', 'color': AppColors.background},
      {'name': 'Surface', 'hex': '#FFFFFF', 'color': AppColors.surface},
      {'name': 'Ink Primary', 'hex': '#2B2E2A', 'color': AppColors.inkPrimary},
      {'name': 'Ink Secondary', 'hex': '#6A6E67', 'color': AppColors.inkSecondary},
      {'name': 'Primary (Sage)', 'hex': '#606C56', 'color': AppColors.primary},
      {'name': 'Primary Dark', 'hex': '#454E3E', 'color': AppColors.primaryDark},
      {'name': 'Primary Light', 'hex': '#E8ECE4', 'color': AppColors.primaryLight},
      {'name': 'Secondary (Linen)', 'hex': '#C7A379', 'color': AppColors.secondary},
      {'name': 'Accent Blue (Bot)', 'hex': '#4A6572', 'color': AppColors.accentBlue},
      {'name': 'Terracotta', 'hex': '#C85A32', 'color': AppColors.craftTerracotta},
      {'name': 'Ochre', 'hex': '#D9822B', 'color': AppColors.craftOchre},
      {'name': 'Status Online', 'hex': '#2E7D32', 'color': AppColors.statusOnline},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 360
            ? ((constraints.maxWidth - 12) / 2).floorToDouble()
            : 135.0;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((item) {
            final c = item['color'] as Color;
            return Container(
              width: itemWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['name'] as String,
                    style: AppTextStyles.labelMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item['hex'] as String,
                    style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTypographySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fraunces Display Large (34pt Serif)', style: AppTextStyles.displayLarge()),
          const SizedBox(height: 8),
          Text('Fraunces Headline Medium (20pt Serif)', style: AppTextStyles.headlineMedium()),
          const SizedBox(height: 8),
          Text('Manrope Title Large (18pt Bold)', style: AppTextStyles.titleLarge()),
          const SizedBox(height: 8),
          Text(
            'Manrope Body Large: KalaSetu bridges local artisans directly with global craft lovers.',
            style: AppTextStyles.bodyLarge(),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Text('Indic Script Fallbacks:', style: AppTextStyles.titleSmall()),
          const SizedBox(height: 8),
          Text('Hindi (हिन्दी): मिट्टी के हस्तनिर्मित बर्तन और कलाकृतियाँ', style: AppTextStyles.bodyMedium()),
          const SizedBox(height: 4),
          Text('Tamil (தமிழ்): பாரம்பரிய கைத்தறி மற்றும் சுடுமண் சிற்பங்கள்', style: AppTextStyles.bodyMedium()),
          const SizedBox(height: 4),
          Text('Telugu (తెలుగు): సాంప్రదాయ చేనేత మరియు హస్తకళలు', style: AppTextStyles.bodyMedium()),
          const SizedBox(height: 4),
          Text('Kannada (ಕನ್ನಡ): ಸಾಂಪ್ರದಾಯಿಕ ಕರಕುಶಲ ವಸ್ತುಗಳು', style: AppTextStyles.bodyMedium()),
          const SizedBox(height: 4),
          Text('Malayalam (മലയാളം): പരമ്പരാഗത കരകൗശല ഉത്പന്നങ്ങൾ', style: AppTextStyles.bodyMedium()),
        ],
      ),
    );
  }

  Widget _buildButtonSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        if (isNarrow) {
          // Spec Section 5.4: buttons stack vertically when narrower than 480
          return Column(
            children: [
              AppButton(
                label: 'Primary Button',
                variant: AppButtonVariant.primary,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Secondary Button',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Outlined Button',
                variant: AppButtonVariant.outlined,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Text Button',
                variant: AppButtonVariant.text,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'With Icon',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              const AppButton(
                label: 'Loading State',
                variant: AppButtonVariant.primary,
                isLoading: true,
                onPressed: null,
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Primary Button',
                    variant: AppButtonVariant.primary,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Secondary Button',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Outlined Button',
                    variant: AppButtonVariant.outlined,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Text Button',
                    variant: AppButtonVariant.text,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'With Icon',
                    variant: AppButtonVariant.primary,
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: AppButton(
                    label: 'Loading State',
                    variant: AppButtonVariant.primary,
                    isLoading: true,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectivitySection() {
    return const Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        ConnectivityPill(state: ConnectivityState.online),
        ConnectivityPill(state: ConnectivityState.syncing, syncCount: 3),
        ConnectivityPill(state: ConnectivityState.offline),
      ],
    );
  }

  Widget _buildCategoryChipsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CraftCategory.values.map((cat) {
        return CraftCategoryBadge(
          category: cat,
          isSelected: _selectedCategory == cat,
          onSelected: (c) => setState(() => _selectedCategory = c),
        );
      }).toList(),
    );
  }

  Widget _buildStepProgressBarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          StepProgressBar(
            currentStep: _currentStep,
            onStepTapped: (step) => setState(() => _currentStep = step),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: _currentStep > 1 ? () => setState(() => _currentStep--) : null,
                child: const Text('Previous Step'),
              ),
              TextButton(
                onPressed: _currentStep < 4 ? () => setState(() => _currentStep++) : null,
                child: const Text('Next Step'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerSection() {
    void toggleSpeech() {
      if (_isSpeaking) {
        VoiceService.instance.stop();
        setState(() => _isSpeaking = false);
      } else {
        setState(() => _isSpeaking = true);
        VoiceService.instance.speak(
          text: 'Welcome to KalaSetu design gallery.',
          languageCode: 'en',
          onComplete: () {
            if (mounted) setState(() => _isSpeaking = false);
          },
        );
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SpeakerAffordance(
          label: _isSpeaking ? 'Playing audio...' : 'Tap to hear',
          isPlaying: _isSpeaking,
          onTap: toggleSpeech,
        ),
        SpeakerAffordance(
          isCompact: true,
          isPlaying: _isSpeaking,
          onTap: toggleSpeech,
        ),
      ],
    );
  }

  Widget _buildArtisanCardsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;

        if (isNarrow) {
          return Column(
            children: [
              ArtisanCard(
                category: 'Pottery',
                title: 'Terracotta Water Pitcher',
                subtitle: 'Hand-thrown natural red clay pot',
                price: '₹449',
                rating: 4.8,
                ratingCount: 26,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ArtisanCard(
                category: 'Handloom',
                title: 'Kalamkari Cotton Stole',
                subtitle: 'Vegetable dye block print',
                price: '₹899',
                rating: 4.9,
                ratingCount: 14,
                onTap: () {},
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ArtisanCard(
                category: 'Pottery',
                title: 'Terracotta Water Pitcher',
                subtitle: 'Hand-thrown natural red clay pot',
                price: '₹449',
                rating: 4.8,
                ratingCount: 26,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ArtisanCard(
                category: 'Handloom',
                title: 'Kalamkari Cotton Stole',
                subtitle: 'Vegetable dye block print',
                price: '₹899',
                rating: 4.9,
                ratingCount: 14,
                onTap: () {},
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageCompareSection() {
    return ImageCompareSlider(
      height: 240,
      beforeWidget: Container(
        color: const Color(0xFFD7CCC8), // Raw clay tone
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Color(0xFF8D6E63)),
              SizedBox(height: 6),
              Text(
                'Original Studio Frame',
                style: TextStyle(color: Color(0xFF5D4037)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      afterWidget: Container(
        color: AppColors.background,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 48, color: AppColors.primary),
              SizedBox(height: 6),
              Text(
                'AI Cleaned & Travertine Shadow',
                style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecorderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Center(
        child: VoiceRecorderButton(
          isRecording: _isRecording,
          onRecordingChanged: (rec) => setState(() => _isRecording = rec),
        ),
      ),
    );
  }

  Widget _buildPriceSuggestionSection() {
    return PriceSuggestionCard(
      recommendedPrice: 449,
      floorPrice: 340,
      budgetPrice: 399,
      premiumPrice: 549,
      confidence: 0.88,
      explanation: 'Based on 3 hours of labour at fair artisan wage, ₹80 raw clay cost, and comparable handcrafted terracotta pots.',
      factors: const [
        PriceFactor(name: 'Material (Terracotta clay)', value: '₹80'),
        PriceFactor(name: 'Labour (3.0 hrs @ ₹80/hr)', value: '₹240'),
        PriceFactor(name: 'Overhead & Firing', value: '₹20'),
        PriceFactor(name: 'Artisan Margin', value: '₹109'),
      ],
      comparables: const [
        ComparableItem(title: 'Pachmura Earthen Pitcher', price: 480, similarity: 0.88),
        ComparableItem(title: 'Traditional Surahi Clay Pot', price: 420, similarity: 0.82),
      ],
      onAccept: () {},
      onEdit: () {},
      onSpeak: () {},
    );
  }

  Widget _buildLanguagePickerSection() {
    return Column(
      children: [
        LanguagePicker(
          selectedCode: _selectedLang,
          onLanguageSelected: (lang) => setState(() => _selectedLang = lang.code),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Open Language Modal Sheet',
          variant: AppButtonVariant.outlined,
          onPressed: () {
            LanguagePicker.showBottomSheet(
              context: context,
              currentCode: _selectedLang,
            ).then((lang) {
              if (lang != null) {
                setState(() => _selectedLang = lang.code);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildEmptyStateSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
      ),
      child: EmptyCraftState(
        onAction: () {},
      ),
    );
  }
}
