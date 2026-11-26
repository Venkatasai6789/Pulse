import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse/ai/ai_service.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/soil.dart';
import 'package:pulse/core/soil_reading.dart';
import 'package:pulse/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AiService.instance = AiService();
  });

  group('Phase 6: AI Soil Context & Schema Tests', () {
    test('AiInsight deserialization handles soilAdvice properly', () {
      final jsonWithSoil = {
        'model': 'gemini-2.5-flash',
        'generatedAt': '2026-11-26T00:00:00.000Z',
        'summary': 'Pollinator activity is healthy.',
        'photoFindings': ['Abundant blossoms'],
        'suggestions': ['Add bee hotel'],
        'habitatSuggestions': [],
        'isHabitatPhoto': true,
        'soilAdvice': 'Soil moisture is optimal at 42.5%. Maintain current watering schedule.',
      };

      final insight = AiInsight.fromJson(jsonWithSoil);
      expect(insight.soilAdvice, 'Soil moisture is optimal at 42.5%. Maintain current watering schedule.');
      expect(insight.toJson()['soilAdvice'], 'Soil moisture is optimal at 42.5%. Maintain current watering schedule.');
    });

    test('AiInsight deserialization defaults missing soilAdvice to empty string', () {
      final jsonWithoutSoil = {
        'model': 'gemini-2.5-flash',
        'generatedAt': '2026-11-26T00:00:00.000Z',
        'summary': 'Pollinator activity is healthy.',
        'photoFindings': ['Abundant blossoms'],
        'suggestions': ['Add bee hotel'],
        'habitatSuggestions': [],
        'isHabitatPhoto': true,
      };

      final insight = AiInsight.fromJson(jsonWithoutSoil);
      expect(insight.soilAdvice, '');
      expect(insight.toJson()['soilAdvice'], '');
    });

    test('REST Schema contains soilAdvice field', () {
      expect(kAiInsightRestSchema['properties'], contains('soilAdvice'));
      final soilAdviceProp = (kAiInsightRestSchema['properties'] as Map)['soilAdvice'] as Map;
      expect(soilAdviceProp['type'], 'STRING');
    });

    test('Score invariance with soil present: PHI and tier unchanged by AI workflow', () {
      final soil = SoilReading(
        percent: 45.0,
        raw: 2100,
        status: SoilStatus.optimal,
        source: SoilSource.esp32,
        deviceId: 'pulse-node-01',
        capturedAt: DateTime.now(),
      );

      final inputs = AssessmentInputs(
        visits: 15,
        durationMinutes: 5,
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 28.0,
        humidityPct: 60.0,
        co2Ppm: 650.0,
        risk: const RiskIndicators(),
        riskLevel: RiskLevel.low,
        soil: soil,
        soilMoisturePercent: soil.percent,
      );

      final calculated = calculatePhi(inputs);
      final assessment = Assessment(
        id: 'test-soil-ai',
        locationId: 'loc-1',
        status: AssessmentStatus.submitted,
        visits: 15,
        observedAt: DateTime.now(),
        durationMinutes: 5,
        weather: 'Sunny',
        flowers: Level.high,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 28.0,
        humidityPct: 60.0,
        co2Ppm: 650.0,
        soil: soil,
        riskLevel: RiskLevel.low,
        result: calculated,
        createdAt: DateTime.now(),
      );

      // Verify that attaching AI insight does NOT change calculated result or tier
      final fakeInsight = AiInsight(
        model: 'gemini-2.5-flash',
        generatedAt: DateTime(2026, 11, 26),
        summary: 'Excellent habitat and soil moisture.',
        suggestions: const ['Maintain native flora'],
        soilAdvice: 'Soil is in optimal zone.',
      );

      final updated = assessment.copyWith(ai: fakeInsight);
      expect(updated.result?.phi, calculated.phi);
      expect(updated.result?.tier, calculated.tier);
      expect(updated.result?.soilScore, calculated.soilScore);
      expect(updated.ai?.soilAdvice, 'Soil is in optimal zone.');
    });
  });
}
