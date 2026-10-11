import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/craft_category_badge.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../core/widgets/voice_recorder_button.dart';
import '../../data/repositories/catalog_repository.dart';

/// Screen for recording artisan craft description & AI transcription
/// Section 8 of Project Specification
class VoiceCatalogScreen extends StatefulWidget {
  final String initialCategory;
  final String? initialImageUrl;

  const VoiceCatalogScreen({
    super.key,
    this.initialCategory = 'pottery',
    this.initialImageUrl,
  });

  @override
  State<VoiceCatalogScreen> createState() => _VoiceCatalogScreenState();
}

class _VoiceCatalogScreenState extends State<VoiceCatalogScreen> {
  final AudioRecordingService _audioService = AudioRecordingService();
  final CatalogRepository _catalogRepo = CatalogRepository();

  CraftCategory _selectedCategory = CraftCategory.pottery;
  bool _isRecording = false;
  bool _isProcessing = false;

  String? _transcriptText;
  String _detectedLang = 'en';

  final TextEditingController _transcriptController = TextEditingController();

  final List<CraftCategory> _categories = [
    CraftCategory.pottery,
    CraftCategory.handloom,
    CraftCategory.jewelry,
    CraftCategory.wood,
    CraftCategory.bamboo,
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = CraftCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == widget.initialCategory.toLowerCase(),
      orElse: () => CraftCategory.pottery,
    );
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _handleRecordingToggle(bool recording) async {
    if (recording) {
      final hasPerm = await _audioService.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('mic_permission_denied'.tr()),
            backgroundColor: AppColors.statusError,
          ),
        );
        return;
      }

      final path = await _audioService.startRecording();
      if (path != null) {
        setState(() {
          _isRecording = true;
          _transcriptText = null;
        });
      }
    } else {
      final path = await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        await _processAudioTranscription(path);
      }
    }
  }

  Future<void> _processAudioTranscription(String filePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final currentLangCode = context.locale.languageCode;
      final result = await _catalogRepo.transcribeAudio(
        filePath: filePath,
        languageHint: currentLangCode,
      );

      setState(() {
        _transcriptText = result.text;
        _detectedLang = result.detectedLang;
        _transcriptController.text = result.text;
      });

      if (result.clarity.toLowerCase() == 'low' && mounted) {
        await _showLowClarityDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    } finally {
      // Ensure audio file is deleted after use
      await AudioRecordingService.deleteAudioFile(filePath);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showLowClarityDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'did_we_hear_you_right'.tr(),
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'low_clarity_prompt'.tr(),
                  style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _transcriptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'transcript_label'.tr(),
                    border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _transcriptText = null;
                  _transcriptController.clear();
                });
              },
              child: Text('re_record'.tr(), style: AppTextStyles.labelLarge(color: AppColors.inkSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                setState(() {
                  _transcriptText = _transcriptController.text.trim();
                });
                Navigator.of(ctx).pop();
              },
              child: Text('sounds_right'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateListing() async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('describe_subtitle'.tr()),
          backgroundColor: AppColors.statusError,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final listingResult = await _catalogRepo.generateCatalog(
        transcript: text,
        sourceLang: _detectedLang,
        category: _selectedCategory.name,
      );

      if (mounted) {
        context.push(RouteNames.addPrice, extra: {
          'category': _selectedCategory.name,
          'listing': listingResult,
          'image_url': widget.initialImageUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('describe_title'.tr(), style: AppTextStyles.titleMedium()),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgressBar(currentStep: 2, totalSteps: 5),
              const SizedBox(height: 8),
              Text(
                'describe_subtitle'.tr(),
                style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Craft Category Chips
              Text(
                'category_label'.tr(),
                style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _categories.map((cat) {
                  return CraftCategoryBadge(
                    category: cat,
                    isSelected: _selectedCategory == cat,
                    onSelected: (selectedCat) {
                      setState(() {
                        _selectedCategory = selectedCat;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Voice Recorder Component
              Center(
                child: VoiceRecorderButton(
                  isRecording: _isRecording,
                  maxDurationSeconds: 90,
                  onRecordingChanged: _handleRecordingToggle,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Processing state indicator
              if (_isProcessing) ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        _transcriptText == null
                            ? 'transcribing_audio'.tr()
                            : 'generating_listing'.tr(),
                        style: AppTextStyles.labelMedium(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Transcript Card (when transcribed)
              if (_transcriptText != null && !_isProcessing) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'transcript_label'.tr(),
                            style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _detectedLang.toUpperCase(),
                              style: AppTextStyles.labelSmall(color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _transcriptController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
                          fillColor: AppColors.background,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'looks_good'.tr(),
                        variant: AppButtonVariant.primary,
                        onPressed: _generateListing,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
