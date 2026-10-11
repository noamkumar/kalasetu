import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/image_compare_slider.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../core/services/voice_service.dart';
import '../../data/api/api_client.dart';
import 'models/enhanced_image_result.dart';
import 'services/image_studio_service.dart';
import 'photo_editor_screen.dart';

/// KalaSetu AI Image Studio Screen
/// 5-Step Add Product Wizard (Step 1: Photo)
/// Features icon StepProgressBar, help header icon, photo-tips carousel
/// with "Tap to hear", large capture area, Take Photo and Upload from Gallery buttons.
class ImageStudioScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ImageStudioScreen({super.key, this.onBack});

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageStudioService _studioService = ImageStudioService();
  final PageController _tipsPageController = PageController();

  // Multi-photo slots: Front, Angle, Detail, Scale
  final List<String?> _slotPaths = [null, null, null, null];
  int _selectedSlot = 0;
  int _currentTipIndex = 0;

  String _canvasStyle = 'white'; // 'white' or 'linen'
  bool _isProcessing = false;
  String? _errorMessage;

  EnhancedImageResult? _enhancedResult;
  VoidCallback? _pendingRetryEnhance;

  void _handleEnhanceError(String errorMsg, VoidCallback retryAction) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _errorMessage = errorMsg;
      _pendingRetryEnhance = retryAction;
    });
    VoiceService.instance.speak(
      text: errorMsg,
      languageCode: context.locale.languageCode,
    );
  }

  final List<String> _slotLabels = [
    'photo_type_front',
    'photo_type_angle',
    'photo_type_detail',
    'photo_type_scale',
  ];

  @override
  void dispose() {
    _tipsPageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 95,
      );

      if (picked != null) {
        setState(() {
          _slotPaths[_selectedSlot] = picked.path;
          _errorMessage = null;
        });
        await _enhanceCurrentPhoto(picked.path);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not access camera or gallery: $e';
      });
    }
  }

  Future<void> _enhanceCurrentPhoto(String filePath) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await _studioService.enhanceImage(
        filePath: filePath,
        canvasStyle: _canvasStyle,
        geminiVisionTags: true,
      );

      if (result.status == 'error' || result.heroUrl.isEmpty) {
        _handleEnhanceError('photo_edit_failed_spoken'.tr(), () => _enhanceCurrentPhoto(filePath));
        return;
      }

      if (mounted) {
        setState(() {
          _enhancedResult = result;
          _isProcessing = false;
          _errorMessage = null;
          _pendingRetryEnhance = null;
        });
      }
    } catch (e) {
      _handleEnhanceError('photo_edit_failed_spoken'.tr(), () => _enhanceCurrentPhoto(filePath));
    }
  }

  void _onStyleChanged(String newStyle) {
    if (_canvasStyle == newStyle) return;
    setState(() {
      _canvasStyle = newStyle;
    });
    final currentPath = _slotPaths[_selectedSlot];
    if (currentPath != null) {
      _enhanceCurrentPhoto(currentPath);
    }
  }

  void _retakeCurrentPhoto() {
    setState(() {
      _slotPaths[_selectedSlot] = null;
      _enhancedResult = null;
      _errorMessage = null;
    });
  }

  void _continueToVoiceListing() {
    final category = _enhancedResult?.visualTags['category']?.toString() ?? 'pottery';
    final heroUrl = _enhancedResult?.heroUrl ?? _slotPaths[0] ?? '';

    context.push(
      '${RouteNames.addDescribe}?category=$category&image_url=${Uri.encodeComponent(heroUrl)}',
    );
  }

  void _openPhotoEditor() async {
    final currentPath = _slotPaths[_selectedSlot];
    if (currentPath == null) return;

    String imageId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
    final hero = _enhancedResult?.heroUrl ?? '';
    if (hero.isNotEmpty) {
      final name = hero.split('/').last;
      imageId = name.replaceAll('_square.webp', '').replaceAll('_original.jpg', '');
    }

    final editedUrl = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PhotoEditorScreen(
          imageId: imageId,
          originalUrl: currentPath,
          initialEditedUrl: hero.isNotEmpty ? hero : currentPath,
        ),
      ),
    );

    if (editedUrl != null && editedUrl.isNotEmpty && mounted) {
      setState(() {
        if (_enhancedResult != null) {
          _enhancedResult = EnhancedImageResult(
            originalUrl: _enhancedResult!.originalUrl,
            heroUrl: editedUrl,
            socialUrl: _enhancedResult!.socialUrl,
            thumbnailUrl: _enhancedResult!.thumbnailUrl,
            canvasStyle: _canvasStyle,
            qualityScore: _enhancedResult!.qualityScore,
            metrics: _enhancedResult!.metrics,
            tips: _enhancedResult!.tips,
            visualTags: _enhancedResult!.visualTags,
            status: _enhancedResult!.status,
            aiPolishApplied: _enhancedResult!.aiPolishApplied,
          );
        }
      });
    }
  }

  void _showHelpDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'photo_help_title'.tr(),
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.inkSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'photo_help_body'.tr(),
              style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'dialog_ok'.tr(),
              variant: AppButtonVariant.primary,
              isFullWidth: true,
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentPhoto = _slotPaths[_selectedSlot] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header with Back button, Serif Title and Help Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.arrow_back, color: AppColors.inkPrimary),
                      onPressed: widget.onBack,
                    ),
                  Expanded(
                    child: Text(
                      'tab_add_product'.tr(),
                      style: AppTextStyles.displaySmall(color: AppColors.inkPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'photo_help_title'.tr(),
                    child: IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.help_outline, color: AppColors.inkPrimary),
                      tooltip: 'photo_help_title'.tr(),
                      onPressed: _showHelpDialog,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 5-Step Icon StepProgressBar (Step 1: Photo)
            const StepProgressBar(currentStep: 1, totalSteps: 5),
            const Divider(color: AppColors.hairline, height: 1),

            // Main Scrollable Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3. Photo-Tips Carousel with "Tap to hear"
                    _buildPhotoTipsCarousel(),
                    const SizedBox(height: 14),

                    // Error Message Banner if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusError.withValues(alpha: 0.08),
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.statusError),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.statusError, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodySmall(color: AppColors.statusError),
                              ),
                            ),
                            if (_pendingRetryEnhance != null) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusError,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                                ),
                                onPressed: () {
                                  final act = _pendingRetryEnhance;
                                  setState(() {
                                    _errorMessage = null;
                                    _pendingRetryEnhance = null;
                                  });
                                  act?.call();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: Text('try_again_btn'.tr()),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. Large Capture Viewport / Area
                    if (_isProcessing)
                      _buildProcessingView()
                    else if (_enhancedResult != null && hasCurrentPhoto)
                      _buildComparisonView(_enhancedResult!, _slotPaths[_selectedSlot]!)
                    else
                      _buildLargeCaptureArea(),

                    const SizedBox(height: 16),

                    // 5. Two Prominent Buttons: Take Photo & Upload from Gallery
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48.0),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
                              ),
                              icon: const Icon(Icons.camera_alt, size: 20),
                              label: Text(
                                'take_photo_btn'.tr(),
                                style: AppTextStyles.labelLarge(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48.0),
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.inkPrimary,
                                side: const BorderSide(color: AppColors.hairline, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
                              ),
                              icon: const Icon(Icons.photo_library_outlined, size: 20, color: AppColors.inkPrimary),
                              label: Text(
                                'upload_gallery_btn'.tr(),
                                style: AppTextStyles.labelLarge(color: AppColors.inkPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 6. Multi-Photo Slots (Front, Angle, Detail, Scale)
                    _buildSlotSelector(),
                    const SizedBox(height: 16),

                    // 7. Background Style Chooser (White / Linen)
                    if (hasCurrentPhoto) ...[
                      _buildCanvasStyleSelector(),
                      const SizedBox(height: 16),
                    ],

                    // Retake & Continue Buttons when photo ready
                    if (hasCurrentPhoto && _enhancedResult != null) ...[
                      AppButton(
                        label: 'edit_photo_btn'.tr(),
                        variant: AppButtonVariant.secondary,
                        icon: const Icon(Icons.auto_fix_high, size: 20, color: AppColors.inkPrimary),
                        isFullWidth: true,
                        onPressed: _openPhotoEditor,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'retake_photo'.tr(),
                              variant: AppButtonVariant.outlined,
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: _retakeCurrentPhoto,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'continue_btn'.tr(),
                              variant: AppButtonVariant.primary,
                              icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                              onPressed: _continueToVoiceListing,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Photo-Tips Carousel with Tap to hear TTS
  Widget _buildPhotoTipsCarousel() {
    final tips = [
      'photo_tip_1'.tr(),
      'photo_tip_2'.tr(),
      'photo_tip_3'.tr(),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight.withValues(alpha: 0.6),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: PageView.builder(
              controller: _tipsPageController,
              onPageChanged: (idx) => setState(() => _currentTipIndex = idx),
              itemCount: tips.length,
              itemBuilder: (context, index) {
                final tipText = tips[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.tips_and_updates_outlined, color: AppColors.craftOchre, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tipText,
                        style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SpeakerAffordance(
                      textToSpeak: tipText,
                      languageCode: context.locale.languageCode,
                      isCompact: true,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Page Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(tips.length, (idx) {
              final isActive = idx == _currentTipIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Large Viewfinder Capture Area
  Widget _buildLargeCaptureArea() {
    return InkWell(
      onTap: () => _pickImage(ImageSource.camera),
      borderRadius: AppRadii.cardRadius,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle Grid guidelines
            Column(
              children: [
                Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline.withValues(alpha: 0.5)))))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline.withValues(alpha: 0.5)))))),
                const Expanded(child: SizedBox()),
              ],
            ),
            Row(
              children: [
                Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.hairline.withValues(alpha: 0.5)))))),
                Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.hairline.withValues(alpha: 0.5)))))),
                const Expanded(child: SizedBox()),
              ],
            ),
            // Center Viewfinder Prompt
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'tap_to_capture_hint'.tr(),
                    style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'choose_photo_source'.tr(),
                    style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'enhancing_photo_progress'.tr(),
              style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'enhancing_progress_sub'.tr(),
              style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonView(EnhancedImageResult result, String originalPath) {
    final heroPath = ApiClient().resolveMediaUrl(result.heroUrl);

    final beforeImage = Image.file(
      File(originalPath),
      fit: BoxFit.contain,
    );

    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final afterImage = result.heroUrl.startsWith('http') || result.heroUrl.startsWith('/static')
        ? Image.network(
            heroPath.contains('?') ? '$heroPath&t=$cacheBuster' : '$heroPath?t=$cacheBuster',
            key: ValueKey('$heroPath-$cacheBuster'),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.file(File(originalPath), fit: BoxFit.contain),
          )
        : Image.file(
            File(result.heroUrl),
            key: ValueKey('${result.heroUrl}-$cacheBuster'),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.file(File(originalPath), fit: BoxFit.contain),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImageCompareSlider(
          beforeWidget: beforeImage,
          afterWidget: afterImage,
          height: 300,
          beforeLabel: 'slider_before'.tr(),
          afterLabel: 'slider_after'.tr(),
        ),
        const SizedBox(height: 10),
        // Quality Score & Fallback Alert
        if (result.isFallback)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.statusSyncing),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.statusSyncing, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'enhancement_fallback_notice'.tr(),
                    style: AppTextStyles.bodySmall(color: AppColors.inkPrimary),
                  ),
                ),
              ],
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadii.pillRadius,
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${'quality_score_label'.tr()}: ${result.qualityScore}/100',
                    style: AppTextStyles.labelMedium(color: AppColors.primaryDark),
                  ),
                ],
              ),
            ),
            Text(
              '${'resolution_label'.tr()}: 2000x2000',
              style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'photo_slots_heading'.tr(),
          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (index) {
            final isSelected = index == _selectedSlot;
            final hasPhoto = _slotPaths[index] != null;
            final labelKey = _slotLabels[index];

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedSlot = index);
                },
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : AppColors.surface,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.hairline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: hasPhoto
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_slotPaths[index]!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt_outlined,
                                  color: isSelected ? AppColors.primary : AppColors.inkSecondary,
                                  size: 24,
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labelKey.tr(),
                        style: AppTextStyles.labelSmall(
                          color: isSelected ? AppColors.primaryDark : AppColors.inkSecondary,
                        ).copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCanvasStyleSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'canvas_style_label'.tr(),
              style: AppTextStyles.labelMedium(color: AppColors.inkPrimary),
            ),
          ),
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 6),
                Text('canvas_style_white'.tr()),
              ],
            ),
            selected: _canvasStyle == 'white',
            selectedColor: AppColors.primaryLight,
            onSelected: (_) => _onStyleChanged('white'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6F0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 6),
                Text('canvas_style_linen'.tr()),
              ],
            ),
            selected: _canvasStyle == 'linen',
            selectedColor: AppColors.secondaryLight,
            onSelected: (_) => _onStyleChanged('linen'),
          ),
        ],
      ),
    );
  }
}
