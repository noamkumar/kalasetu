import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/language_picker.dart';
import 'package:frontend/core/widgets/connectivity_pill.dart';
import 'package:frontend/features/onboarding/onboarding_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildEasyLocalizationWrapper(Widget child, {double width = 360.0, double height = 1000.0}) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ta'),
        Locale('te'),
        Locale('kn'),
        Locale('ml'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.lightTheme,
              home: child,
            ),
          );
        },
      ),
    );
  }

  Widget buildPlainWrapper(Widget child, {double width = 360.0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: const TextScaler.linear(1.3),
      ),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Phase 1 & Phase 2 Responsive and Component Tests', () {
    testWidgets('LanguagePicker displays all 6 native script names', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      await tester.pumpWidget(
        buildPlainWrapper(
          Scaffold(
            body: SingleChildScrollView(
              child: LanguagePicker(
                selectedCode: 'en',
                onLanguageSelected: (_) {},
              ),
            ),
          ),
          width: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('മലയാളം'), findsOneWidget);
    });

    testWidgets('OnboardingScreen renders on 320px screen at 1.3 text scale without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(
        buildEasyLocalizationWrapper(const OnboardingScreen(), width: 320, height: 700),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ConnectivityPill renders online, syncing, and offline states properly', (tester) async {
      await tester.pumpWidget(
        buildPlainWrapper(
          const Column(
            children: [
              ConnectivityPill(state: ConnectivityState.online),
              ConnectivityPill(state: ConnectivityState.syncing, syncCount: 3),
              ConnectivityPill(state: ConnectivityState.offline),
            ],
          ),
          width: 320,
        ),
      );
      await tester.pump();

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Syncing (3)'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
