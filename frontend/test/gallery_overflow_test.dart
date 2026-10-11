import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/gallery/gallery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GalleryScreen Responsive Overflow Tests (320px, 360px, 412px with 1.3 text scale)', () {
    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('Renders GalleryScreen at ${width.toInt()}px width without any overflow', (tester) async {
        // Set physical size and ratio to match test viewport
        tester.view.physicalSize = Size(width * 2, 900 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Catch any layout error or RenderFlex overflow
        FlutterErrorDetails? errorCaught;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          errorCaught = details;
          originalOnError?.call(details);
        };

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GalleryScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Check top-level rendering
        expect(errorCaught, isNull, reason: 'Encountered layout overflow at top of screen');
        expect(tester.takeException(), isNull);

        // Scroll down in increments to layout and test every component
        final scrollable = find.byType(Scrollable).first;
        for (int i = 0; i < 8; i++) {
          await tester.drag(scrollable, const Offset(0, -350));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(errorCaught, isNull, reason: 'Encountered layout overflow while scrolling section $i at ${width.toInt()}px');
          expect(tester.takeException(), isNull);
        }

        FlutterError.onError = originalOnError;
      });
    }
  });
}
