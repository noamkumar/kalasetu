import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_recording_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/product_repository.dart';

/// Six-language tab review screen with edit, regenerate, voice refinement, and TTS playback
/// Section 8 of Project Specification
class VoiceCatalogReviewScreen extends StatefulWidget {
  final String category;
  final CatalogListingResult listing;
  final int? price;
  final String? imageUrl;

  const VoiceCatalogReviewScreen({
    super.key,
    required this.category,
    required this.listing,
    this.price,
    this.imageUrl,
  });

  @override
  State<VoiceCatalogReviewScreen> createState() => _VoiceCatalogReviewScreenState();
}

class _VoiceCatalogReviewScreenState extends State<VoiceCatalogReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VoiceService _voiceService = VoiceService.instance;
  final ProductRepository _productRepo = ProductRepository();
  final CatalogRepository _catalogRepo = CatalogRepository();
  final AudioRecordingService _audioService = AudioRecordingService();

  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _isRefining = false;
  bool _isReviewed = false;
  String? _currentlySpeakingLang;

  final List<String> _languages = ['en', 'hi', 'ta', 'te', 'kn', 'ml'];

  late Map<String, ListingItemData> _editableTranslations;

  // Controllers per language
  final Map<String, TextEditingController> _titleControllers = {};
  final Map<String, TextEditingController> _shortDescControllers = {};
  final Map<String, TextEditingController> _longDescControllers = {};
  final Map<String, TextEditingController> _materialsControllers = {};
  final Map<String, TextEditingController> _careControllers = {};
  final Map<String, TextEditingController> _seoTitleControllers = {};
  final Map<String, TextEditingController> _metaDescControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _languages.length, vsync: this);

    _editableTranslations = {};
    for (final lang in _languages) {
      final item = widget.listing.translations[lang] ?? widget.listing.master;
      _editableTranslations[lang] = ListingItemData(
        title: item.title,
        shortDescription: item.shortDescription,
        longDescription: item.longDescription,
        bulletPoints: List.from(item.bulletPoints),
        materials: List.from(item.materials),
        careInstructions: item.careInstructions,
        seoTitle: item.seoTitle.length > 60 ? item.seoTitle.substring(0, 60) : item.seoTitle,
        metaDescription: item.metaDescription.length > 155 ? item.metaDescription.substring(0, 155) : item.metaDescription,
        keywords: List.from(item.keywords),
        hashtags: List.from(item.hashtags),
      );

      _titleControllers[lang] = TextEditingController(text: item.title);
      _shortDescControllers[lang] = TextEditingController(text: item.shortDescription);
      _longDescControllers[lang] = TextEditingController(text: item.longDescription);
      _materialsControllers[lang] = TextEditingController(text: item.materials.join(', '));
      _careControllers[lang] = TextEditingController(text: item.careInstructions);
      _seoTitleControllers[lang] = TextEditingController(text: _editableTranslations[lang]!.seoTitle);
      _metaDescControllers[lang] = TextEditingController(text: _editableTranslations[lang]!.metaDescription);
    }

    // Auto-read aloud listing in artisan's current language upon screen arrival
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      String curLang = 'en';
      try {
        curLang = context.locale.languageCode;
      } catch (_) {
        curLang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
      }
      final initialIdx = _languages.indexOf(curLang);
      if (initialIdx != -1 && initialIdx != _tabController.index) {
        _tabController.index = initialIdx;
      }
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (StorageService.isAutoSpeakEnabled && !isTest) {
        _handleSpeak(curLang);
      }
    });
  }

  @override
  void dispose() {
    _voiceService.stop();
    _tabController.dispose();
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    for (final c in _shortDescControllers.values) {
      c.dispose();
    }
    for (final c in _longDescControllers.values) {
      c.dispose();
    }
    for (final c in _materialsControllers.values) {
      c.dispose();
    }
    for (final c in _careControllers.values) {
      c.dispose();
    }
    for (final c in _seoTitleControllers.values) {
      c.dispose();
    }
    for (final c in _metaDescControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _getLanguageNativeLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'kn':
        return 'ಕನ್ನಡ';
      case 'ml':
        return 'മലയാളം';
      default:
        return code.toUpperCase();
    }
  }

  void _handleSpeak(String lang) {
    final title = _titleControllers[lang]?.text.trim() ?? '';
    final desc = _shortDescControllers[lang]?.text.trim() ?? '';
    final textToSpeak = '$title. $desc';

    if (_currentlySpeakingLang == lang) {
      _voiceService.stop();
      setState(() {
        _currentlySpeakingLang = null;
      });
    } else {
      setState(() {
        _currentlySpeakingLang = lang;
      });
      _voiceService.speak(
        text: textToSpeak,
        languageCode: lang,
        onComplete: () {
          if (mounted) {
            setState(() {
              _currentlySpeakingLang = null;
            });
          }
        },
      );
    }
  }

  Future<void> _handleVoiceChange() async {
    final currentLang = _languages[_tabController.index];
    final textController = TextEditingController();
    bool isRecordingChange = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, color: AppColors.craftTerracotta, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'speak_your_change'.tr(),
                          style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'voice_change_hint'.tr(),
                    style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: 'voice_change_hint'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(
                              color: isRecordingChange ? AppColors.statusError : AppColors.primary,
                              width: 2,
                            ),
                          ),
                          icon: Icon(
                            isRecordingChange ? Icons.stop_rounded : Icons.mic_rounded,
                            color: isRecordingChange ? AppColors.statusError : AppColors.primary,
                          ),
                          label: Text(
                            isRecordingChange ? 'stop'.tr() : 'mic_btn'.tr(),
                            style: AppTextStyles.labelLarge(
                              color: isRecordingChange ? AppColors.statusError : AppColors.primary,
                            ),
                          ),
                          onPressed: () async {
                            if (isRecordingChange) {
                              final path = await _audioService.stopRecording();
                              setModalState(() => isRecordingChange = false);
                              if (path != null) {
                                try {
                                  final res = await _catalogRepo.transcribeAudio(
                                    filePath: path,
                                    languageHint: currentLang,
                                  );
                                  if (res.text.isNotEmpty) {
                                    textController.text = res.text;
                                  }
                                } catch (_) {}
                              }
                            } else {
                              final hasPerm = await _audioService.hasPermission();
                              if (!hasPerm) return;
                              final path = await _audioService.startRecording();
                              if (path != null) {
                                setModalState(() => isRecordingChange = true);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final feedback = textController.text.trim();
                            if (feedback.isEmpty) return;
                            Navigator.of(modalCtx).pop();

                            setState(() => _isRefining = true);
                            try {
                              final currentMap = <String, dynamic>{
                                'title': _titleControllers[currentLang]?.text.trim() ?? '',
                                'short_description': _shortDescControllers[currentLang]?.text.trim() ?? '',
                                'long_description': _longDescControllers[currentLang]?.text.trim() ?? '',
                                'materials': _materialsControllers[currentLang]?.text.trim() ?? '',
                                'care_instructions': _careControllers[currentLang]?.text.trim() ?? '',
                              };

                              final refined = await _catalogRepo.refineCatalog(
                                currentListing: currentMap,
                                feedback: feedback,
                                sourceLang: currentLang,
                                category: widget.category,
                              );

                              for (final lang in _languages) {
                                final item = refined.translations[lang] ?? refined.master;
                                _titleControllers[lang]?.text = item.title;
                                _shortDescControllers[lang]?.text = item.shortDescription;
                                _longDescControllers[lang]?.text = item.longDescription;
                                _materialsControllers[lang]?.text = item.materials.join(', ');
                                _careControllers[lang]?.text = item.careInstructions;
                                _seoTitleControllers[lang]?.text = item.seoTitle.length > 60 ? item.seoTitle.substring(0, 60) : item.seoTitle;
                                _metaDescControllers[lang]?.text = item.metaDescription.length > 155 ? item.metaDescription.substring(0, 155) : item.metaDescription;
                              }

                              setState(() {
                                _isReviewed = false;
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('change_applied_spoken'.tr()),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                                _handleSpeak(currentLang);
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error updating: $e'),
                                    backgroundColor: AppColors.statusError,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isRefining = false);
                              }
                            }
                          },
                          child: Text('done'.tr(), style: AppTextStyles.labelLarge(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleConfirmGood() {
    setState(() {
      _isReviewed = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('yes_this_is_good'.tr()),
        backgroundColor: AppColors.statusOnline,
      ),
    );

    if (widget.price != null) {
      _handleSave();
    } else {
      context.push('/pricing', extra: {
        'category': widget.category,
        'listing': widget.listing,
        'image_url': widget.imageUrl,
      });
    }
  }

  Future<void> _handleRegenerate() async {
    setState(() {
      _isRegenerating = true;
    });

    try {
      final currentLang = _languages[_tabController.index];
      final currentTitle = _titleControllers[currentLang]?.text.trim() ?? '';
      final currentDesc = _shortDescControllers[currentLang]?.text.trim() ?? '';
      final prompt = '$currentTitle. $currentDesc';

      final fresh = await _catalogRepo.generateCatalog(
        transcript: prompt.isNotEmpty ? prompt : widget.listing.master.title,
        sourceLang: currentLang,
        category: widget.category,
      );

      for (final lang in _languages) {
        final item = fresh.translations[lang] ?? fresh.master;
        _titleControllers[lang]?.text = item.title;
        _shortDescControllers[lang]?.text = item.shortDescription;
        _longDescControllers[lang]?.text = item.longDescription;
        _materialsControllers[lang]?.text = item.materials.join(', ');
        _careControllers[lang]?.text = item.careInstructions;
        _seoTitleControllers[lang]?.text = item.seoTitle.length > 60 ? item.seoTitle.substring(0, 60) : item.seoTitle;
        _metaDescControllers[lang]?.text = item.metaDescription.length > 155 ? item.metaDescription.substring(0, 155) : item.metaDescription;
      }

      setState(() => _isReviewed = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('regenerate'.tr()),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_isReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('unreviewed_warning'.tr()),
          backgroundColor: AppColors.statusSyncing,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = <String, dynamic>{};
      for (final lang in _languages) {
        payload[lang] = {
          'title': _titleControllers[lang]?.text.trim() ?? '',
          'short_description': _shortDescControllers[lang]?.text.trim() ?? '',
          'long_description': _longDescControllers[lang]?.text.trim() ?? '',
          'materials': _materialsControllers[lang]?.text.trim() ?? '',
          'care_instructions': _careControllers[lang]?.text.trim() ?? '',
          'seo_title': _seoTitleControllers[lang]?.text.trim() ?? '',
          'meta_description': _metaDescControllers[lang]?.text.trim() ?? '',
        };
      }

      await _productRepo.createProductWithTranslations(
        category: widget.category,
        price: (widget.price ?? 449).toDouble(),
        primaryImageUrl: widget.imageUrl,
        translations: payload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('listing_online_success'.tr()),
            backgroundColor: AppColors.statusOnline,
          ),
        );
        // Navigate back to Catalogue tab
        context.go('/home?tab=1');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('six_lang_review'.tr(), style: AppTextStyles.titleMedium()),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.inkPrimary),
            tooltip: 'regenerate'.tr(),
            onPressed: _isRegenerating ? null : _handleRegenerate,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3.0,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.inkSecondary,
          labelStyle: AppTextStyles.labelLarge(color: AppColors.primaryDark),
          tabs: _languages.map((lang) {
            return Tab(
              text: _getLanguageNativeLabel(lang),
            );
          }).toList(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _languages.map((lang) {
                  return _buildLanguageForm(lang);
                }).toList(),
              ),
            ),

            // Bottom Action Bar with 56dp Touch Targets
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.craftTerracotta, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.mic, color: AppColors.craftTerracotta),
                        label: Text(
                          'no_change_it'.tr(),
                          style: AppTextStyles.labelLarge(color: AppColors.craftTerracotta),
                        ),
                        onPressed: _isRefining ? null : _handleVoiceChange,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isReviewed ? AppColors.statusOnline : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          'yes_this_is_good'.tr(),
                          style: AppTextStyles.labelLarge(color: Colors.white),
                        ),
                        onPressed: (_isSaving || _isRefining) ? null : _handleConfirmGood,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageForm(String lang) {
    final isPlaying = _currentlySpeakingLang == lang;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Original Verbatim Words Card (Kept Verbatim • No Invented Facts)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'artisan_original_words'.tr(),
                        style: AppTextStyles.labelSmall(color: AppColors.primaryDark).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isReviewed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusOnline.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 12, color: AppColors.statusOnline),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: AppTextStyles.labelSmall(color: AppColors.statusOnline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.listing.originalTranscript.isNotEmpty
                      ? widget.listing.originalTranscript
                      : (widget.listing.original.shortDescription.isNotEmpty
                          ? widget.listing.original.shortDescription
                          : widget.listing.original.title),
                  style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Audio header with SpeakerAffordance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getLanguageNativeLabel(lang)} Listing',
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
              SpeakerAffordance(
                label: 'tap_to_hear'.tr(),
                isPlaying: isPlaying,
                onTap: () => _handleSpeak(lang),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Title field
          Text('product_title_label'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _titleControllers[lang],
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Short description field
          Text('product_desc_label'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _shortDescControllers[lang],
            maxLines: 2,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Long description field
          Text('field_long_desc'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _longDescControllers[lang],
            maxLines: 4,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Materials field
          Text('materials_label'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _materialsControllers[lang],
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Care instructions
          Text('care_instructions_label'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _careControllers[lang],
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // SEO Title (<= 60 chars)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('seo_title_label'.tr(), style: AppTextStyles.labelMedium()),
              Text(
                '${_seoTitleControllers[lang]?.text.length ?? 0}/60',
                style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _seoTitleControllers[lang],
            maxLength: 60,
            onChanged: (val) {
              setState(() {});
            },
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Meta description (<= 155 chars)
          Text('meta_desc_label'.tr(), style: AppTextStyles.labelMedium()),
          const SizedBox(height: 4),
          TextField(
            controller: _metaDescControllers[lang],
            maxLength: 155,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadii.inputRadius),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
