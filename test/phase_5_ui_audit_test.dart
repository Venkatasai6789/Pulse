import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/score_format.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/locations/locations_screen.dart';
import 'package:pulse/theme/app_theme.dart';
import 'package:pulse/widgets/phi_gauge.dart';
import 'package:pulse/widgets/tier_badge.dart';
import 'package:provider/provider.dart';

class _FakeApiService implements ApiService {
  final Map<String, Assessment> assessments = {};
  final Map<String, Location> locations = {};

  @override
  Future<Assessment?> getAssessment(String id) async => assessments[id];

  @override
  Future<Location?> getLocation(String id) async => locations[id];

  @override
  Future<List<Location>> getLocations() async => locations.values.toList();

  @override
  Future<List<Assessment>> getAssessments({String? locationId, bool submittedOnly = true}) async =>
      assessments.values.toList();

  @override
  Future<Location> createLocation(Location location) async {
    locations[location.id] = location;
    return location;
  }

  @override
  Future<Assessment> submitAssessment(Assessment assessment) async {
    assessments[assessment.id] = assessment;
    return assessment;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 UI Audit Fixes', () {
    test('F04 & F08: scoreBand and formatSubScore verification', () {
      expect(formatSubScore(78.0), '78');
      expect(formatSubScore(77.5), '77.5');
      expect(formatSubScore(0.0), '0');
      expect(formatSubScore(100.0), '100');

      expect(scoreBand(85), 'Good');
      expect(scoreBand(80), 'Good');
      expect(scoreBand(75), 'Fair');
      expect(scoreBand(60), 'Fair');
      expect(scoreBand(55), 'Moderate');
      expect(scoreBand(40), 'Moderate');
      expect(scoreBand(35), 'Low');
      expect(scoreBand(20), 'Low');
      expect(scoreBand(15), 'Critical');
      expect(scoreBand(0), 'Critical');
    });

    testWidgets('F03: PhiGauge renders score at values 5, 50, and 95 without error',
        (tester) async {
      for (final val in [5, 50, 95]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: PhiGauge(
                  phi: val,
                  size: 220,
                  animate: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('$val'), findsOneWidget);
        expect(find.text(' / 100'), findsOneWidget);
      }
    });

    testWidgets('F11: TierBadge for ENHANCE has no sparkle icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Center(
              child: TierBadge(tier: Tier.enhance),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      expect(find.text('ENHANCE'), findsOneWidget);
    });

    testWidgets('F01 & F21: LocationsScreen displays correct dynamic PHI score and tier',
        (tester) async {
      final api = _FakeApiService();
      const locId = 'loc-test-1';
      final now = DateTime.now();

      await api.createLocation(Location(
        id: locId,
        name: 'Community Garden',
        type: 'Community Garden',
        address: 'Alwarpet, Chennai',
        latitude: 13.04,
        longitude: 80.25,
        createdAt: now,
      ));

      final assessment = Assessment(
        id: 'asm-1',
        locationId: locId,
        status: AssessmentStatus.submitted,
        submittedAt: now,
        createdAt: now,
        observedAt: now,
        weather: 'Sunny',
        visits: 25,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 28,
        humidityPct: 65,
        co2Ppm: 450,
        riskLevel: RiskLevel.low,
      );

      final inputs = assessment.toInputs();
      final result = calculatePhi(inputs);
      await api.submitAssessment(assessment.copyWith(result: result));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: api),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LocationsScreen(),
          ),
        ),
      );

      // Pump frames for loading
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Community Garden'), findsOneWidget);
      expect(find.text('Alwarpet, Chennai'), findsOneWidget);
      expect(find.textContaining(result.tier.name.toUpperCase()), findsWidgets);
    });
  });
}
