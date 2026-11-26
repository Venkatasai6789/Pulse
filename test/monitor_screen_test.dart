import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/screens/monitor/monitor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _createMonitorScreen({String? locationId, double textScale = 1.0}) {
  SharedPreferences.setMockInitialValues({});
  final mockApi = MockApiService(seedDemoHistory: true, latency: Duration.zero);

  return MultiProvider(
    providers: [
      Provider<ApiService>.value(value: mockApi),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MonitorScreen(locationId: locationId),
      ),
    ),
  );
}

void main() {
  testWidgets('MonitorScreen renders header, location card, and stepper without old placeholders',
      (tester) async {
    await tester.pumpWidget(_createMonitorScreen());
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('New Assessment'), findsOneWidget);
    // F13: Single line subtitle at 360dp
    expect(
      find.text('Record what you see at this site'),
      findsOneWidget,
    );

    // Verify old placeholders are NOT present
    expect(find.text('Monitor Pollinator Health'), findsNothing);
    expect(find.text('Calculate PHI (Test View)'), findsNothing);
    expect(find.text('Ready for Assessment'), findsNothing);

    // Verify location card is visible
    expect(find.text('Location *'), findsOneWidget);

    // Verify 5 stepper segments
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Habitat'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);
    expect(find.text('Risk'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);

    // Verify bottom bar buttons and required counter
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);
    expect(find.textContaining('required'), findsOneWidget);
  });

  testWidgets('Step 1 Pollinator Activity counter and chips interact correctly',
      (tester) async {
    await tester.pumpWidget(_createMonitorScreen(locationId: 'loc-garden'));
    await tester.pumpAndSettle();

    // Visits initially empty showing muted placeholder "0" (F17)
    expect(find.text('0'), findsOneWidget);

    // Tap + to increment
    final plusButton = find.byIcon(Icons.add_rounded);
    expect(plusButton, findsOneWidget);
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    final visitCountFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == '1' && widget.style?.fontSize == 38,
    );
    expect(visitCountFinder, findsOneWidget);

    // Tap + again
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    // Duration chips present
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);

    // Weather chips present
    final sunnyChip = find.text('Sunny');
    await tester.ensureVisible(sunnyChip);
    await tester.tap(sunnyChip);
    await tester.pumpAndSettle();

    // "How to observe" collapsible card present
    final protocolHeader = find.text('How to observe');
    await tester.ensureVisible(protocolHeader);
    await tester.tap(protocolHeader);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 m × 2 m'), findsOneWidget);
  });

  testWidgets('Complete End-to-End Stepper Flow: Steps 1 -> 2 -> 3 -> 4 -> 5 Review & PHI Preview',
      (tester) async {
    await tester.pumpWidget(_createMonitorScreen(locationId: 'loc-garden'));
    await tester.pumpAndSettle();

    // -------------------------------- Step 1: Pollinator Activity
    // Visits: 18 visits
    for (int i = 0; i < 18; i++) {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Date & Time: Use now
    final useNow = find.text('Use now');
    await tester.ensureVisible(useNow);
    await tester.tap(useNow);
    await tester.pumpAndSettle();

    // Weather: Sunny
    final sunnyChip = find.text('Sunny');
    await tester.ensureVisible(sunnyChip);
    await tester.tap(sunnyChip);
    await tester.pumpAndSettle();

    // Tap Next
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // -------------------------------- Step 2: Habitat Quality
    expect(find.text('Habitat Quality'), findsWidgets);

    // Flowers: High
    final highPills = find.text('High');
    await tester.ensureVisible(highPills.first);
    await tester.tap(highPills.first);
    await tester.pumpAndSettle();

    // Nesting Spaces: Medium
    final medPills = find.text('Medium');
    await tester.ensureVisible(medPills.at(1));
    await tester.tap(medPills.at(1));
    await tester.pumpAndSettle();

    // Shelter: High
    await tester.ensureVisible(highPills.at(2));
    await tester.tap(highPills.at(2));
    await tester.pumpAndSettle();

    // Water: Present
    final presentPill = find.text('Present');
    await tester.ensureVisible(presentPill);
    await tester.tap(presentPill);
    await tester.pumpAndSettle();

    // Verify Habitat sub-score live preview chip appears
    expect(find.text('Habitat Quality Score'), findsOneWidget);
    expect(find.text('85 / 100'), findsOneWidget);

    // Tap Next
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // -------------------------------- Step 3: Environmental Conditions
    expect(find.text('Environmental Conditions'), findsWidgets);

    // Enter Temperature: 29
    final tempField = find.widgetWithText(TextField, 'e.g. 25');
    expect(tempField, findsOneWidget);
    await tester.enterText(tempField, '29');
    await tester.pumpAndSettle();

    // Enter Humidity: 61
    final humField = find.widgetWithText(TextField, 'e.g. 60');
    expect(humField, findsOneWidget);
    await tester.enterText(humField, '61');
    await tester.pumpAndSettle();

    // Enter CO2: 610
    final co2Field = find.widgetWithText(TextField, 'e.g. 600');
    expect(co2Field, findsOneWidget);
    await tester.enterText(co2Field, '610');
    await tester.pumpAndSettle();

    // Verify Environmental score live chip
    expect(find.text('Environmental Score'), findsOneWidget);
    expect(find.text('100 / 100'), findsOneWidget);

    // Tap Next
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // -------------------------------- Step 4: Potential Risks
    expect(find.text('Potential Risks'), findsWidgets);

    // Select Risk Level: Low
    final riskDropdown = find.text('Select risk level');
    expect(riskDropdown, findsOneWidget);
    await tester.ensureVisible(riskDropdown);
    await tester.tap(riskDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    final lowOption = find.text('Low').last;
    await tester.tap(lowOption);
    await tester.pumpAndSettle();

    // All required fields are now filled: counter shows "All set ✓"
    expect(find.text('All set ✓'), findsOneWidget);

    // Tap Next -> Review
    await tester.tap(find.text('Next →'));
    await tester.pumpAndSettle();

    // -------------------------------- Step 5: Review & Calculate
    expect(find.text('Review & Calculate'), findsWidgets);
    expect(find.text('Live PHI Preview'), findsOneWidget);
    expect(find.text('Pollinator Paradise'), findsOneWidget);
    expect(find.text('91'), findsWidgets);
    expect(find.text('Calculate PHI →'), findsOneWidget);
  });

  testWidgets('360px screen width and 1.3 text scale renders without overflow',
      (tester) async {
    FlutterErrorDetails? caughtDetails;
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };
    try {
      await tester.pumpWidget(_createMonitorScreen(locationId: 'loc-garden', textScale: 1.3));
      await tester.pumpAndSettle();
      expect(caughtDetails, isNull);
      expect(find.text('New Assessment'), findsOneWidget);
    } finally {
      FlutterError.onError = prevHandler;
    }
  });

  testWidgets('Observation Timer renders on 360px screen without right overflow and interacts cleanly',
      (tester) async {
    FlutterErrorDetails? caughtDetails;
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };

    try {
      await tester.pumpWidget(_createMonitorScreen(locationId: 'loc-garden', textScale: 1.0));
      await tester.pumpAndSettle();

      // Find and tap the timer button
      final startTimerBtn = find.text('Start 5-min observation timer');
      expect(startTimerBtn, findsOneWidget);
      await tester.ensureVisible(startTimerBtn);
      await tester.tap(startTimerBtn);
      await tester.pump();

      // Verify timer card opened
      expect(find.text('Observation Timer'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Stop & Use Count'), findsOneWidget);
      expect(find.textContaining('Tap each visit!'), findsOneWidget);

      // No overflow should have occurred!
      expect(caughtDetails, isNull);

      // Tap "Tap each visit!"
      final tapVisitBtn = find.textContaining('Tap each visit!');
      await tester.tap(tapVisitBtn);
      await tester.pump();

      // Tap Pause
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);

      // Tap Stop & Use Count
      await tester.tap(find.text('Stop & Use Count'));
      await tester.pump();

      // Timer card should now be closed and button restored
      expect(find.text('Start 5-min observation timer'), findsOneWidget);
      expect(caughtDetails, isNull);
    } finally {
      FlutterError.onError = prevHandler;
    }
  });
}
