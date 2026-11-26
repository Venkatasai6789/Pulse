import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/soil.dart';
import 'package:pulse/core/soil_reading.dart';
import 'package:pulse/data/api_service.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/monitor/widgets/step5_review.dart';
import 'package:pulse/screens/results/results_screen.dart';
import 'package:provider/provider.dart';

class FakeTestApiService implements ApiService {
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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final location = Location(
    id: 'loc-1',
    name: 'Community Garden',
    type: 'Community Garden',
    address: '123 Green St',
    latitude: 51.5,
    longitude: -0.1,
    createdAt: DateTime(2026, 1, 1),
  );

  group('Review and Results Soil Moisture Integration', () {
    testWidgets('Review Step 5 shows Soil moisture row when soil is present in draft', (tester) async {
      final draftWithSoil = Assessment(
        id: 'draft-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
        visits: 15,
        observedAt: DateTime.now(),
        weather: 'Sunny',
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 22.0,
        humidityPct: 50.0,
        co2Ppm: 450.0,
        riskLevel: RiskLevel.low,
        soil: SoilReading(
          percent: 52.0,
          raw: 2150,
          status: SoilStatus.optimal,
          source: SoilSource.esp32,
          deviceId: 'PULSE-Node-A1B2',
          capturedAt: DateTime(2026, 5, 1, 10, 30),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Step5Review(
                draft: draftWithSoil,
                selectedLocation: location,
                onJumpToStep: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Soil moisture'), findsOneWidget);
      expect(find.text('52 % · Optimal'), findsOneWidget);
      expect(find.text('Sensor PULSE-Node-A1B2 · 10:30'), findsOneWidget);
    });

    testWidgets('Review Step 5 hides Soil moisture row when soil is null', (tester) async {
      final draftWithoutSoil = Assessment(
        id: 'draft-2',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
        visits: 15,
        observedAt: DateTime.now(),
        weather: 'Sunny',
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 22.0,
        humidityPct: 50.0,
        co2Ppm: 450.0,
        riskLevel: RiskLevel.low,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Step5Review(
                draft: draftWithoutSoil,
                selectedLocation: location,
                onJumpToStep: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Soil moisture'), findsNothing);
    });

    testWidgets('Results screen shows soil in environmental line and breakdown', (tester) async {
      const inputs = AssessmentInputs(
        visits: 15,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 22.0,
        humidityPct: 50.0,
        co2Ppm: 450.0,
        risk: RiskIndicators(),
        riskLevel: RiskLevel.low,
      );

      final soilReading = SoilReading(
        percent: 52.0,
        raw: 2150,
        status: SoilStatus.optimal,
        source: SoilSource.esp32,
        deviceId: 'PULSE-Node-A1B2',
        capturedAt: DateTime(2026, 5, 1, 10, 30),
      );

      final phiResult = calculatePhi(inputs, soil: soilReading);

      final assessment = Assessment(
        id: 'assess-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
        result: phiResult,
        status: AssessmentStatus.submitted,
        visits: 15,
        observedAt: DateTime.now(),
        weather: 'Sunny',
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.high,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 22.0,
        humidityPct: 50.0,
        co2Ppm: 450.0,
        riskLevel: RiskLevel.low,
        soil: soilReading,
      );

      final api = FakeTestApiService();
      api.assessments['assess-1'] = assessment;
      api.locations['loc-1'] = location;

      await tester.pumpWidget(
        Provider<ApiService>.value(
          value: api,
          child: const MaterialApp(
            home: ResultsScreen(id: 'assess-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('52 % soil'), findsOneWidget);

      final tileFinder = find.text('How PHI is calculated');
      await tester.ensureVisible(tileFinder);
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('/ 4 ='), findsOneWidget);
    });
  });
}
