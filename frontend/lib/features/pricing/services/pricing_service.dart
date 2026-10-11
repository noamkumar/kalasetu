library;

import '../../../data/api/api_client.dart';
import '../../../core/widgets/price_suggestion_card.dart';
import '../models/price_suggestion_result.dart';

class PricingService {
  final ApiClient _apiClient;

  PricingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Call POST /pricing/suggest to retrieve fair cost floor, market comparables,
  /// gradient-boosted prediction, and localized reasoning.
  Future<PriceSuggestionResult> suggestPrice({
    String? productId,
    required String category,
    required List<String> materials,
    required double materialCost,
    required double labourHours,
    double? rawMaterialCost,
    double? hoursOfWork,
    String? approvedImage,
    String? listingText,
    String? date,
    double? sizeCm,
    String? technique,
    String? region,
    double? qualityScore,
    double? userExpectedPrice,
    String lang = 'en',
    double otherCost = 0.0,
    double? otherProductCosts,
  }) async {
    try {
      final response = await _apiClient.post(
        '/pricing/suggest',
        body: {
          'product_id': productId,
          'category': category,
          'materials': materials,
          'material_cost': materialCost,
          'raw_material_cost': rawMaterialCost ?? materialCost,
          'labour_hours': labourHours,
          'hours_of_work': hoursOfWork ?? labourHours,
          'other_cost': otherProductCosts ?? otherCost,
          'other_product_costs': otherProductCosts ?? otherCost,
          'approved_image': approvedImage,
          'listing_text': listingText,
          'date': date,
          'size_cm': sizeCm ?? 25.0,
          'technique': technique,
          'region': region,
          'quality_score': qualityScore ?? 85.0,
          'user_expected_price': userExpectedPrice,
          'lang': lang,
        },
      );

      if (response is Map<String, dynamic>) {
        return PriceSuggestionResult.fromJson(response);
      }
      throw ApiException(message: 'Invalid response format from pricing endpoint');
    } catch (e) {
      if (e is ApiException && e.isNetworkError) {
        return _calculateLocalFallback(
          materialCost: materialCost,
          labourHours: labourHours,
          category: category,
          userExpectedPrice: userExpectedPrice,
          otherCost: otherProductCosts ?? otherCost,
        );
      }
      rethrow;
    }
  }

  /// Logs artisan feedback when accepting or editing price
  Future<void> sendFeedback({
    String? productId,
    required int recommendedPrice,
    required int chosenPrice,
    required String action,
    String? reason,
  }) async {
    try {
      await _apiClient.post(
        '/pricing/feedback',
        body: {
          'product_id': productId,
          'recommended_price': recommendedPrice,
          'chosen_price': chosenPrice,
          'action': action,
          'reason': reason,
        },
      );
    } catch (_) {
      // Best-effort logging; ignore errors
    }
  }

  PriceSuggestionResult _calculateLocalFallback({
    required double materialCost,
    required double labourHours,
    required String category,
    double? userExpectedPrice,
    double otherCost = 0.0,
  }) {
    const fairWage = 95.0;
    final labourCost = labourHours * fairWage;
    final baseSum = materialCost + labourCost + otherCost;
    final overhead = baseSum * 0.10;
    final floor = (baseSum + overhead).ceil();
    final recommended = (floor * 1.35).ceil();
    final budget = (floor * 1.15).ceil();
    final premium = (floor * 1.60).ceil();

    String? warning;
    if (userExpectedPrice != null && userExpectedPrice < floor) {
      warning = 'Your expected price of ₹${userExpectedPrice.toInt()} is below your cost floor of ₹$floor.';
    }

    return PriceSuggestionResult(
      floor: floor,
      budget: budget,
      recommended: recommended,
      premium: premium,
      confidence: 0.65,
      label: 'Estimate based on your costs only',
      hasComparables: false,
      breakdown: {
        'material_cost': materialCost,
        'labour_hours': labourHours,
        'labour_cost': labourCost,
        'overhead': overhead,
        'floor': floor,
      },
      factors: [
        PriceFactor(name: 'Raw materials', value: '₹${materialCost.toInt()}'),
        PriceFactor(name: 'Fair labour (${labourHours}h @ ₹${fairWage.toInt()}/h)', value: '₹${labourCost.toInt()}'),
        PriceFactor(name: 'Workshop overhead (10%)', value: '₹${overhead.toInt()}'),
        PriceFactor(name: 'Cost floor', value: '₹$floor'),
        PriceFactor(name: 'Artisan margin', value: '₹${recommended - floor}'),
      ],
      comparables: [],
      explanation: {
        'en': 'Calculated based on your materials and fair artisan labor hours (offline estimate).',
        'hi': 'आपकी सामग्री और उचित श्रम घंटों पर आधारित ऑफ़लाइन अनुमान।',
        'ta': 'உங்கள் மூலப்பொருட்கள் மற்றும் உழைப்பு நேரத்தின் அடிப்படையிலான ஆஃப்லைன் மதிப்பீடு.',
        'te': 'మీ ముడి సరుకులు మరియు శ్రమ గంటల ఆధారిత ఆఫ్‌లైన్ అంచనా.',
        'kn': 'ನಿಮ್ಮ ವಸ್ತುಗಳು ಮತ್ತು ಶ್ರಮದ ಸಮಯದ ಆಧಾರಿತ ಆಫ್‌ಲೈನ್ ಅಂದಾಜು.',
        'ml': 'നിങ്ങളുടെ സാമഗ്രികളും അധ്വാന സമയവും അടിസ്ഥാനമാക്കിയുള്ള ഓഫ്‌ലൈൻ കണക്കുകൂട്ടൽ.',
      },
      warning: warning,
    );
  }
}
