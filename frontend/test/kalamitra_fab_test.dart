import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend/core/services/storage_service.dart';
import 'package:frontend/core/widgets/kalamitra_fab.dart';

class FakeBox implements Box {
  final Map<dynamic, dynamic> _map = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _map.containsKey(key) ? _map[key] : defaultValue;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _map.remove(key);
  }

  @override
  bool containsKey(dynamic key) => _map.containsKey(key);

  @override
  Future<int> clear() async {
    final count = _map.length;
    _map.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final authBox = FakeBox();
    final settingsBox = FakeBox();
    StorageService.initForTesting(authBox: authBox, settingsBox: settingsBox);
  });

  tearDownAll(() async {});

  setUp(() async {
    await StorageService.resetKalaMitraPosition();
  });

  Widget buildTestableWidget({
    required Widget child,
    double width = 400.0,
    double height = 800.0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );
  }

  testWidgets('KalaMitraFab renders 52dp round button without text label and triggers onTap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        child: KalaMitraFab(
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check button exists
    expect(find.byType(KalaMitraFab), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);

    // Verify 52x52 round button size
    final buttonFinder = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 52.0 &&
          w.constraints?.maxHeight == 52.0,
    );
    expect(buttonFinder, findsOneWidget);

    // Verify Semantics label
    final semanticsFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.button == true,
    );
    expect(semanticsFinder, findsOneWidget);

    // Tap button
    await tester.tap(find.byIcon(Icons.smart_toy_rounded));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('KalaMitraFab drags and snaps to nearest edge and persists in Hive', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        width: 400.0,
        height: 800.0,
        child: const KalaMitraFab(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially docked on right edge
    expect(StorageService.kalaMitraIsRight, isTrue);

    // Drag from right toward left edge (across screen center 200.0)
    final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.smart_toy_rounded)));
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-25.0, -10.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Should now snap to left edge
    expect(StorageService.kalaMitraIsRight, isFalse);
    expect(StorageService.kalaMitraYRatio, isNotNull);

    // Now drag back towards the right edge
    final gesture2 = await tester.startGesture(tester.getCenter(find.byIcon(Icons.smart_toy_rounded)));
    for (int i = 0; i < 10; i++) {
      await gesture2.moveBy(const Offset(25.0, 5.0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture2.up();
    await tester.pumpAndSettle();

    // Should snap back to right edge
    expect(StorageService.kalaMitraIsRight, isTrue);
  });

  testWidgets('KalaMitraFab long press opens menu and Hide for now shrinks to edge tab', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        width: 400.0,
        height: 800.0,
        child: const KalaMitraFab(),
      ),
    );
    await tester.pumpAndSettle();

    // Long press on the button icon
    await tester.longPress(find.byIcon(Icons.smart_toy_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Menu should be open with PopupMenuItems
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));

    // Tap "Hide for now" (first popup item)
    await tester.tap(find.byType(PopupMenuItem<String>).first);
    await tester.pumpAndSettle();

    // State is now hidden in StorageService
    expect(StorageService.isKalaMitraHidden, isTrue);

    // An edge tab icon should be shown (chevron left when docked on right)
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    // Tap edge tab to expand it back
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    // Button restored to full round button
    expect(StorageService.isKalaMitraHidden, isFalse);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
  });

  testWidgets('KalaMitraFab respects isScrolling opacity and hide parameter', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        child: const KalaMitraFab(
          isScrolling: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find AnimatedOpacity with 0.5 opacity
    final animatedOpacityFinder = find.byWidgetPredicate(
      (w) => w is AnimatedOpacity && w.opacity == 0.5,
    );
    expect(animatedOpacityFinder, findsOneWidget);

    // Now test hide: true
    await tester.pumpWidget(
      buildTestableWidget(
        child: const KalaMitraFab(
          hide: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should render SizedBox.shrink, no button
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
  });

  test('StorageService.resetKalaMitraPosition restores default position', () async {
    // Save custom position
    await StorageService.saveKalaMitraPosition(yRatio: 0.3, isRight: false);
    await StorageService.setKalaMitraHidden(true);

    expect(StorageService.kalaMitraYRatio, 0.3);
    expect(StorageService.kalaMitraIsRight, isFalse);
    expect(StorageService.isKalaMitraHidden, isTrue);

    // Reset
    await StorageService.resetKalaMitraPosition();

    expect(StorageService.kalaMitraYRatio, isNull);
    expect(StorageService.kalaMitraIsRight, isTrue);
    expect(StorageService.isKalaMitraHidden, isFalse);
  });
}
