import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/core/widgets/connectivity_pill.dart';
import 'package:frontend/core/widgets/craft_category_badge.dart';
import 'package:frontend/core/widgets/speaker_affordance.dart';
import 'package:frontend/core/widgets/step_progress_bar.dart';
import 'package:frontend/core/widgets/language_picker.dart';
import 'package:frontend/core/widgets/empty_craft_state.dart';
import 'package:frontend/core/widgets/artisan_card.dart';
import 'package:frontend/core/widgets/price_suggestion_card.dart';
import 'package:frontend/core/theme/app_theme.dart';

Widget _buildTestWrapper(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('KalaSetu Reusable Components - Widget Tests', () {
    testWidgets('AppButton renders label and triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildTestWrapper(
          AppButton(
            label: 'Submit Listing',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Submit Listing'), findsOneWidget);
      await tester.tap(find.text('Submit Listing'));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows progress indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const AppButton(
            label: 'Submit Listing',
            isLoading: true,
            onPressed: null,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Listing'), findsNothing);
    });

    testWidgets('ConnectivityPill renders online and syncing states', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const Column(
            children: [
              ConnectivityPill(state: ConnectivityState.online),
              ConnectivityPill(state: ConnectivityState.syncing, syncCount: 4),
              ConnectivityPill(state: ConnectivityState.offline),
            ],
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Syncing (4)'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('SpeakerAffordance renders and can be tapped', (tester) async {
      bool played = false;
      await tester.pumpWidget(
        _buildTestWrapper(
          SpeakerAffordance(
            onTap: () => played = true,
          ),
        ),
      );

      expect(find.text('Tap to hear'), findsOneWidget);
      await tester.tap(find.text('Tap to hear'));
      expect(played, isTrue);
    });

    testWidgets('CraftCategoryBadge renders category and selection', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const Row(
            children: [
              CraftCategoryBadge(category: CraftCategory.pottery, isSelected: true),
              CraftCategoryBadge(category: CraftCategory.handloom, isSelected: false),
            ],
          ),
        ),
      );

      expect(find.text('Pottery'), findsOneWidget);
      expect(find.text('Handloom'), findsOneWidget);
    });

    testWidgets('LanguagePicker renders all 6 supported languages in native scripts', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          LanguagePicker(
            selectedCode: 'en',
            onLanguageSelected: (_) {},
          ),
        ),
      );

      expect(find.text('English'), findsWidgets);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('മലയാളം'), findsOneWidget);
    });

    testWidgets('StepProgressBar displays step icons and labels for 5-step wizard', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const StepProgressBar(
            currentStep: 2,
            totalSteps: 5,
            stepLabels: ['Photo', 'Voice', 'AI Review', 'Price', 'Publish'],
          ),
        ),
      );

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('AI Review'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
    });

    testWidgets('EmptyCraftState renders illustration, title, and CTA', (tester) async {
      bool actionClicked = false;
      await tester.pumpWidget(
        _buildTestWrapper(
          EmptyCraftState(
            title: 'No Crafts Added',
            subtitle: 'Start selling today',
            buttonLabel: 'Add Product',
            onAction: () => actionClicked = true,
          ),
        ),
      );

      expect(find.text('No Crafts Added'), findsOneWidget);
      expect(find.text('Start selling today'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      await tester.tap(find.text('Add Product'));
      expect(actionClicked, isTrue);
    });

    testWidgets('ArtisanCard displays product details and price', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const SizedBox(
            width: 280,
            child: ArtisanCard(
              title: 'Blue Ceramic Vase',
              price: '₹550',
              rating: 4.9,
              ratingCount: 18,
            ),
          ),
        ),
      );

      expect(find.text('Blue Ceramic Vase'), findsOneWidget);
      expect(find.text('₹550'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('(18)'), findsOneWidget);
    });

    testWidgets('PriceSuggestionCard renders recommended price and breakdown', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          const SingleChildScrollView(
            child: PriceSuggestionCard(
              recommendedPrice: 449,
              floorPrice: 340,
              budgetPrice: 399,
              premiumPrice: 549,
              explanation: 'Based on artisan labour and raw materials.',
            ),
          ),
        ),
      );

      expect(find.text('₹449'), findsWidgets);
      expect(find.text('₹399'), findsOneWidget);
      expect(find.text('₹549'), findsOneWidget);
      expect(find.text('Why this price?'), findsOneWidget);
      expect(find.text('Based on artisan labour and raw materials.'), findsOneWidget);
    });
  });
}
