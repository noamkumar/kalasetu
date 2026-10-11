import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/big_numeric_keypad.dart';
import '../../core/widgets/price_suggestion_card.dart';
import '../../core/widgets/step_progress_bar.dart';
import '../../data/repositories/catalog_repository.dart';
import 'models/price_suggestion_result.dart';
import 'services/pricing_service.dart';

/// KalaSetu Dynamic Pricing Assistant Screen
/// Section 9 of Project Specification
class PricingScreen extends StatefulWidget {
  final String category;
  final CatalogListingResult? listing;
  final String? imageUrl;

  const PricingScreen({
    super.key,
    this.category = 'pottery',
    this.listing,
    this.imageUrl,
  });

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final PricingService _pricingService = PricingService();
  final VoiceService _voiceService = VoiceService.instance;

  final TextEditingController _materialCostController = TextEditingController(text: '80');
  final TextEditingController _labourHoursController = TextEditingController(text: '3.0');
  final TextEditingController _expectedPriceController = TextEditingController();
  final TextEditingController _customAdjustController = TextEditingController();

  String _selectedRegion = 'TN';
  final List<String> _regions = ['TN', 'RJ', 'UP', 'WB', 'KL', 'GJ', 'KA', 'OR'];

  bool _isLoading = false;
  PriceSuggestionResult? _result;
  int? _selectedPrice;
  bool _isSpeaking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-calculate fair price on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPricingSuggestion();
    });
  }

  @override
  void dispose() {
    _materialCostController.dispose();
    _labourHoursController.dispose();
    _expectedPriceController.dispose();
    _customAdjustController.dispose();
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _fetchPricingSuggestion() async {
    final matCost = double.tryParse(_materialCostController.text.trim()) ?? 0.0;
    final labourHours = double.tryParse(_labourHoursController.text.trim()) ?? 1.0;
    final expectedPrice = double.tryParse(_expectedPriceController.text.trim());

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentLang = context.locale.languageCode;
      final materials = widget.listing?.master.materials ?? ['natural craft materials'];
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);

      final suggestion = await _pricingService.suggestPrice(
        category: widget.category,
        materials: materials,
        materialCost: matCost,
        labourHours: labourHours,
        rawMaterialCost: matCost,
        hoursOfWork: labourHours,
        approvedImage: widget.imageUrl,
        listingText: widget.listing?.master.title,
        region: _selectedRegion,
        date: todayDate,
        userExpectedPrice: expectedPrice,
        lang: currentLang,
      );

      if (mounted) {
        setState(() {
          _result = suggestion;
          _selectedPrice = suggestion.recommended;
          _customAdjustController.text = suggestion.recommended.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleVoiceEntry(TextEditingController controller, String title) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.mic, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium(color: AppColors.inkPrimary))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('voice_entry_hint'.tr(), style: AppTextStyles.bodyMedium(color: AppColors.inkSecondary)),
              const SizedBox(height: 16),
              // Quick voice chip presets for easy one-tap input
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['50', '100', '150', '250', '500', '750'].map((val) {
                  return ActionChip(
                    label: Text('₹$val'),
                    backgroundColor: AppColors.background,
                    onPressed: () {
                      controller.text = val;
                      Navigator.pop(ctx);
                      _fetchPricingSuggestion();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr(), style: AppTextStyles.labelMedium(color: AppColors.inkSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _speakExplanation() async {
    if (_result == null) return;
    final currentLang = context.locale.languageCode;
    final text = _result!.getExplanationForLang(currentLang);

    if (_isSpeaking) {
      await _voiceService.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _voiceService.speak(
        text: text,
        languageCode: currentLang,
        onComplete: () {
          if (mounted) setState(() => _isSpeaking = false);
        },
      );
    }
  }

  void _openNumericKeypadSheet(
    TextEditingController controller,
    String title, {
    int? minFloor,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String currentInput = controller.text.trim();
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final valNum = int.tryParse(currentInput) ?? 0;
            final isBelow = minFloor != null && valNum > 0 && valNum < minFloor;

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isBelow ? AppColors.statusError : AppColors.hairline,
                        width: isBelow ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      currentInput.isEmpty ? '₹ 0' : '₹ $currentInput',
                      style: AppTextStyles.displaySmall(
                        color: isBelow ? AppColors.statusError : AppColors.inkPrimary,
                      ).copyWith(fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isBelow) ...[
                    const SizedBox(height: 8),
                    Text(
                      'below_floor_warning'.tr(namedArgs: {'price': '$valNum', 'floor': '$minFloor'}),
                      style: AppTextStyles.labelSmall(color: AppColors.statusError),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  BigNumericKeypad(
                    onDigitPressed: (digit) {
                      setSheetState(() {
                        currentInput += digit;
                      });
                    },
                    onBackspacePressed: () {
                      if (currentInput.isNotEmpty) {
                        setSheetState(() {
                          currentInput = currentInput.substring(0, currentInput.length - 1);
                        });
                      }
                    },
                    onClearPressed: () {
                      setSheetState(() {
                        currentInput = '';
                      });
                    },
                    onVoicePressed: () {
                      Navigator.pop(sheetCtx);
                      _handleVoiceEntry(controller, title);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (currentInput.isNotEmpty) {
                          controller.text = currentInput;
                          if (minFloor != null) {
                            setState(() {
                              _selectedPrice = int.tryParse(currentInput);
                            });
                          } else {
                            _fetchPricingSuggestion();
                          }
                        }
                        Navigator.pop(sheetCtx);
                      },
                      child: Text('confirm'.tr(), style: AppTextStyles.labelLarge(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdjustDialog() {
    if (_result == null) return;
    _openNumericKeypadSheet(
      _customAdjustController,
      'adjust_price_title'.tr(),
      minFloor: _result!.floor,
    );
  }

  void _continueToReview() async {
    if (_result == null) return;
    final finalPrice = _selectedPrice ?? _result!.recommended;

    // Persist accepted price for earnings screen & calculate fair wage
    await StorageService.saveAcceptedPrice(finalPrice);

    // Log feedback
    final action = finalPrice == _result!.recommended
        ? 'accepted'
        : (finalPrice < _result!.recommended ? 'budget_adjusted' : 'premium_adjusted');

    _pricingService.sendFeedback(
      recommendedPrice: _result!.recommended,
      chosenPrice: finalPrice,
      action: action,
    );

    if (!mounted) return;
    if (widget.listing != null) {
      context.push(RouteNames.addReview, extra: {
        'category': widget.category,
        'listing': widget.listing,
        'price': finalPrice,
        'image_url': widget.imageUrl,
      });
    } else {
      context.pop(finalPrice);
    }
  }

  Widget _buildCostInputsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Craft Context Header (Image & Title preview if available)
          if (widget.listing != null || widget.imageUrl != null) ...[
            Row(
              children: [
                if (widget.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.imageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.palette_outlined, color: AppColors.primary),
                      ),
                    ),
                  ),
                if (widget.imageUrl != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.listing?.master.title ?? widget.category.toUpperCase(),
                        style: AppTextStyles.titleSmall(color: AppColors.inkPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.category.toUpperCase(),
                        style: AppTextStyles.labelSmall(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: AppColors.hairline),
          ],

          Text(
            'cost_breakdown_toggle'.tr(),
            style: AppTextStyles.titleMedium(color: AppColors.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'floor_price_guarantee_desc'.tr(),
            style: AppTextStyles.bodySmall(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 16),

          // Raw Material Cost input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _materialCostController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'raw_materials_cost'.tr(),
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.dialpad, color: AppColors.primary),
                tooltip: 'Big Keypad',
                onPressed: () => _openNumericKeypadSheet(_materialCostController, 'raw_materials_cost'.tr()),
              ),
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.primary),
                tooltip: 'voice_input_tooltip'.tr(),
                onPressed: () => _handleVoiceEntry(_materialCostController, 'raw_materials_cost'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Labour Hours input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labourHoursController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'labour_hours'.tr(),
                    suffixText: 'hrs',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.dialpad, color: AppColors.primary),
                tooltip: 'Big Keypad',
                onPressed: () => _openNumericKeypadSheet(_labourHoursController, 'labour_hours'.tr()),
              ),
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.primary),
                tooltip: 'voice_input_tooltip'.tr(),
                onPressed: () => _handleVoiceEntry(_labourHoursController, 'labour_hours'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Region & Date Selection
          Row(
            children: [
              Text('Region:', style: AppTextStyles.labelMedium(color: AppColors.inkPrimary)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _regions.map((reg) {
                      final isSelected = _selectedRegion == reg;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(reg),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.inkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedRegion = reg);
                              _fetchPricingSuggestion();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Expected Price (Optional)
          TextField(
            controller: _expectedPriceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'expected_price_label'.tr(),
              prefixText: '₹ ',
              hintText: 'expected_price_hint'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'suggest_fair_price_btn'.tr(),
            variant: AppButtonVariant.secondary,
            isLoading: _isLoading,
            onPressed: _fetchPricingSuggestion,
          ),
        ],
      ),
    );
  }

  Widget _buildBelowFloorWarningBanner(int chosen, int floor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusError.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.statusError.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.statusError, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'below_floor_warning'.tr(namedArgs: {'price': '$chosen', 'floor': '$floor'}),
              style: AppTextStyles.bodySmall(color: AppColors.statusError).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = context.locale.languageCode;
    final floorPrice = _result?.floor ?? 0;
    final effectivePrice = _selectedPrice ?? _result?.recommended ?? 0;
    final isBelowFloor = _result != null && effectivePrice < floorPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('pricing_title'.tr(), style: AppTextStyles.titleMedium(color: AppColors.inkPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepProgressBar(
              currentStep: 4,
              totalSteps: 5,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildCostInputsCard(),
            const SizedBox(height: AppSpacing.lg),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusError.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.statusError),
                ),
                child: Text(_errorMessage!, style: AppTextStyles.bodySmall(color: AppColors.statusError)),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('Calculating fair artisan price...'),
                    ],
                  ),
                ),
              )
            else if (_result != null) ...[
              if (isBelowFloor)
                _buildBelowFloorWarningBanner(effectivePrice, floorPrice),
              PriceSuggestionCard(
                recommendedPrice: _selectedPrice ?? _result!.recommended,
                floorPrice: _result!.floor,
                budgetPrice: _result!.budget,
                premiumPrice: _result!.premium,
                confidence: _result!.confidence,
                statusLabel: _result!.label,
                evidenceLevel: _result!.evidenceLevel,
                impactMessage: _result!.impactMessage,
                explanation: _result!.getExplanationForLang(currentLang),
                factors: _result!.factors,
                comparables: _result!.comparables,
                isBelowFloor: isBelowFloor,
                isSpeaking: _isSpeaking,
                onSelectPrice: (p) => setState(() => _selectedPrice = p),
                onSpeak: _speakExplanation,
                onEdit: _showAdjustDialog,
                onAccept: _continueToReview,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'accept_and_continue'.tr(),
                variant: AppButtonVariant.primary,
                onPressed: _continueToReview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
