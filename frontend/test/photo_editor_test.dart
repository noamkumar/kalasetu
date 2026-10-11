import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/studio/photo_editor_screen.dart';

void main() {
  const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
    Locale('kn'),
    Locale('ml'),
  ];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWrapper({
    required Widget child,
    Locale locale = const Locale('en'),
    double width = 412.0,
    double height = 900.0,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );
  }

  group('PhotoEditorScreen Widget & Responsive Tests', () {
    testWidgets('PhotoEditorScreen renders slider, big mic, text input, and quick tool buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWrapper(
          child: const PhotoEditorScreen(
            imageId: 'test_pottery_123',
            originalUrl: '/static/uploads/test_pottery_original.jpg',
            initialEditedUrl: '/static/uploads/test_pottery_square.webp',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Top App Bar & Action Icons
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);

      // 2. Verify Big Mic Button
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // 3. Verify Typed Command Input & Send Button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      // 4. Verify Quick Edit Tool Buttons
      expect(find.byIcon(Icons.layers_clear), findsOneWidget); // Remove BG
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget); // Background
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget); // Brighter
      expect(find.byIcon(Icons.tonality), findsOneWidget); // Shadow
      expect(find.byIcon(Icons.zoom_in), findsOneWidget); // Zoom
      expect(find.byIcon(Icons.auto_fix_high), findsOneWidget); // Auto Enhance
      expect(find.byIcon(Icons.rotate_right), findsOneWidget); // Rotate

      // 5. Verify Save Button
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('Interacting with tool buttons and entering text operates without exception', (tester) async {
      await tester.pumpWidget(
        buildTestWrapper(
          child: const PhotoEditorScreen(
            imageId: 'test_pottery_123',
            originalUrl: '/static/uploads/test_pottery_original.jpg',
            initialEditedUrl: '/static/uploads/test_pottery_square.webp',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Brighter button
      final brighterFinder = find.byIcon(Icons.wb_sunny_outlined);
      expect(brighterFinder, findsOneWidget);
      await tester.tap(brighterFinder, warnIfMissed: false);
      await tester.pump();

      // 2. Tap Shadow button
      final shadowFinder = find.byIcon(Icons.tonality);
      expect(shadowFinder, findsOneWidget);
      await tester.tap(shadowFinder, warnIfMissed: false);
      await tester.pump();

      // 3. Enter typed command in text field
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      await tester.enterText(textFieldFinder, 'background neela karo');
      expect(find.text('background neela karo'), findsOneWidget);

      // 4. Tap send button
      final sendFinder = find.byIcon(Icons.arrow_upward);
      expect(sendFinder, findsOneWidget);
      await tester.tap(sendFinder, warnIfMissed: false);
      await tester.pump();
    });

    testWidgets('Renders on small mobile (360px) and large text scale (1.3x) without overflow', (tester) async {
      await tester.pumpWidget(
        buildTestWrapper(
          width: 360.0,
          height: 800.0,
          textScale: 1.3,
          child: const PhotoEditorScreen(
            imageId: 'test_small_screen',
            originalUrl: '/static/uploads/sample.jpg',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect no overflow errors
      expect(tester.takeException(), isNull);
      expect(find.byType(PhotoEditorScreen), findsOneWidget);
    });

    testWidgets('Save button triggers onSave callback', (tester) async {
      String? savedUrl;
      await tester.pumpWidget(
        buildTestWrapper(
          child: PhotoEditorScreen(
            imageId: 'test_save_flow',
            originalUrl: '/static/uploads/sample.jpg',
            initialEditedUrl: '/static/uploads/sample_edited.webp',
            onSave: (url) => savedUrl = url,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byIcon(Icons.check);
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();

      expect(savedUrl, equals('/static/uploads/sample_edited.webp'));
    });
  });
}
