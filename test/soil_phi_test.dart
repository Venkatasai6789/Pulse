import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/recommendations.dart';
import 'package:pulse/core/score_format.dart';
import 'package:pulse/core/soil.dart';
import 'package:pulse/core/soil_reading.dart';

AssessmentInputs baseInputs({
  int visits = 18,
  int duration = 5,
  Level flowers = Level.high,
  Level nesting = Level.medium,
  Level shelter = Level.high,
  Water water = Water.present,
  double temp = 29,
  double humidity = 61,
  double co2 = 610,
  RiskLevel risk = RiskLevel.low,
  SoilReading? soil,
}) =>
    AssessmentInputs(
      visits: visits,
      durationMinutes: duration,
      flowers: flowers,
      nesting: nesting,
      shelter: shelter,
      water: water,
      temperatureC: temp,
      humidityPct: humidity,
      co2Ppm: co2,
      risk: const RiskIndicators(),
      riskLevel: risk,
      soil: soil,
    );

void main() {
  group('Soil Bands & Scores', () {
    test('Band thresholds and points match specification', () {
      // S < 25 -> DRY, 20 points
      expect(soilStatusFor(0.0), SoilStatus.dry);
      expect(soilScore(0.0), 20.0);
      expect(soilStatusFor(24.9), SoilStatus.dry);
      expect(soilScore(24.9), 20.0);
      expect(soilBandLabel(SoilStatus.dry), 'Stressful');
      expect(soilStatusLabel(SoilStatus.dry), 'Dry');

      // 25 <= S < 40 -> LOW, 60 points
      expect(soilStatusFor(25.0), SoilStatus.low);
      expect(soilScore(25.0), 60.0);
      expect(soilStatusFor(39.9), SoilStatus.low);
      expect(soilScore(39.9), 60.0);
      expect(soilBandLabel(SoilStatus.low), 'Moderate');
      expect(soilStatusLabel(SoilStatus.low), 'Low');

      // 40 <= S <= 60 -> OPTIMAL, 100 points
      expect(soilStatusFor(40.0), SoilStatus.optimal);
      expect(soilScore(40.0), 100.0);
      expect(soilStatusFor(60.0), SoilStatus.optimal);
      expect(soilScore(60.0), 100.0);
      expect(soilBandLabel(SoilStatus.optimal), 'Suitable');
      expect(soilStatusLabel(SoilStatus.optimal), 'Optimal');

      // 60 < S <= 75 -> MOIST, 60 points
      expect(soilStatusFor(60.1), SoilStatus.moist);
      expect(soilScore(60.1), 60.0);
      expect(soilStatusFor(75.0), SoilStatus.moist);
      expect(soilScore(75.0), 60.0);
      expect(soilBandLabel(SoilStatus.moist), 'Moderate');
      expect(soilStatusLabel(SoilStatus.moist), 'Moist');

      // S > 75 -> WET, 20 points
      expect(soilStatusFor(75.1), SoilStatus.wet);
      expect(soilScore(75.1), 20.0);
      expect(soilStatusFor(100.0), SoilStatus.wet);
      expect(soilScore(100.0), 20.0);
      expect(soilBandLabel(SoilStatus.wet), 'Stressful');
      expect(soilStatusLabel(SoilStatus.wet), 'Waterlogged');
    });

    test('Clamping & validation on negative and out-of-range values', () {
      expect(soilStatusFor(-10.0), SoilStatus.dry);
      expect(soilScore(-10.0), 20.0);
      expect(soilStatusFor(150.0), SoilStatus.wet);
      expect(soilScore(150.0), 20.0);
    });

    test('Status codes match wire specification', () {
      expect(soilStatusCode(SoilStatus.dry), 'DRY');
      expect(soilStatusCode(SoilStatus.low), 'LOW');
      expect(soilStatusCode(SoilStatus.optimal), 'OPTIMAL');
      expect(soilStatusCode(SoilStatus.moist), 'MOIST');
      expect(soilStatusCode(SoilStatus.wet), 'WET');

      expect(soilStatusFromCode('DRY'), SoilStatus.dry);
      expect(soilStatusFromCode('optimal'), SoilStatus.optimal);
      expect(soilStatusFromCode('WET'), SoilStatus.wet);
      expect(soilStatusFromCode('UNKNOWN'), isNull);
    });
  });

  group('Regression Test: Invariance without soil', () {
    test('Scores are identical to existing baseline when soil is null', () {
      final inputsWithoutSoil = baseInputs();
      final result = calculatePhi(inputsWithoutSoil);

      expect(result.activity, 90.0);
      expect(result.habitat, 85.0);
      expect(result.environmental, 100.0);
      expect(result.risk, 90);
      expect(result.phi, 91);
      expect(result.tier, Tier.protect);
      expect(result.soilScore, isNull);
      expect(result.formulaVersion, 'v1');
    });
  });

  group('Worked Example from Real App Data (Community Garden, 14 Nov, PHI 66)', () {
    // Activity 15 visits -> (15/20)*100 = 75, wait:
    // Community Garden 14 Nov: Activity: 3 visits in 5 min -> (3/20)*100 = 15.
    // Habitat: flowers Med(60), nesting Med(60), shelter High(90), water Present(100) -> (60+60+90+100)/4 = 77.5
    // Temp 25 -> 100, Humidity 50 -> 100, CO2 80 -> 100 -> Env without soil = 100.
    // Risk Low -> 90.
    // Raw without soil = 15*0.30 + 77.5*0.30 + 100*0.20 + 90*0.20 = 4.5 + 23.25 + 20 + 18 = 65.75 -> 66 ENHANCE.
    final communityGardenInputs = AssessmentInputs(
      visits: 3,
      durationMinutes: 5,
      flowers: Level.medium,
      nesting: Level.medium,
      shelter: Level.high,
      water: Water.present,
      temperatureC: 25.0,
      humidityPct: 50.0,
      co2Ppm: 80.0,
      risk: const RiskIndicators(),
      riskLevel: RiskLevel.low,
    );

    test('No soil: Env 100 -> PHI 66, v1', () {
      final r = calculatePhi(communityGardenInputs);
      expect(r.environmental, 100.0);
      expect(r.phi, 66);
      expect(r.tier, Tier.enhance);
      expect(r.soilScore, isNull);
      expect(r.formulaVersion, 'v1');
    });

    test('Soil 46% (OPTIMAL): Env (100+100+100+100)/4 = 100 -> PHI 66, v1.1-soil', () {
      final soil = SoilReading(
        percent: 46.0,
        status: SoilStatus.optimal,
        source: SoilSource.esp32,
        capturedAt: DateTime.now(),
      );
      final r = calculatePhi(communityGardenInputs, soil: soil);
      expect(r.soilScore, 100.0);
      expect(r.environmental, 100.0);
      expect(r.phi, 66);
      expect(r.tier, Tier.enhance);
      expect(r.formulaVersion, 'v1.1-soil');
      expect(r.environmentalBreakdown.first, 'Environmental = (100 + 100 + 100 + 100) / 4 = 100');
    });

    test('Soil 18% (DRY): Env (100+100+100+20)/4 = 80 -> PHI 62', () {
      final soil = SoilReading(
        percent: 18.0,
        status: SoilStatus.dry,
        source: SoilSource.esp32,
        capturedAt: DateTime.now(),
      );
      final r = calculatePhi(communityGardenInputs, soil: soil);
      expect(r.soilScore, 20.0);
      expect(r.environmental, 80.0);
      // Raw = 4.5 + 23.25 + 80*0.20(16) + 18 = 61.75 -> 62
      expect(r.phi, 62);
      expect(r.tier, Tier.enhance);
    });

    test('Soil 30% (LOW): Env (100+100+100+60)/4 = 90 -> PHI 64', () {
      final soil = SoilReading(
        percent: 30.0,
        status: SoilStatus.low,
        source: SoilSource.esp32,
        capturedAt: DateTime.now(),
      );
      final r = calculatePhi(communityGardenInputs, soil: soil);
      expect(r.soilScore, 60.0);
      expect(r.environmental, 90.0);
      // Raw = 4.5 + 23.25 + 90*0.20(18) + 18 = 63.75 -> 64
      expect(r.phi, 64);
      expect(r.tier, Tier.enhance);
    });
  });

  group('Tier Movement across boundary with soil', () {
    test('Boundary crossing: 62 ENHANCE without soil drops to 58 IMPROVE with DRY soil', () {
      // Build a case where raw is 61.75 -> 62 without soil, but drops with soil:
      // Activity: 2 visits in 5 min -> 10 pts (weight 0.3 = 3.0)
      // Habitat: (25+60+60+100)/4 = 61.25 pts (weight 0.3 = 18.375)
      // Temp 25(100), Hum 50(100), CO2 80(100) -> Env without soil = 100 (weight 0.2 = 20.0)
      // Risk Low(90) -> (weight 0.2 = 18.0)
      // Total without soil = 3.0 + 18.375 + 20.0 + 18.0 = 59.375 -> wait, let's make it 62:
      // Activity: 3 visits in 5 min -> 15 (weight 0.3 = 4.5)
      // Habitat: (60+60+90+100)/4 = 77.5 (weight 0.3 = 23.25)
      // Risk: Moderate(50) -> weight 0.2 = 10.0
      // Env without soil = 100 -> weight 0.2 = 20.0
      // Total without soil = 4.5 + 23.25 + 20.0 + 10.0 = 57.75.
      // With Risk Low(90, weight 0.2 = 18.0) and Env without soil = (60+100+100)/3 = 86.666
      // Let's test the worked boundary:
      final boundaryCase = AssessmentInputs(
        visits: 3,
        durationMinutes: 5,
        flowers: Level.medium,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present, // Habitat: (60+60+60+100)/4 = 70.0 -> *0.3 = 21.0
        temperatureC: 25.0,
        humidityPct: 50.0,
        co2Ppm: 80.0, // Env without soil = 100 -> *0.2 = 20.0
        risk: const RiskIndicators(),
        riskLevel: RiskLevel.low, // Risk 90 -> *0.2 = 18.0
        // Activity 3 visits -> 15 -> *0.3 = 4.5
        // Raw without soil = 4.5 + 21.0 + 20.0 + 18.0 = 63.5 -> 64 ENHANCE
      );
      final withoutSoil = calculatePhi(boundaryCase);
      expect(withoutSoil.phi, 64);
      expect(withoutSoil.tier, Tier.enhance);

      // Now add DRY soil (20 pts):
      // Env with soil = (100+100+100+20)/4 = 80.0 -> *0.2 = 16.0 (-4.0 pts)
      // Raw with soil = 4.5 + 21.0 + 16.0 + 18.0 = 59.5 -> wait, 59.5 rounds to 60 ENHANCE.
      // Let's adjust visits to 2 (10 pts -> *0.3 = 3.0):
      // Raw without soil = 3.0 + 21.0 + 20.0 + 18.0 = 62.0 -> 62 ENHANCE
      // Raw with DRY soil = 3.0 + 21.0 + 16.0 + 18.0 = 58.0 -> 58 IMPROVE!
      final crossingInputs = AssessmentInputs(
        visits: 2,
        durationMinutes: 5,
        flowers: Level.medium,
        nesting: Level.medium,
        shelter: Level.medium,
        water: Water.present,
        temperatureC: 25.0,
        humidityPct: 50.0,
        co2Ppm: 80.0,
        risk: const RiskIndicators(),
        riskLevel: RiskLevel.low,
      );
      final rBefore = calculatePhi(crossingInputs);
      expect(rBefore.phi, 62);
      expect(rBefore.tier, Tier.enhance);

      final rAfter = calculatePhi(
        crossingInputs,
        soil: SoilReading(
          percent: 15.0,
          status: SoilStatus.dry,
          source: SoilSource.esp32,
          capturedAt: DateTime.now(),
        ),
      );
      expect(rAfter.phi, 58);
      expect(rAfter.tier, Tier.improve); // Proven tier movement!
    });
  });

  group('SoilReading JSON Serialization & Tolerance', () {
    test('SoilReading roundtrips correctly', () {
      final now = DateTime.now();
      final reading = SoilReading(
        percent: 46.2,
        raw: 2310,
        status: SoilStatus.optimal,
        source: SoilSource.esp32,
        deviceId: 'a1b2c3d4',
        firmware: '1.0.0',
        stable: true,
        capturedAt: now,
        capturedLat: 13.0337,
        capturedLng: 80.2533,
      );

      final json = reading.toJson();
      expect(json['percent'], 46.2);
      expect(json['raw'], 2310);
      expect(json['status'], 'OPTIMAL');
      expect(json['source'], 'esp32');
      expect(json['deviceId'], 'a1b2c3d4');
      expect(json['firmware'], '1.0.0');
      expect(json['stable'], isTrue);
      expect(json['capturedLat'], 13.0337);
      expect(json['capturedLng'], 80.2533);

      final parsed = SoilReading.fromJson(json);
      expect(parsed.percent, 46.2);
      expect(parsed.raw, 2310);
      expect(parsed.status, SoilStatus.optimal);
      expect(parsed.source, SoilSource.esp32);
      expect(parsed.deviceId, 'a1b2c3d4');
      expect(parsed.firmware, '1.0.0');
      expect(parsed.stable, isTrue);
      expect(parsed.capturedLat, 13.0337);
      expect(parsed.capturedLng, 80.2533);
    });

    test('SoilReading.fromJson on empty legacy map produces safe defaults', () {
      final empty = SoilReading.fromJson({});
      expect(empty.percent, 0.0);
      expect(empty.status, SoilStatus.dry);
      expect(empty.source, SoilSource.manual);
      expect(empty.stable, isTrue);
    });
  });

  group('Score Formatter & Vocabulary', () {
    test('formatSubScore correctly formats integers vs decimals', () {
      expect(formatSubScore(77.5), '77.5');
      expect(formatSubScore(78.0), '78');
      expect(formatSubScore(100.0), '100');
      expect(formatSubScore(85.25), '85.3');
    });

    test('scoreBand vocabulary matches specification', () {
      expect(scoreBand(85), 'Good');
      expect(scoreBand(70), 'Fair');
      expect(scoreBand(50), 'Moderate');
      expect(scoreBand(30), 'Low');
      expect(scoreBand(10), 'Critical');
    });
  });

  group('Strengths and Limiting Factors with Soil', () {
    test('Soil phrases appear only when soil is present', () {
      final inputNoSoil = baseInputs();
      final rNoSoil = calculatePhi(inputNoSoil);
      final textNoSoil = explainScore(inputNoSoil, rNoSoil);
      expect(textNoSoil.contains('soil moisture'), isFalse);

      final soilOptimal = SoilReading(
        percent: 46.0,
        status: SoilStatus.optimal,
        source: SoilSource.esp32,
        capturedAt: DateTime.now(),
      );
      final inputWithSoil = baseInputs(soil: soilOptimal);
      final rWithSoil = calculatePhi(inputWithSoil);
      final textWithSoil = explainScore(inputWithSoil, rWithSoil);
      expect(textWithSoil.contains('soil moisture in the optimal range (46 %)'), isTrue);

      final soilDry = SoilReading(
        percent: 18.0,
        status: SoilStatus.dry,
        source: SoilSource.esp32,
        capturedAt: DateTime.now(),
      );
      final inputDry = baseInputs(soil: soilDry);
      final rDry = calculatePhi(inputDry);
      final textDry = explainScore(inputDry, rDry);
      expect(textDry.contains('dry soil (18 %) limiting flowering'), isTrue);
    });
  });
}
