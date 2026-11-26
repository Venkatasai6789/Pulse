import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/recommendations.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/results/results_screen.dart';
import 'package:pulse/theme/app_theme.dart';

class FakeApiService implements ApiService {
  final Map<String, Assessment> assessments = {};
  final Map<String, Location> locations = {};

  @override
  Future<Assessment?> getAssessment(String id) async => assessments[id];

  @override
  Future<Location?> getLocation(String id) async => locations[id];

  @override
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true}) async {
    return assessments.values
        .where((a) => locationId == null || a.locationId == locationId)
        .where((a) => !submittedOnly || a.isSubmitted)
        .toList();
  }

  @override
  Future<Assessment> addActionTaken(String assessmentId, ActionTaken action) async {
    final a = assessments[assessmentId];
    if (a == null) throw Exception('Not found');
    final updated = a.copyWith(actionsTaken: [...a.actionsTaken, action]);
    assessments[assessmentId] = updated;
    return updated;
  }

  @override
  Future<Assessment> submitAssessment(Assessment draft) async {
    final result = calculatePhi(draft.toInputs());
    final s = draft.copyWith(
      status: AssessmentStatus.submitted,
      result: result,
      submittedAt: DateTime.now(),
    );
    assessments[s.id] = s;
    return s;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Acceptance Criteria Math Verification', () {
    test('18 visits · 5 min · High/Medium/High/Present · 29 °C · 61 % · 610 ppm · Low risk', () {
      const inputs = AssessmentInputs(
        visits: 18,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final result = calculatePhi(inputs);

      // Verify overall score and tier
      expect(result.phi, 91);
      expect(result.tier, Tier.protect);
      expect(tierInfo[result.tier]!.categoryName, 'Pollinator Paradise');

      // Verify 4 sub-scores
      expect(result.activity, 90.0);
      expect(result.habitat, 85.0);
      expect(result.environmental, 100.0);
      expect(result.risk, 90);
    });

    test('Change Water to Absent: habitat becomes 60 and PHI becomes 83', () {
      const inputsWaterAbsent = AssessmentInputs(
        visits: 18,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.absent,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final result = calculatePhi(inputsWaterAbsent);

      // Verify habitat becomes 60 and PHI becomes 83
      expect(result.habitat, 60.0);
      expect(result.phi, 83);
      expect(result.tier, Tier.protect);
      expect(tierInfo[result.tier]!.categoryName, 'Pollinator Paradise');

      // Verify other sub-scores remain identical
      expect(result.activity, 90.0);
      expect(result.environmental, 100.0);
      expect(result.risk, 90);
    });
  });

  group('ResultsScreen Widget Tests', () {
    late FakeApiService fakeApi;
    final testDate = DateTime(2026, 11, 14, 10, 20);

    setUp(() {
      fakeApi = FakeApiService();

      fakeApi.locations['loc-1'] = Location(
        id: 'loc-1',
        name: 'Community Garden',
        type: 'Community garden',
        address: 'Alwarpet, Chennai',
        createdAt: DateTime(2026, 8, 1),
      );

      const inputs = AssessmentInputs(
        visits: 18,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final result = calculatePhi(inputs);

      fakeApi.assessments['test-assessment-id'] = Assessment(
        id: 'test-assessment-id',
        locationId: 'loc-1',
        status: AssessmentStatus.submitted,
        visits: 18,
        durationMinutes: 5,
        observedAt: testDate,
        weather: 'Sunny',
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 29.0,
        humidityPct: 61.0,
        co2Ppm: 610.0,
        riskLevel: RiskLevel.low,
        result: result,
        createdAt: testDate,
        submittedAt: testDate,
      );
    });

    Widget createTestApp(String assessmentId) {
      return Provider<ApiService>.value(
        value: fakeApi,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ResultsScreen(id: assessmentId),
        ),
      );
    }

    testWidgets('Header displays location name, formatted date & time and weather, hides internal ID', (tester) async {
      await tester.pumpWidget(createTestApp('test-assessment-id'));
      await tester.pumpAndSettle();

      // Header info
      expect(find.text('Community Garden'), findsOneWidget);
      expect(find.text('14 Nov 2026 · 10:20 AM · Sunny'), findsOneWidget);

      // Internal ID must be hidden
      expect(find.textContaining('test-assessment-id'), findsNothing);
      expect(find.textContaining('Assessment ID:'), findsNothing);
      expect(find.textContaining('sample-assessment-id'), findsNothing);
    });

    testWidgets('Gauge shows 91 / 100, TierBadge, category name and recommendation', (tester) async {
      await tester.pumpWidget(createTestApp('test-assessment-id'));
      await tester.pumpAndSettle();

      // PHI score
      expect(find.text('91'), findsOneWidget);
      expect(find.text(' / 100'), findsWidgets);
      expect(find.text('PHI'), findsOneWidget);

      // Tier & Category
      expect(find.text('PROTECT · Pollinator Paradise'), findsOneWidget);
      expect(
        find.text('Maintain an excellent habitat and help neighbouring spaces improve.'),
        findsOneWidget,
      );

      // Why this score?
      expect(find.text('Why this score?'), findsOneWidget);
      expect(
        find.textContaining('Your location has high pollinator activity, good habitat features, suitable environmental conditions and low risk factors'),
        findsOneWidget,
      );
    });

    testWidgets('Parameter breakdown renders 4 full-width rows with weights and input details', (tester) async {
      await tester.pumpWidget(createTestApp('test-assessment-id'));
      await tester.pumpAndSettle();

      // Parameter titles
      expect(find.text('Pollinator Activity'), findsOneWidget);
      expect(find.text('Habitat Quality'), findsOneWidget);
      expect(find.text('Environmental Conditions'), findsOneWidget);
      expect(find.text('Potential Risk'), findsOneWidget);

      // Weights
      expect(find.text('Weight 30%'), findsNWidgets(2));
      expect(find.text('Weight 20%'), findsNWidgets(2));

      // Detail lines built from inputs
      expect(find.text('18 visits in 5 min · Sunny'), findsOneWidget);
      expect(find.text('Flowers High · Nesting Medium · Shelter High · Water Present'), findsOneWidget);
      expect(find.text('29 °C · 61 % humidity · 610 ppm CO₂'), findsOneWidget);
      expect(find.text('Risk level Low · 0 indicators'), findsOneWidget);

      // Status labels (F08: scoreBand: Activity=90 -> Good, Habitat=85 -> Good, Environmental=100 -> Good; Risk -> Low risk)
      expect(find.text('Good'), findsNWidgets(3)); // Activity, Habitat, Environmental
      expect(find.text('Low risk'), findsOneWidget); // Risk
    });

    testWidgets('How PHI is calculated shows real numbers formula', (tester) async {
      await tester.pumpWidget(createTestApp('test-assessment-id'));
      await tester.pumpAndSettle();

      final tileFinder = find.text('How PHI is calculated');
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();

      // Expandable title
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // Real numbers formula
      expect(
        find.text('(90 × 0.30) + (85 × 0.30) + (100 × 0.20) + (90 × 0.20) = 90.5 → 91'),
        findsOneWidget,
      );
    });

    testWidgets('What to do next and action buttons render properly', (tester) async {
      await tester.pumpWidget(createTestApp('test-assessment-id'));
      await tester.pumpAndSettle();

      // Next steps section
      expect(find.text('What to do next?'), findsOneWidget);

      // Navigation and Action buttons
      expect(find.text('Record an action taken'), findsOneWidget);
      expect(find.text('View location'), findsOneWidget);
      expect(find.text('New assessment'), findsOneWidget);

      // AI Suggestions advisory (F10: single title "Ecological insights" and "Advisory" chip)
      expect(find.text('Ecological insights'), findsOneWidget);
      expect(find.text('Advisory'), findsOneWidget);
    });

    testWidgets('High Risk alert banner appears when highRiskAlert is true even on PROTECT', (tester) async {
      // Create high risk assessment with high other scores
      const highRiskInputs = AssessmentInputs(
        visits: 20,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 25.0,
        humidityPct: 60.0,
        co2Ppm: 500.0,
        risk: RiskIndicators(pesticide: true),
        riskLevel: RiskLevel.high,
      );

      final highRiskResult = calculatePhi(highRiskInputs);
      fakeApi.assessments['high-risk-id'] = Assessment(
        id: 'high-risk-id',
        locationId: 'loc-1',
        status: AssessmentStatus.submitted,
        visits: 20,
        durationMinutes: 5,
        observedAt: testDate,
        weather: 'Sunny',
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.high,
        water: Water.present,
        temperatureC: 25.0,
        humidityPct: 60.0,
        co2Ppm: 500.0,
        riskLevel: RiskLevel.high,
        result: highRiskResult,
        createdAt: testDate,
        submittedAt: testDate,
      );

      await tester.pumpWidget(createTestApp('high-risk-id'));
      await tester.pumpAndSettle();

      // Alert must be visible
      expect(find.text('High Risk Alert'), findsOneWidget);
      expect(
        find.text('High risk observation recorded. A high overall PHI does not rule out a serious local concern. Consider investigating and reporting it.'),
        findsOneWidget,
      );
    });

    testWidgets('Empty state displays Result not found for non-existent assessment', (tester) async {
      await tester.pumpWidget(createTestApp('non-existent-id'));
      await tester.pumpAndSettle();

      expect(find.text('Result not found'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
    });
  });
}
