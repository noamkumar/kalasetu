import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:frontend/core/widgets/connectivity_pill.dart';
import 'package:frontend/features/profile/developer_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Requirement 5: Connectivity Pill Distinguishes No Internet vs Server Not Reachable', () {
    testWidgets('Renders Online state with green badge', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConnectivityPill(state: ConnectivityState.online),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('Renders Syncing state with amber badge and sync count', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConnectivityPill(state: ConnectivityState.syncing, syncCount: 4),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Syncing (4)'), findsOneWidget);
    });

    testWidgets('Renders Server Not Reachable state distinctly from No Internet', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConnectivityPill(state: ConnectivityState.serverUnreachable),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Server Not Reachable'), findsOneWidget);
      expect(find.text('No Internet'), findsNothing);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('Renders No Internet state distinctly from Server Not Reachable', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConnectivityPill(state: ConnectivityState.noInternet),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Internet'), findsOneWidget);
      expect(find.text('Server Not Reachable'), findsNothing);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('Tapping on Server Not Reachable pill opens DeveloperSettingsDialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConnectivityPill(state: ConnectivityState.serverUnreachable),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConnectivityPill));
      await tester.pumpAndSettle();

      expect(find.byType(DeveloperSettingsDialog), findsOneWidget);
    });
  });
}
