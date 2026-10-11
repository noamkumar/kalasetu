import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/price_suggestion_card.dart';
import 'package:frontend/core/widgets/speaker_affordance.dart';
import 'package:frontend/features/pricing/models/price_suggestion_result.dart';

void main() {
  group('PriceSuggestionCard & Dynamic Pricing Tests', () {
    testWidgets('PriceSuggestionCard renders recommended price and factors', (WidgetTester tester) async {
      bool accepted = false;
      bool spoke = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceSuggestionCard(
              recommendedPrice: 449,
              floorPrice: 340,
              budgetPrice: 399,
              premiumPrice: 549,
              confidence: 0.86,
              explanation: 'Calculated fair artisan price based on materials and 3 hours labour.',
              factors: const [
                PriceFactor(name: 'Raw materials', value: '₹80'),
                PriceFactor(name: 'Fair labour (3h @ ₹95/h)', value: '₹285'),
              ],
              comparables: const [
                ComparableItem(title: 'Earthen Jug', price: 480, similarity: 0.88),
              ],
              isBelowFloor: false,
              onAccept: () => accepted = true,
              onSpeak: () => spoke = true,
            ),
          ),
        ),
      );

      // Verify recommended price is prominently shown
      expect(find.text('₹449'), findsWidgets);
      expect(find.text('Recommended Price'), findsOneWidget);
      expect(find.text('₹399'), findsOneWidget);
      expect(find.text('₹549'), findsOneWidget);

      // Verify factors
      expect(find.text('Raw materials'), findsOneWidget);
      expect(find.text('₹80'), findsOneWidget);

      // Verify TTS speak button
      final speakerBtn = find.byType(SpeakerAffordance);
      expect(speakerBtn, findsOneWidget);
      await tester.tap(speakerBtn);
      await tester.pump();
      expect(spoke, isTrue);

      // Verify tap on Accept Price button
      final acceptBtn = find.text('Accept Price');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pump();
      expect(accepted, isTrue);
    });

    testWidgets('PriceSuggestionCard displays below-floor warning when isBelowFloor is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PriceSuggestionCard(
              recommendedPrice: 250,
              floorPrice: 340,
              budgetPrice: 220,
              premiumPrice: 290,
              confidence: 0.50,
              explanation: 'Expected price is below cost floor.',
              isBelowFloor: true,
            ),
          ),
        ),
      );

      // Verify floor warning text is present
      expect(find.textContaining('below your cost floor'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    test('PriceSuggestionResult JSON deserialization handles no-comparables case', () {
      final json = {
        'floor': 420,
        'budget': 499,
        'recommended': 599,
        'premium': 749,
        'confidence': 0.48,
        'label': 'Estimate based on your costs only',
        'has_comparables': false,
        'breakdown': {
          'material_cost': 120.0,
          'labour_hours': 3.0,
          'floor': 420,
        },
        'factors': [
          {'name': 'Raw materials', 'value': '₹120'},
        ],
        'comparables': [],
        'explanation': {
          'en': 'Estimate based on your costs only: ₹599 protects your ₹420 minimum production floor.',
          'hi': 'केवल आपकी लागत पर आधारित अनुमान: ₹599 आपके ₹420 न्यूनतम आधार की रक्षा करता है।'
        },
        'warning': null,
      };

      final result = PriceSuggestionResult.fromJson(json);
      expect(result.floor, 420);
      expect(result.recommended, 599);
      expect(result.hasComparables, isFalse);
      expect(result.label, 'Estimate based on your costs only');
      expect(result.confidence, 0.48);
      expect(result.comparables, isEmpty);
      expect(result.getExplanationForLang('hi'), contains('₹599'));
    });
  });
}
