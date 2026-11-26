import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/core/recommendations.dart';

AssessmentInputs garden({
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
  RiskIndicators indicators = const RiskIndicators(),
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
      risk: indicators,
      riskLevel: risk,
    );

void main() {
  group('Brief test case: Community Garden', () {
    final r = calculatePhi(garden());
    test('sub-scores', () {
      expect(r.activity, 90);
      expect(r.habitat, 85);
      expect(r.environmental, 100);
      expect(r.risk, 90);
    });
    test('raw 90.5 rounds to 91, PROTECT', () {
      expect(r.raw, closeTo(90.5, 1e-9));
      expect(r.phi, 91);
      expect(r.tier, Tier.protect);
      expect(tierInfo[r.tier]!.categoryName, 'Pollinator Paradise');
    });
  });

  group('Tier boundaries', () {
    final cases = {
      0: Tier.investigate, 19: Tier.investigate,
      20: Tier.restore, 39: Tier.restore,
      40: Tier.improve, 59: Tier.improve,
      60: Tier.enhance, 79: Tier.enhance,
      80: Tier.protect, 100: Tier.protect,
    };
    cases.forEach((phi, tier) => test('$phi -> ${tier.name}', () => expect(tierFor(phi), tier)));
    test('out of range throws', () {
      expect(() => tierFor(-1), throwsArgumentError);
      expect(() => tierFor(101), throwsArgumentError);
    });
  });

  group('Round half up', () {
    test('x.5 goes up', () {
      expect(roundHalfUp(90.5), 91);
      expect(roundHalfUp(79.5), 80);
      expect(roundHalfUp(59.5), 60);
      expect(roundHalfUp(39.5), 40);
      expect(roundHalfUp(19.5), 20);
    });
    test('below .5 goes down', () {
      expect(roundHalfUp(79.49), 79);
      expect(roundHalfUp(11.625), 12);
    });
  });

  group('Activity', () {
    test('20 visits = 100, capped above', () {
      expect(activityScore(20), 100);
      expect(activityScore(40), 100);
      expect(activityScore(0), 0);
    });
    test('normalised to 5 minutes', () => expect(activityScore(36, durationMinutes: 10), 90));
    test('negative throws', () => expect(() => activityScore(-1), throwsArgumentError));
  });

  group('Habitat', () {
    test('all low, no water = 18.75', () {
      expect(habitatScore(Level.low, Level.low, Level.low, Water.absent), 18.75);
    });
    test('all high + water = 92.5', () {
      expect(habitatScore(Level.high, Level.high, Level.high, Water.present), 92.5);
    });
  });

  group('Temperature boundaries', () {
    final cases = {14.9: 20, 15.0: 60, 17.9: 60, 18.0: 100, 30.0: 100, 30.1: 60, 34.0: 60, 34.1: 20};
    cases.forEach((t, s) => test('$t°C -> $s', () => expect(temperatureScore(t), s)));
  });

  group('Humidity boundaries', () {
    final cases = {34.9: 20, 35.0: 60, 49.9: 60, 50.0: 100, 70.0: 100, 70.1: 60, 85.0: 60, 85.1: 20};
    cases.forEach((h, s) => test('$h% -> $s', () => expect(humidityScore(h), s)));
    test('over 100 throws', () => expect(() => humidityScore(101), throwsArgumentError));
  });

  group('CO2 boundaries', () {
    final cases = {799.0: 100, 800.0: 60, 1000.0: 60, 1001.0: 20};
    cases.forEach((c, s) => test('$c ppm -> $s', () => expect(co2Score(c), s)));
  });

  group('Risk', () {
    test('scores', () {
      expect(riskScore(RiskLevel.low), 90);
      expect(riskScore(RiskLevel.moderate), 50);
      expect(riskScore(RiskLevel.high), 10);
    });
    test('suggestion from checkboxes', () {
      expect(suggestedRiskLevel(const RiskIndicators()), RiskLevel.low);
      expect(suggestedRiskLevel(const RiskIndicators(traffic: true)), RiskLevel.moderate);
      expect(suggestedRiskLevel(const RiskIndicators(pesticide: true)), RiskLevel.high);
      expect(suggestedRiskLevel(const RiskIndicators(traffic: true, other: true)), RiskLevel.high);
    });
    test('high risk alert shows even in PROTECT', () {
      final r = calculatePhi(garden(visits: 20, flowers: Level.high, nesting: Level.high, risk: RiskLevel.high));
      expect(r.tier, Tier.protect);
      expect(r.highRiskAlert, isTrue);
    });
  });

  group('Real-world range', () {
    test('worst possible inputs = 12', () {
      final r = calculatePhi(garden(
          visits: 0, flowers: Level.low, nesting: Level.low, shelter: Level.low,
          water: Water.absent, temp: 5, humidity: 20, co2: 2000, risk: RiskLevel.high));
      expect(r.phi, 12);
      expect(r.tier, Tier.investigate);
    });
    test('best possible inputs = 96', () {
      final r = calculatePhi(garden(visits: 25, flowers: Level.high, nesting: Level.high));
      expect(r.phi, 96);
    });
  });

  group('Recommendations', () {
    test('garden explanation and steps are generated', () {
      final i = garden();
      final r = calculatePhi(i);
      expect(explainScore(i, r), contains('high pollinator activity'));
      expect(nextSteps(i, r), isNotEmpty);
      expect(nextSteps(i, r).length, lessThanOrEqualTo(4));
    });
  });
}
