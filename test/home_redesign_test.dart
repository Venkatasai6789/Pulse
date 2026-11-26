import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/home/widgets/activity_timeline.dart';
import 'package:pulse/screens/home/widgets/assessment_cta.dart';
import 'package:pulse/screens/home/widgets/health_summary_card.dart';
import 'package:pulse/screens/home/widgets/location_card.dart';
import 'package:pulse/screens/home/widgets/parameters_card.dart';
import 'package:pulse/screens/home/widgets/quick_actions.dart';
import 'package:pulse/screens/home/widgets/ring_gauge.dart';
import 'package:pulse/screens/home/widgets/stat_tile.dart';

void main() {
  testWidgets('RingGauge renders score', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RingGauge(phi: 85, animate: false),
        ),
      ),
    );

    expect(find.text('85'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
  });

  testWidgets('HealthSummaryCard renders with data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HealthSummaryCard(
            averagePhi: 91,
            healthyLocationsCount: 2,
            totalLocationsCount: 3,
            deltaPhi: 9,
            hasData: true,
          ),
        ),
      ),
    );

    expect(find.text('PROTECT'), findsOneWidget);
    expect(find.text('2 of 3 locations are in good health'), findsOneWidget);
    // F05: Single arrow icon without duplicate glyph in text
    expect(find.text('9 since last assessment'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('StatTile renders title, value and caption', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatTile(
            icon: Icons.location_on_outlined,
            value: '4',
            label: 'Total Locations',
            caption: '+1 this month',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Total Locations'), findsOneWidget);
    expect(find.text('+1 this month'), findsOneWidget);

    await tester.tap(find.byType(StatTile));
    expect(tapped, isTrue);
  });

  testWidgets('AssessmentCtaCard renders primary CTA and draft resumption', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssessmentCtaCard(),
        ),
      ),
    );

    expect(find.text('Start a new assessment'), findsOneWidget);
    expect(find.text('Begin →'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssessmentCtaCard(
            draftLocationName: 'Community Garden',
            draftLocationId: 'loc-1',
          ),
        ),
      ),
    );

    expect(find.text('Continue draft for Community Garden'), findsOneWidget);
    expect(find.text('Resume →'), findsOneWidget);
  });

  testWidgets('ParametersCard renders all 4 parameters', (tester) async {
    const params = [
      ParameterData(
        title: 'Pollinator Activity',
        weight: '30%',
        score: 90,
        label: 'Good',
        labelColor: Color(0xFF1E4D2B),
        icon: Icons.pest_control_outlined,
        iconColor: Color(0xFFE65100),
      ),
      ParameterData(
        title: 'Habitat Quality',
        weight: '30%',
        score: 85,
        label: 'Good',
        labelColor: Color(0xFF1E4D2B),
        icon: Icons.local_florist_outlined,
        iconColor: Color(0xFFF57C00),
      ),
      ParameterData(
        title: 'Environmental',
        weight: '20%',
        score: 100,
        label: 'Ideal',
        labelColor: Color(0xFF1E4D2B),
        icon: Icons.thermostat_outlined,
        iconColor: Color(0xFF0288D1),
      ),
      ParameterData(
        title: 'Potential Risks',
        weight: '20%',
        score: 90,
        label: 'Low Risk',
        labelColor: Color(0xFF1E4D2B),
        icon: Icons.warning_amber_rounded,
        iconColor: Color(0xFFD32F2F),
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParametersCard(
            parameters: params,
            hasData: true,
          ),
        ),
      ),
    );

    expect(find.text('Pollinator Activity · 30%'), findsOneWidget);
    expect(find.text('Habitat Quality · 30%'), findsOneWidget);
    expect(find.text('Environmental · 20%'), findsOneWidget);
    expect(find.text('Potential Risks · 20%'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Ideal'), findsOneWidget);
    expect(find.text('Low Risk'), findsOneWidget);
  });

  testWidgets('QuickActionsRow renders all 4 actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuickActionsRow(),
        ),
      ),
    );

    expect(find.text('New\nAssessment'), findsOneWidget);
    expect(find.text('Add\nLocation'), findsOneWidget);
    expect(find.text('Report\nConcern'), findsOneWidget);
    expect(find.text('Share\nUpdate'), findsOneWidget);
  });

  testWidgets('ActivityTimeline renders activity events', (tester) async {
    final events = [
      ActivityItem(
        title: 'Assessment submitted · Community Garden',
        detail: 'PHI 91 · Protect',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        dotColor: const Color(0xFF1E4D2B),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityTimeline(items: events),
        ),
      ),
    );

    expect(find.text('Assessment submitted · Community Garden'), findsOneWidget);
    expect(find.text('PHI 91 · Protect'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);
  });

  testWidgets('HomeLocationCard renders with assessment data and no overflow at 200px height', (tester) async {
    final location = Location(
      id: 'loc-1',
      name: 'Community Garden',
      type: 'Urban Community Garden',
      address: '123 Green Way, Eco City',
      photoPaths: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    final assessment = Assessment(
      id: 'a-1',
      locationId: 'loc-1',
      status: AssessmentStatus.submitted,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      submittedAt: DateTime.now().subtract(const Duration(hours: 1)),
      result: const PhiResult(
        activity: 80,
        habitat: 85,
        environmental: 90,
        risk: 90,
        riskLevel: RiskLevel.low,
        temperaturePoints: 90,
        humidityPoints: 90,
        co2Points: 90,
        raw: 85.5,
        phi: 86,
        tier: Tier.protect,
      ),
    );

    // Test inside exact 200px height (where previous overflow occurred)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                HomeLocationCard(
                  location: location,
                  latestAssessment: assessment,
                ),
                const AddLocationCard(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Community Garden'), findsOneWidget);
    expect(find.text('123 Green Way, Eco City'), findsOneWidget);
    expect(find.text('86 · PROTECT'), findsOneWidget);
    expect(find.text('1h ago'), findsOneWidget);
    expect(find.text('Add Location'), findsOneWidget);
  });

  testWidgets('HomeLocationCard renders with 1.3 text scale without bottom overflow', (tester) async {
    final location = Location(
      id: 'loc-2',
      name: 'South Botanical Gardens Conservation Zone',
      type: 'Botanical Garden',
      address: '456 Flora Avenue, Botanical District, South Sector',
      photoPaths: const [],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    final assessment = Assessment(
      id: 'a-2',
      locationId: 'loc-2',
      status: AssessmentStatus.submitted,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      result: const PhiResult(
        activity: 95,
        habitat: 95,
        environmental: 90,
        risk: 90,
        riskLevel: RiskLevel.low,
        temperaturePoints: 100,
        humidityPoints: 85,
        co2Points: 90,
        raw: 92.5,
        phi: 93,
        tier: Tier.protect,
      ),
    );

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SizedBox(
              height: 212 * 1.3,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  HomeLocationCard(
                    location: location,
                    latestAssessment: assessment,
                    width: 230,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('South Botanical Gardens Conservation Zone'), findsOneWidget);
    expect(find.text('93 · PROTECT'), findsOneWidget);
  });

  testWidgets('HomeLocationCard unassessed state and AddLocationCard render without overflow', (tester) async {
    final location = Location(
      id: 'loc-3',
      name: 'Rooftop Garden',
      type: 'Rooftop',
      address: '789 Highrise St',
      photoPaths: const [],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 212,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                HomeLocationCard(
                  location: location,
                  latestAssessment: null,
                ),
                const AddLocationCard(width: 230),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Rooftop Garden'), findsOneWidget);
    expect(find.text('Not assessed'), findsOneWidget);
    expect(find.text('Add Location'), findsOneWidget);
    expect(find.text('Register new site'), findsOneWidget);
  });
}
