import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/simple_mode_voice_helper.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/big_numeric_keypad.dart';
import '../../core/widgets/image_compare_slider.dart';
import '../../core/widgets/speaker_affordance.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/local_db/app_database.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../pricing/services/pricing_service.dart';
import 'services/image_editor_service.dart';

/// Guided 4-Screen "Sell a Product" Flow for Simple Mode
/// Screen 1: Photo (Capture/Pick + Gemini Background/Lighting Edit + Vision Fidelity Check)
/// Screen 2: Details (Verbatim Spoken Voice + Gemini 6-Language Listing + Refinement)
/// Screen 3: Price (3 Sequential Questions + Numeric Keypad/Voice + Cost Floor & Tiers)
/// Screen 4: Publish (Full Buyer Card Preview + Multi-Language Preview + Publish Guard)
class SimpleAddProductScreen extends StatefulWidget {
  final bool showAppBar;

  const SimpleAddProductScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<SimpleAddProductScreen> createState() => _SimpleAddProductScreenState();
}

class _SimpleAddProductScreenState extends State<SimpleAddProductScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageEditorService _editorService = ImageEditorService();
  final CatalogRepository _catalogRepo = CatalogRepository();
  final AudioRecordingService _audioService = AudioRecordingService();
  final PricingService _pricingService = PricingService();
  final ProductRepository _productRepo = ProductRepository();

  int _currentStep = 1; // 1: Photo, 2: Details, 3: Price, 4: Publish
  bool _isLoading = false;
  String? _statusText;
  String? _errorMessage;
  VoidCallback? _pendingRetryAction;
  int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
  String? _backendUploadedId;

  // --- SCREEN 1: PHOTO STATE ---
  String? _rawPhotoPath;
  String? _editedPhotoPath;
  String _imageId = 'img_craft';
  bool _isEditingPhoto = false;
  bool _isRecordingPhotoEdit = false;
  final TextEditingController _photoEditController = TextEditingController();
  final List<String> _editHistory = [];
  bool _fidelityWarningShown = false;

  // --- SCREEN 2: DETAILS STATE ---
  String _verbatimName = '';
  String _verbatimDesc = '';
  String _cleanedTitle = '';
  String _cleanedDesc = '';
  String _detectedCategory = 'pottery';
  CatalogListingResult? _listingResult;
  String _previewLanguage = 'en';
  String? _activeRecordingField; // 'name' | 'desc'

  // --- SCREEN 3: PRICE STATE ---
  int _priceQuestionIndex = 1; // 1: Materials, 2: Labour, 3: Other
  double _materialCost = 150.0;
  double _labourHours = 3.5;
  double _otherCost = 0.0;
  String _keypadInput = '150';
  int _costFloor = 534;
  int _budgetPrice = 550;
  int _recommendedPrice = 650;
  int _premiumPrice = 850;
  int _selectedPrice = 650;
  double _pricingConfidence = 0.90;
  bool _isEstimate = false;

  // --- SCREEN 4: PUBLISH PREVIEW STATE ---
  String _buyerPreviewLang = 'en';

  @override
  void initState() {
    super.initState();
    _loadSavedDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakCurrentStepInstruction();
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    _photoEditController.dispose();
    super.dispose();
  }

  String _safeLang(BuildContext context) {
    try {
      return context.locale.languageCode;
    } catch (_) {
      return Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    }
  }

  // --- DRAFT PERSISTENCE ---
  void _loadSavedDraft() {
    final draft = StorageService.getProductDraft();
    if (draft == null || draft.isEmpty) return;

    setState(() {
      _rawPhotoPath = draft['rawPhotoPath'] as String?;
      _editedPhotoPath = draft['editedPhotoPath'] as String?;
      _imageId = draft['imageId'] as String? ?? 'img_craft';
      _cleanedTitle = draft['cleanedTitle'] as String? ?? '';
      _cleanedDesc = draft['cleanedDesc'] as String? ?? '';
      _verbatimName = draft['verbatimName'] as String? ?? '';
      _verbatimDesc = draft['verbatimDesc'] as String? ?? '';
      _detectedCategory = draft['category'] as String? ?? 'pottery';
      _materialCost = (draft['materialCost'] as num?)?.toDouble() ?? 150.0;
      _labourHours = (draft['labourHours'] as num?)?.toDouble() ?? 3.5;
      _otherCost = (draft['otherCost'] as num?)?.toDouble() ?? 0.0;
      _costFloor = (draft['costFloor'] as num?)?.toInt() ?? 534;
      _selectedPrice = (draft['selectedPrice'] as num?)?.toInt() ?? 650;
      _recommendedPrice = _selectedPrice;
      _currentStep = (draft['currentStep'] as num?)?.toInt().clamp(1, 4) ?? 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_rawPhotoPath != null || _cleanedTitle.isNotEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('draft_resumed_msg'.tr()),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    });
  }

  Future<void> _saveDraft() async {
    final draft = <String, dynamic>{
      'currentStep': _currentStep,
      'rawPhotoPath': _rawPhotoPath,
      'editedPhotoPath': _editedPhotoPath,
      'imageId': _imageId,
      'cleanedTitle': _cleanedTitle,
      'cleanedDesc': _cleanedDesc,
      'verbatimName': _verbatimName,
      'verbatimDesc': _verbatimDesc,
      'category': _detectedCategory,
      'materialCost': _materialCost,
      'labourHours': _labourHours,
      'otherCost': _otherCost,
      'costFloor': _costFloor,
      'selectedPrice': _selectedPrice,
    };
    await StorageService.saveProductDraft(draft);
  }

  // --- AUDIO INSTRUCTION ---
  void _speakCurrentStepInstruction() {
    String instructionKey;
    switch (_currentStep) {
      case 1:
        instructionKey = 'step1_photo_instruction';
        break;
      case 2:
        instructionKey = 'step2_details_instruction';
        break;
      case 3:
        instructionKey = 'step3_price_instruction';
        break;
      case 4:
        instructionKey = 'step4_publish_instruction';
        break;
      default:
        instructionKey = 'step1_photo_instruction';
    }

    SimpleModeVoiceHelper.autoSpeakScreenInstruction(
      context,
      instructionKey.tr(),
    );
  }

  String _getInstructionForCurrentStep() {
    switch (_currentStep) {
      case 1:
        return 'step1_photo_instruction'.tr();
      case 2:
        return 'step2_details_instruction'.tr();
      case 3:
        return 'step3_price_instruction'.tr();
      case 4:
        return 'step4_publish_instruction'.tr();
      default:
        return '';
    }
  }

  // =========================================================================
  // SCREEN 1: PHOTO LOGIC
  // =========================================================================

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );

      if (picked != null) {
        final imgId = 'img_${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _rawPhotoPath = picked.path;
          _editedPhotoPath = null;
          _imageId = imgId;
          _backendUploadedId = null;
          _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
          _editHistory.clear();
          _editHistory.add(picked.path);
          _isEditingPhoto = false;
          _errorMessage = null;
        });

        await _saveDraft();

        if (mounted) {
          await SimpleModeVoiceHelper.playSuccessFeedback(
            context,
            'photo_captured_spoken'.tr(),
          );
        }
      }
    } catch (_) {
      _showFriendlyError('could_not_take_photo'.tr(), () => _pickPhoto(source));
    }
  }

  Future<void> _applyPhotoEditPrompt(String promptText, {String? audioPath}) async {
    if (promptText.trim().isEmpty && (audioPath == null || audioPath.isEmpty)) return;

    final lang = _safeLang(context);
    setState(() {
      _isLoading = true;
      _statusText = 'enhancing_photo_progress'.tr();
      _errorMessage = null;
    });

    try {
      // 1. If photo hasn't been uploaded yet, upload first so backend has source
      if (_rawPhotoPath != null && (_backendUploadedId == null || _backendUploadedId != _imageId)) {
        try {
          final up = await _editorService.uploadProductImage(_rawPhotoPath!);
          _imageId = up['image_id']?.toString() ?? _imageId;
          _backendUploadedId = _imageId;
        } catch (_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showFriendlyError(
              'photo_edit_failed_spoken'.tr(),
              () => _applyPhotoEditPrompt(promptText, audioPath: audioPath),
            );
          }
          return;
        }
      }

      String effectivePrompt = promptText.trim();
      if (effectivePrompt.isEmpty && audioPath != null && audioPath.isNotEmpty) {
        try {
          final transcribed = await _catalogRepo.transcribeAudio(
            filePath: audioPath,
            languageHint: lang,
          );
          effectivePrompt = transcribed.text.trim();
          await AudioRecordingService.deleteAudioFile(audioPath);
        } catch (_) {}
      }

      final res = await _editorService.editImage(
        imageId: _imageId,
        prompt: effectivePrompt.isNotEmpty ? effectivePrompt : 'remove background and make background clean white',
        lang: lang,
      );

      if (res.status == 'error' || res.imageUrl.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showFriendlyError(
            'photo_edit_failed_spoken'.tr(),
            () => _applyPhotoEditPrompt(promptText, audioPath: audioPath),
          );
        }
        return;
      }

      // Vision fidelity check
      final fidelity = await _editorService.checkFidelity(_imageId);
      final hasProductAlteredWarning = res.warnProductChange ||
          fidelity['product_changed'] == true ||
          (fidelity['confidence'] != null && (fidelity['confidence'] as num) < 0.6);

      if (mounted) {
        PaintingBinding.instance.imageCache.clear();
        setState(() {
          _isLoading = false;
          _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
          _editedPhotoPath = res.imageUrl;
          _editHistory.add(res.imageUrl);
        });

        if (hasProductAlteredWarning && !_fidelityWarningShown) {
          _showProductChangeWarningDialog(res.productWarning ?? fidelity['warning']?.toString());
        } else {
          await SimpleModeVoiceHelper.playSuccessFeedback(
            context,
            'photo_edit_success_spoken'.tr(),
          );
        }
        await _saveDraft();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFriendlyError(
          'photo_edit_failed_spoken'.tr(),
          () => _applyPhotoEditPrompt(promptText, audioPath: audioPath),
        );
      }
    }
  }

  void _showProductChangeWarningDialog(String? customWarning) {
    _fidelityWarningShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.craftTerracotta, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'product_change_warning_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          customWarning ?? 'product_change_warning_msg'.tr(),
          style: AppTextStyles.bodyMedium(color: AppColors.inkPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleResetPhoto();
            },
            child: Text(
              'cancel_product_change_btn'.tr(),
              style: AppTextStyles.labelLarge(color: AppColors.inkSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.craftTerracotta,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('confirm_product_change_btn'.tr()),
          ),
        ],
      ),
    );
  }

  void _handleUndoPhoto() {
    if (_editHistory.length > 1) {
      setState(() {
        _editHistory.removeLast();
        _editedPhotoPath = _editHistory.last == _rawPhotoPath ? null : _editHistory.last;
      });
      _saveDraft();
    }
  }

  void _handleResetPhoto() {
    setState(() {
      _editedPhotoPath = null;
      _editHistory.clear();
      if (_rawPhotoPath != null) _editHistory.add(_rawPhotoPath!);
    });
    _saveDraft();
  }

  void _confirmAndAdvanceFromPhoto() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 2; // Advance to Screen 2: Details
      _isEditingPhoto = false;
    });
    await _saveDraft();
    _speakCurrentStepInstruction();
  }

  // =========================================================================
  // SCREEN 2: DETAILS LOGIC
  // =========================================================================

  Future<void> _recordField(String fieldType) async {
    final lang = _safeLang(context);

    if (_activeRecordingField == fieldType) {
      // Stop recording
      final path = await _audioService.stopRecording();
      setState(() {
        _activeRecordingField = null;
        _isLoading = true;
        _statusText = 'transcribing_audio'.tr();
        _errorMessage = null;
      });

      if (path != null) {
        try {
          final res = await _catalogRepo.transcribeAudio(
            filePath: path,
            languageHint: lang,
          );
          await AudioRecordingService.deleteAudioFile(path);

          if (mounted) {
            setState(() {
              if (fieldType == 'name') {
                _verbatimName = res.text;
                if (_cleanedTitle.isEmpty) _cleanedTitle = res.text;
              } else {
                _verbatimDesc = res.text;
                if (_cleanedDesc.isEmpty) _cleanedDesc = res.text;
              }
              _statusText = 'generating_catalog_msg'.tr();
            });

            // Generate clean 6-language listing
            final transcriptCombined = '$_verbatimName. $_verbatimDesc'.trim();
            final listing = await _catalogRepo.generateCatalog(
              transcript: transcriptCombined.isNotEmpty ? transcriptCombined : 'Handcrafted craft',
              sourceLang: res.detectedLang,
              category: _detectedCategory,
            );

            setState(() {
              _listingResult = listing;
              _cleanedTitle = listing.master.title;
              _cleanedDesc = listing.master.shortDescription;
              _isLoading = false;
            });

            await _saveDraft();
            if (mounted) {
              await SimpleModeVoiceHelper.playSuccessFeedback(
                context,
                'product_card_ready_spoken'.tr(),
              );
            }
          }
        } catch (_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showFriendlyError('could_not_hear_voice'.tr(), () => _recordField(fieldType));
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      // Start recording
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
      if (path != null && mounted) {
        setState(() {
          _activeRecordingField = fieldType;
        });
      }
    }
  }

  void _requestDetailsVoiceRefinement() async {
    final hasPerm = await _audioService.hasPermission();
    if (!hasPerm) return;

    final path = await _audioService.startRecording();
    if (path == null) return;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('speak_your_change'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: AppColors.craftTerracotta, size: 48),
            const SizedBox(height: 12),
            Text('voice_change_hint'.tr(), style: AppTextStyles.bodyMedium()),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              final lang = _safeLang(context);
              Navigator.of(ctx).pop();
              final recorded = await _audioService.stopRecording();
              if (recorded != null) {
                setState(() {
                  _isLoading = true;
                  _statusText = 'Updating with Gemini...';
                });
                try {
                  final trans = await _catalogRepo.transcribeAudio(
                    filePath: recorded,
                    languageHint: lang,
                  );
                  if (trans.text.isNotEmpty && mounted) {
                    final currentMap = <String, dynamic>{
                      'title': _cleanedTitle,
                      'short_description': _cleanedDesc,
                      'long_description': _listingResult?.master.longDescription ?? _cleanedDesc,
                      'materials': _listingResult?.master.materials.join(', ') ?? 'Clay',
                      'care_instructions': _listingResult?.master.careInstructions ?? '',
                    };

                    final refined = await _catalogRepo.refineCatalog(
                      currentListing: currentMap,
                      feedback: trans.text,
                      sourceLang: lang,
                      category: _detectedCategory,
                    );

                    setState(() {
                      _listingResult = refined;
                      _cleanedTitle = refined.master.title;
                      _cleanedDesc = refined.master.shortDescription;
                      _isLoading = false;
                    });

                    await _saveDraft();
                    if (!mounted) return;
                    await SimpleModeVoiceHelper.playSuccessFeedback(
                      context,
                      'change_applied_spoken'.tr(),
                    );
                  } else {
                    setState(() => _isLoading = false);
                  }
                } catch (_) {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
  }

  void _readAloudDetails() {
    final text = '$_cleanedTitle. $_cleanedDesc';
    SimpleModeVoiceHelper.autoSpeakScreenInstruction(context, text);
  }

  void _confirmAndAdvanceFromDetails() async {
    if (_cleanedTitle.trim().isEmpty) {
      _cleanedTitle = 'Handcrafted ${_detectedCategory.capitalize()}';
    }
    if (_cleanedDesc.trim().isEmpty) {
      _cleanedDesc = 'Authentic handcrafted $_detectedCategory made with traditional technique.';
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _currentStep = 3; // Advance to Screen 3: Price
      _priceQuestionIndex = 1;
      _keypadInput = _materialCost.toInt().toString();
    });
    await _saveDraft();
    _speakCurrentStepInstruction();
  }

  // =========================================================================
  // SCREEN 3: PRICE LOGIC
  // =========================================================================

  void _handleKeypadDigit(String digit) {
    setState(() {
      if (_keypadInput == '0' || _keypadInput.isEmpty) {
        _keypadInput = digit;
      } else if (_keypadInput.length < 6) {
        _keypadInput += digit;
      }
      _syncCurrentQuestionFromKeypad();
    });
  }

  void _handleKeypadBackspace() {
    setState(() {
      if (_keypadInput.isNotEmpty) {
        _keypadInput = _keypadInput.substring(0, _keypadInput.length - 1);
        if (_keypadInput.isEmpty) _keypadInput = '0';
      }
      _syncCurrentQuestionFromKeypad();
    });
  }

  void _handleKeypadClear() {
    setState(() {
      _keypadInput = '0';
      _syncCurrentQuestionFromKeypad();
    });
  }

  void _syncCurrentQuestionFromKeypad() {
    final val = double.tryParse(_keypadInput) ?? 0.0;
    if (_priceQuestionIndex == 1) {
      _materialCost = val;
    } else if (_priceQuestionIndex == 2) {
      _labourHours = val;
    } else if (_priceQuestionIndex == 3) {
      _otherCost = val;
    }
  }

  void _advancePriceQuestion() {
    HapticFeedback.lightImpact();
    if (_priceQuestionIndex == 1) {
      setState(() {
        _priceQuestionIndex = 2;
        _keypadInput = _labourHours.toStringAsFixed(0);
      });
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'price_q2_prompt'.tr(),
      );
    } else if (_priceQuestionIndex == 2) {
      setState(() {
        _priceQuestionIndex = 3;
        _keypadInput = _otherCost.toStringAsFixed(0);
      });
      SimpleModeVoiceHelper.autoSpeakScreenInstruction(
        context,
        'price_q3_prompt'.tr(),
      );
    } else {
      // Calculate final pricing suggestion!
      _calculateAndShowPricing();
    }
  }

  Future<void> _calculateAndShowPricing() async {
    setState(() {
      _isLoading = true;
      _statusText = 'price_calculating_msg'.tr();
      _errorMessage = null;
    });

    try {
      final lang = _safeLang(context);
      final res = await _pricingService.suggestPrice(
        category: _detectedCategory,
        materials: ['Clay', 'Natural Dye'],
        materialCost: _materialCost,
        labourHours: _labourHours,
        otherCost: _otherCost,
        lang: lang,
      );

      if (mounted) {
        setState(() {
          _costFloor = res.floor;
          _budgetPrice = res.budget;
          _recommendedPrice = res.recommended;
          _premiumPrice = res.premium;
          _selectedPrice = res.recommended;
          _pricingConfidence = res.confidence;
          _isEstimate = res.confidence < 0.8;
          _priceQuestionIndex = 4; // Completed questions, show breakdown
          _isLoading = false;
        });

        await _saveDraft();
        if (mounted) {
          await SimpleModeVoiceHelper.playSuccessFeedback(
            context,
            'fair_price_calculated_spoken'.tr(),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        // Safe offline calculation formula
        final labourCost = _labourHours * 95.0;
        final baseFloor = ((_materialCost + labourCost + _otherCost) * 1.10).ceil();
        setState(() {
          _costFloor = baseFloor;
          _budgetPrice = baseFloor;
          _recommendedPrice = (baseFloor * 1.25).round();
          _premiumPrice = (baseFloor * 1.50).round();
          _selectedPrice = _recommendedPrice;
          _priceQuestionIndex = 4;
          _isEstimate = true;
          _isLoading = false;
        });
        await _saveDraft();
      }
    }
  }

  void _showAdjustPriceModal() {
    int tempPrice = _selectedPrice;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('adjust_price_title'.tr(), style: AppTextStyles.titleMedium()),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 40, color: AppColors.primary),
                    onPressed: () {
                      if (tempPrice > 50) {
                        setModalState(() => tempPrice -= 50);
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '₹$tempPrice',
                    style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(fontSize: 38),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 40, color: AppColors.primary),
                    onPressed: () {
                      setModalState(() => tempPrice += 50);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'confirm_price'.tr(),
                variant: AppButtonVariant.primary,
                minHeight: 56.0,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _setCustomPrice(tempPrice);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setCustomPrice(int newPrice) {
    if (newPrice < _costFloor) {
      _showBelowFloorWarningDialog(newPrice);
    } else {
      setState(() => _selectedPrice = newPrice);
      _saveDraft();
    }
  }

  void _showBelowFloorWarningDialog(int targetPrice) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.statusError, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'below_floor_warning'.tr(namedArgs: {'floor': '$_costFloor'}),
                style: AppTextStyles.titleSmall(color: AppColors.statusError),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('dialog_ok'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusError,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _selectedPrice = targetPrice);
              _saveDraft();
            },
            child: Text('confirm_below_floor_btn'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmAndAdvanceFromPrice() async {
    HapticFeedback.mediumImpact();
    await StorageService.saveAcceptedPrice(_selectedPrice);
    setState(() {
      _currentStep = 4; // Advance to Screen 4: Publish
    });
    await _saveDraft();
    _speakCurrentStepInstruction();
  }

  // =========================================================================
  // SCREEN 4: PUBLISH LOGIC
  // =========================================================================

  void _handleGoBackPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'choose_step_to_edit'.tr(),
              style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: Text('edit_photo_choice'.tr(), style: AppTextStyles.titleSmall()),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _currentStep = 1);
                _speakCurrentStepInstruction();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.edit_note_rounded, color: AppColors.primary),
              ),
              title: Text('edit_details_choice'.tr(), style: AppTextStyles.titleSmall()),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _currentStep = 2);
                _speakCurrentStepInstruction();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.currency_rupee_rounded, color: AppColors.primary),
              ),
              title: Text('edit_price_choice'.tr(), style: AppTextStyles.titleSmall()),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _currentStep = 3;
                  _priceQuestionIndex = 4;
                });
                _speakCurrentStepInstruction();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    // Strict publish guard
    if (_rawPhotoPath == null || _cleanedTitle.trim().isEmpty || _selectedPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('publish_guard_msg'.tr()),
          backgroundColor: AppColors.statusError,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = 'publishing_progress'.tr();
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final prodId = 'prod_${now.millisecondsSinceEpoch}';
      final heroUrl = _editedPhotoPath ?? _rawPhotoPath ?? '';
      final titleText = _cleanedTitle;
      final descText = _cleanedDesc;

      // 1. Upsert into Drift SQLite
      final db = AppDatabase();
      final localProd = LocalProduct(
        id: prodId,
        artisanId: StorageService.artisanId ?? 'artisan_local',
        category: _detectedCategory,
        price: _selectedPrice.toDouble(),
        costPrice: _costFloor.toDouble(),
        status: 'live',
        stockQuantity: 1,
        primaryImageUrl: _rawPhotoPath,
        enhancedImageUrl: heroUrl,
        createdAt: now,
        updatedAt: now,
      );

      final curLang = _safeLang(context);
      final translation = LocalProductTranslation(
        id: 'trans_${now.millisecondsSinceEpoch}',
        productId: prodId,
        languageCode: curLang,
        title: titleText,
        description: descText,
        tags: 'handmade,craft,$_detectedCategory,new',
        materials: _listingResult?.master.materials.join(', ') ?? 'Natural materials',
        careInstructions: _listingResult?.master.careInstructions ?? 'Wipe clean',
      );

      await db.upsertProduct(localProd);
      await db.upsertTranslation(translation);

      // 2. Prepare 6-language translations payload
      final translationsPayload = <String, dynamic>{
        curLang: {
          'title': titleText,
          'description': descText,
          'materials': _listingResult?.master.materials.join(', ') ?? 'Natural materials',
          'care_instructions': _listingResult?.master.careInstructions ?? 'Wipe clean',
        },
      };

      if (_listingResult?.translations != null) {
        _listingResult!.translations.forEach((lCode, item) {
          translationsPayload[lCode] = {
            'title': item.title,
            'description': item.shortDescription,
            'materials': item.materials.join(', '),
            'care_instructions': item.careInstructions,
          };
        });
      }

      // 3. Sync to Backend
      try {
        await _productRepo.createProductWithTranslations(
          category: _detectedCategory,
          price: _selectedPrice.toDouble(),
          costPrice: _costFloor.toDouble(),
          primaryImageUrl: heroUrl.isNotEmpty ? heroUrl : _rawPhotoPath,
          translations: translationsPayload,
        );
      } catch (_) {
        // Offline resilience: Safe offline preservation in Drift
      }

      // Clear draft
      await StorageService.clearProductDraft();

      if (!mounted) return;
      await SimpleModeVoiceHelper.playSuccessFeedback(
        context,
        'product_published_spoken'.tr(),
      );

      if (!mounted) return;
      // Navigate to Published Success Screen (from which 'Go to My Shop' opens catalogue with product at top)
      context.go(
        '/product/published-success?product_id=$prodId&title=${Uri.encodeComponent(titleText)}&price=$_selectedPrice&image_url=${Uri.encodeComponent(heroUrl)}',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFriendlyError('could_not_publish_msg'.tr(), _handlePublish);
      }
    }
  }

  void _showFriendlyError(String message, VoidCallback onRetry) {
    setState(() {
      _errorMessage = message;
      _pendingRetryAction = onRetry;
    });
    SimpleModeVoiceHelper.autoSpeakScreenInstruction(context, message);
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final currentLang = _safeLang(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.inkPrimary),
                onPressed: () {
                  if (_currentStep > 1) {
                    setState(() => _currentStep--);
                    _speakCurrentStepInstruction();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
              ),
              title: Text(
                'sell_a_product_title'.tr(),
                style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SpeakerAffordance(
                    textToSpeak: _getInstructionForCurrentStep(),
                    languageCode: currentLang,
                    label: 'listen_instruction'.tr(),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusText ?? 'processing'.tr(),
                      style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 96.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step Progress Bar (4 steps: Photo, Details, Price, Publish)
                    StepProgressBar(
                      currentStep: _currentStep,
                      totalSteps: 4,
                      stepLabels: StepProgressBar.fourStepLabels,
                      stepIcons: StepProgressBar.fourStepIcons,
                      onStepTapped: (step) {
                        if (step < _currentStep) {
                          setState(() => _currentStep = step);
                          _speakCurrentStepInstruction();
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Instruction Banner with Replay Button
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(color: AppColors.primaryLight, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getInstructionForCurrentStep(),
                              style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay_rounded, color: AppColors.primary),
                            tooltip: 'replay_instruction'.tr(),
                            onPressed: _speakCurrentStepInstruction,
                          ),
                        ],
                      ),
                    ),

                    // Friendly Error Banner if any
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.statusError.withValues(alpha: 0.1),
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(color: AppColors.statusError),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.statusError),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.bodyMedium(color: AppColors.statusError),
                              ),
                            ),
                            if (_pendingRetryAction != null)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusError,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                                ),
                                onPressed: () {
                                  final retry = _pendingRetryAction;
                                  setState(() {
                                    _errorMessage = null;
                                    _pendingRetryAction = null;
                                  });
                                  retry?.call();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: Text('try_again_btn'.tr()),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Step View Rendering
                    if (_currentStep == 1) _buildScreen1Photo(),
                    if (_currentStep == 2) _buildScreen2Details(),
                    if (_currentStep == 3) _buildScreen3Price(),
                    if (_currentStep == 4) _buildScreen4Publish(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPhotoWidget(String path, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
    if (path.isEmpty) return Container(color: AppColors.surface, height: height, width: width);
    final resolved = ApiClient().resolveMediaUrl(path);
    if (path.startsWith('http') || path.startsWith('/static')) {
      final cacheBusted = resolved.contains('?')
          ? '$resolved&t=$_imageTimestamp'
          : '$resolved?t=$_imageTimestamp';
      return Image.network(
        cacheBusted,
        key: ValueKey(cacheBusted),
        fit: fit,
        height: height,
        width: width,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
        ),
      );
    }
    return Image.file(
      File(path),
      key: ValueKey('$path-$_imageTimestamp'),
      fit: fit,
      height: height,
      width: width,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.inkSecondary, size: 40),
      ),
    );
  }

  // =========================================================================
  // SCREEN 1: PHOTO VIEW
  // =========================================================================
  Widget _buildScreen1Photo() {
    final photo = _editedPhotoPath ?? _rawPhotoPath;

    if (photo == null) {
      // Empty state: Take photo or upload
      return Column(
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'step1_photo_instruction'.tr(),
                    style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 64 dp Giant Camera Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                elevation: 2,
              ),
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_rounded, size: 30),
              label: Text('take_photo_btn'.tr(), style: AppTextStyles.titleLarge(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),

          // 56 dp Secondary Gallery Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                backgroundColor: AppColors.surface,
              ),
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 24, color: AppColors.primary),
              label: Text('upload_gallery_btn'.tr(), style: AppTextStyles.titleMedium(color: AppColors.primary)),
            ),
          ),
        ],
      );
    }

    // Photo is selected: Show Preview or Compare Slider
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editedPhotoPath != null && _rawPhotoPath != null) ...[
          // Before/After comparison slider
          ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: ImageCompareSlider(
              height: 260,
              beforeWidget: _buildPhotoWidget(_rawPhotoPath!),
              afterWidget: _buildPhotoWidget(_editedPhotoPath!),
              beforeLabel: 'Original',
              afterLabel: 'AI Scene',
            ),
          ),
        ] else ...[
          // Large photo preview
          ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: _buildPhotoWidget(photo, height: 260, width: double.infinity),
          ),
        ],
        const SizedBox(height: 12),

        // Photo Edit Control Panel
        if (_isEditingPhoto) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.secondary, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'voice_edit_hint'.tr(),
                  style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
                ),
                const SizedBox(height: 12),

                // Voice Mic Button for prompt
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecordingPhotoEdit ? AppColors.craftTerracotta : AppColors.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                    ),
                    onPressed: () async {
                      if (_isRecordingPhotoEdit) {
                        final recPath = await _audioService.stopRecording();
                        setState(() => _isRecordingPhotoEdit = false);
                        if (recPath != null) {
                          _applyPhotoEditPrompt('', audioPath: recPath);
                        }
                      } else {
                        final hasPerm = await _audioService.hasPermission();
                        if (!hasPerm) return;
                        final recPath = await _audioService.startRecording();
                        if (recPath != null) {
                          setState(() => _isRecordingPhotoEdit = true);
                        }
                      }
                    },
                    icon: Icon(_isRecordingPhotoEdit ? Icons.stop_rounded : Icons.mic_rounded, size: 26),
                    label: Text(
                      _isRecordingPhotoEdit ? 'tap_to_finish'.tr() : 'speak_edit_btn'.tr(),
                      style: AppTextStyles.titleMedium(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Preset Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('White background'),
                      onPressed: () => _applyPhotoEditPrompt('remove background and make background clean white'),
                    ),
                    ActionChip(
                      label: const Text('Wooden table'),
                      onPressed: () => _applyPhotoEditPrompt('place on warm rustic polished wooden craft table'),
                    ),
                    ActionChip(
                      label: const Text('Brighter light'),
                      onPressed: () => _applyPhotoEditPrompt('enhance lighting balanced bright warm sunlight'),
                    ),
                    ActionChip(
                      label: const Text('Soft shadow'),
                      onPressed: () => _applyPhotoEditPrompt('add soft natural grounding shadow below product'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Undo / Reset Actions
                Row(
                  children: [
                    if (_editHistory.length > 1)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleUndoPhoto,
                          icon: const Icon(Icons.undo_rounded, size: 20),
                          label: Text('undo_btn'.tr()),
                        ),
                      ),
                    if (_editHistory.length > 1) const SizedBox(width: 8),
                    if (_editedPhotoPath != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleResetPhoto,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text('reset_btn'.tr()),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 64 dp Giant "Use this photo" (or "Yes, this is good") Button
        SizedBox(
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusOnline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              elevation: 2,
            ),
            onPressed: _confirmAndAdvanceFromPhoto,
            icon: const Icon(Icons.check_circle_rounded, size: 28),
            label: Text(
              _editedPhotoPath != null ? 'yes_this_is_good'.tr() : 'use_this_photo'.tr(),
              style: AppTextStyles.titleLarge(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 56 dp "Edit this photo" Button
        if (!_isEditingPhoto) ...[
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.secondary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                backgroundColor: AppColors.surface,
              ),
              onPressed: () => setState(() => _isEditingPhoto = true),
              icon: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 24),
              label: Text('edit_this_photo'.tr(), style: AppTextStyles.titleMedium(color: AppColors.secondary)),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Retake Button
        Center(
          child: TextButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.inkSecondary),
            label: Text('take_photo_btn'.tr(), style: AppTextStyles.labelLarge(color: AppColors.inkSecondary)),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SCREEN 2: DETAILS VIEW
  // =========================================================================
  Widget _buildScreen2Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two Big Mic Cards
        Row(
          children: [
            // Name Mic
            Expanded(
              child: _buildMicCard(
                title: 'speak_product_name'.tr(),
                hint: 'tap_to_speak_name'.tr(),
                isRecording: _activeRecordingField == 'name',
                onTap: () => _recordField('name'),
              ),
            ),
            const SizedBox(width: 12),
            // Description Mic
            Expanded(
              child: _buildMicCard(
                title: 'speak_product_desc'.tr(),
                hint: 'tap_to_speak_desc'.tr(),
                isRecording: _activeRecordingField == 'desc',
                onTap: () => _recordField('desc'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Verbatim words display if artisan spoke
        if (_verbatimName.isNotEmpty || _verbatimDesc.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'artisan_original_words'.tr(),
                  style: AppTextStyles.labelSmall(color: AppColors.secondary).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (_verbatimName.isNotEmpty)
                  Text('"${_verbatimName.trim()}"', style: AppTextStyles.bodySmall(color: AppColors.inkPrimary)),
                if (_verbatimDesc.isNotEmpty)
                  Text('"${_verbatimDesc.trim()}"', style: AppTextStyles.bodySmall(color: AppColors.inkSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Cleaned Listing Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: Text(
                      _detectedCategory.toUpperCase(),
                      style: AppTextStyles.labelSmall(color: AppColors.primaryDark).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                    tooltip: 'read_aloud_btn'.tr(),
                    onPressed: _readAloudDetails,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title (Tap to edit)
              InkWell(
                onTap: () => _editFieldDialog('title', _cleanedTitle),
                child: Text(
                  _cleanedTitle.isNotEmpty ? _cleanedTitle : 'Handcrafted ${_detectedCategory.capitalize()}',
                  style: AppTextStyles.displaySmall(color: AppColors.inkPrimary).copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(height: 8),

              // Description (Tap to edit)
              InkWell(
                onTap: () => _editFieldDialog('desc', _cleanedDesc),
                child: Text(
                  _cleanedDesc.isNotEmpty
                      ? _cleanedDesc
                      : 'Authentic handcrafted $_detectedCategory made with traditional technique.',
                  style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // 6 Languages Preview Chips
              Text(
                '6-Language Preview (runs in background):',
                style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['en', 'hi', 'ta', 'te', 'kn', 'ml'].map((langCode) {
                    final isSel = _previewLanguage == langCode;
                    final names = {
                      'en': 'EN (English)',
                      'hi': 'HI (हिन्दी)',
                      'ta': 'TA (தமிழ்)',
                      'te': 'TE (తెలుగు)',
                      'kn': 'KN (ಕನ್ನಡ)',
                      'ml': 'ML (മലയാളം)',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(names[langCode] ?? langCode.toUpperCase()),
                        selected: isSel,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _previewLanguage = langCode);
                            final trans = _listingResult?.translations[langCode];
                            if (trans != null) {
                              SimpleModeVoiceHelper.autoSpeakScreenInstruction(
                                context,
                                '${trans.title}. ${trans.shortDescription}',
                              );
                            }
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 64 dp Giant "Yes, this is good" Button
        SizedBox(
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusOnline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              elevation: 2,
            ),
            onPressed: _confirmAndAdvanceFromDetails,
            icon: const Icon(Icons.check_circle_rounded, size: 28),
            label: Text('yes_this_is_good'.tr(), style: AppTextStyles.titleLarge(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // 56 dp "No, change it" (mic spoken changes)
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.secondary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              backgroundColor: AppColors.surface,
            ),
            onPressed: _requestDetailsVoiceRefinement,
            icon: const Icon(Icons.mic_rounded, size: 24, color: AppColors.secondary),
            label: Text('no_change_it'.tr(), style: AppTextStyles.titleMedium(color: AppColors.secondary)),
          ),
        ),
      ],
    );
  }

  Widget _buildMicCard({
    required String title,
    required String hint,
    required bool isRecording,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRecording ? AppColors.craftTerracotta.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(
            color: isRecording ? AppColors.craftTerracotta : AppColors.primary,
            width: isRecording ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isRecording ? AppColors.craftTerracotta : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _editFieldDialog(String field, String currentVal) {
    final controller = TextEditingController(text: currentVal);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(field == 'title' ? 'speak_product_name'.tr() : 'speak_product_desc'.tr()),
        content: TextField(
          controller: controller,
          maxLines: field == 'title' ? 2 : 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('dialog_ok'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                if (field == 'title') {
                  _cleanedTitle = controller.text;
                } else {
                  _cleanedDesc = controller.text;
                }
              });
              _saveDraft();
            },
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SCREEN 3: PRICE VIEW
  // =========================================================================
  Widget _buildScreen3Price() {
    if (_priceQuestionIndex <= 3) {
      // 3 Sequential Cost Questions
      String qTitle;
      String qPrompt;
      String currentDisplay;
      List<String> presetChips;

      if (_priceQuestionIndex == 1) {
        qTitle = 'price_q1_title'.tr();
        qPrompt = 'price_q1_prompt'.tr();
        currentDisplay = '₹$_keypadInput';
        presetChips = ['₹50', '₹100', '₹200', '₹500'];
      } else if (_priceQuestionIndex == 2) {
        qTitle = 'price_q2_title'.tr();
        qPrompt = 'price_q2_prompt'.tr();
        final hours = double.tryParse(_keypadInput) ?? 0.0;
        final wageVal = (hours * 95.0).round();
        currentDisplay = '$hours hrs (₹$wageVal)';
        presetChips = ['1 hr', '2 hrs', '4 hrs', '8 hrs'];
      } else {
        qTitle = 'price_q3_title'.tr();
        qPrompt = 'price_q3_prompt'.tr();
        currentDisplay = '₹$_keypadInput';
        presetChips = ['₹0', '₹20', '₹50', '₹100'];
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                Text(
                  'Question $_priceQuestionIndex of 3: $qTitle',
                  style: AppTextStyles.labelMedium(color: AppColors.secondary).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  qPrompt,
                  style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  currentDisplay,
                  style: AppTextStyles.displaySmall(color: AppColors.craftTerracotta).copyWith(fontSize: 38),
                ),
                if (_priceQuestionIndex == 2) ...[
                  const SizedBox(height: 4),
                  Text(
                    'fair_wage_info'.tr(),
                    style: AppTextStyles.labelSmall(color: AppColors.inkSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preset Chips
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: presetChips.map((chipText) {
              return ActionChip(
                label: Text(chipText, style: AppTextStyles.labelLarge(color: AppColors.primary)),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                onPressed: () {
                  final numVal = chipText.replaceAll(RegExp(r'[^0-9]'), '');
                  setState(() {
                    _keypadInput = numVal.isEmpty ? '0' : numVal;
                    _syncCurrentQuestionFromKeypad();
                  });
                },
              );
            }).toList(),
          ),

          // None (₹0) Button on Question 3
          if (_priceQuestionIndex == 3) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.inkSecondary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
                ),
                onPressed: () {
                  setState(() {
                    _keypadInput = '0';
                    _otherCost = 0.0;
                  });
                  _advancePriceQuestion();
                },
                child: Text('none_cost_btn'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Big Numeric Keypad
          BigNumericKeypad(
            onDigitPressed: _handleKeypadDigit,
            onBackspacePressed: _handleKeypadBackspace,
            onClearPressed: _handleKeypadClear,
          ),
          const SizedBox(height: 16),

          // 56 dp "Next Question" or "Calculate" Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              ),
              onPressed: _advancePriceQuestion,
              child: Text(
                _priceQuestionIndex == 3 ? 'Calculate Fair Price' : 'next_question_btn'.tr(),
                style: AppTextStyles.titleMedium(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    // Step 3 Breakdown & 3-Tier Suggestion
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3 Tiers Selector
        Row(
          children: [
            _buildPriceTierCard('Budget', _budgetPrice, isRecommended: false),
            const SizedBox(width: 8),
            _buildPriceTierCard('Recommended', _recommendedPrice, isRecommended: true),
            const SizedBox(width: 8),
            _buildPriceTierCard('Premium', _premiumPrice, isRecommended: false),
          ],
        ),
        const SizedBox(height: 14),

        // Cost Floor Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.primaryDark),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.primaryDark, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('cost_floor_label'.tr(), style: AppTextStyles.labelSmall(color: AppColors.primaryDark)),
                    Text(
                      '₹$_costFloor (materials + labour + overhead)',
                      style: AppTextStyles.titleSmall(color: AppColors.primaryDark).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Text(
                  '${'confidence_label'.tr()}: ${(_pricingConfidence * 100).toInt()}%',
                  style: AppTextStyles.labelSmall(color: AppColors.primaryDark).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (_isEstimate) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.craftOchre.withValues(alpha: 0.2),
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    'evidence_estimate_badge'.tr(),
                    style: AppTextStyles.labelSmall(color: AppColors.craftTerracotta).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('breakdown_title'.tr(), style: AppTextStyles.titleSmall(color: AppColors.inkPrimary)),
              const Divider(height: 16),
              _buildBreakdownRow('breakdown_materials'.tr(), '₹${_materialCost.round()}'),
              _buildBreakdownRow('breakdown_labour'.tr(), '₹${(_labourHours * 95.0).round()} (${_labourHours}h)'),
              _buildBreakdownRow('breakdown_other'.tr(), '₹${_otherCost.round()}'),
              _buildBreakdownRow('breakdown_overhead'.tr(), '₹${((_materialCost + _labourHours * 95.0 + _otherCost) * 0.10).round()}'),
              _buildBreakdownRow('breakdown_profit'.tr(), '₹${(_selectedPrice - _costFloor).clamp(0, 999999)}', isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 64 dp Giant "Yes, use this price" Button
        SizedBox(
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusOnline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              elevation: 2,
            ),
            onPressed: _confirmAndAdvanceFromPrice,
            icon: const Icon(Icons.check_circle_rounded, size: 28),
            label: Text('yes_use_price'.tr(), style: AppTextStyles.titleLarge(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // 56 dp "Change price" Button
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.hairline, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              backgroundColor: AppColors.surface,
            ),
            onPressed: _showAdjustPriceModal,
            icon: const Icon(Icons.edit_rounded, color: AppColors.inkSecondary),
            label: Text('change_price_btn'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceTierCard(String tierName, int price, {required bool isRecommended}) {
    final isSelected = _selectedPrice == price;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPrice = price);
          _saveDraft();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondaryLight : AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.hairline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                tierName,
                style: AppTextStyles.labelSmall(
                  color: isSelected ? AppColors.secondary : AppColors.inkSecondary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '₹$price',
                style: AppTextStyles.titleMedium(
                  color: isSelected ? AppColors.secondary : AppColors.inkPrimary,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold ? AppTextStyles.labelMedium(color: AppColors.inkPrimary).copyWith(fontWeight: FontWeight.bold) : AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          ),
          Text(
            value,
            style: isBold ? AppTextStyles.labelMedium(color: AppColors.craftTerracotta).copyWith(fontWeight: FontWeight.bold) : AppTextStyles.bodySmall(color: AppColors.inkPrimary),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SCREEN 4: PUBLISH VIEW
  // =========================================================================
  Widget _buildScreen4Publish() {
    final photo = _editedPhotoPath ?? _rawPhotoPath;

    // Localized description for buyer preview (can toggle between artisan lang and English/Hindi)
    String displayedDesc = _cleanedDesc;
    if (_buyerPreviewLang != 'en' && _listingResult?.translations[_buyerPreviewLang] != null) {
      displayedDesc = _listingResult!.translations[_buyerPreviewLang]!.shortDescription;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'publish_card_subtitle'.tr(),
          style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),

        // Finished Buyer Card Preview
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Header with Category Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: photo != null
                        ? _buildPhotoWidget(photo, height: 220, width: double.infinity)
                        : Container(height: 220, color: AppColors.background),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Text(
                        _detectedCategory.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              // Card Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _cleanedTitle,
                            style: AppTextStyles.serifCardTitle(color: AppColors.inkPrimary).copyWith(fontSize: 20),
                          ),
                        ),
                        Text(
                          '₹$_selectedPrice',
                          style: AppTextStyles.displaySmall(color: AppColors.craftTerracotta).copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Language switcher chips for preview
                    Row(
                      children: [
                        Text('Language:', style: AppTextStyles.labelSmall(color: AppColors.inkSecondary)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Local'),
                          selected: _buyerPreviewLang == 'en',
                          onSelected: (_) => setState(() => _buyerPreviewLang = 'en'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('हिन्दी'),
                          selected: _buyerPreviewLang == 'hi',
                          onSelected: (_) => setState(() => _buyerPreviewLang = 'hi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      displayedDesc,
                      style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Fair wage verified badge
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.statusOnline, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'fair_wage_guarantee_short'.tr(),
                          style: AppTextStyles.labelSmall(color: AppColors.statusOnline).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Giant 64 dp "Yes, publish" Button
        SizedBox(
          height: 64,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusOnline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              elevation: 3,
            ),
            onPressed: _handlePublish,
            icon: const Icon(Icons.rocket_launch_rounded, size: 30),
            label: Text('yes_publish_btn'.tr(), style: AppTextStyles.titleLarge(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // 56 dp "No, go back" Button (choose section to edit)
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.hairline, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
              backgroundColor: AppColors.surface,
            ),
            onPressed: _handleGoBackPicker,
            icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.inkSecondary),
            label: Text('no_go_back_btn'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
          ),
        ),
      ],
    );
  }
}

extension _StringExt on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
