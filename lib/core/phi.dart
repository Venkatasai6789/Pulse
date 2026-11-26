/// P.U.L.S.E. scoring engine.
///
/// Pure Dart, no Flutter imports, so it can be unit tested on its own and the
/// backend team can use it as the reference implementation.
///
/// All ranges here are PROTOTYPE values from the client brief. They are not
/// universal biological thresholds. Every stored assessment keeps
/// [scoringVersion] so old PHIs stay reproducible if the ranges change later.
library;

import 'soil.dart';
import 'soil_reading.dart';

const String scoringVersion = 'proto-1';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum Level { low, medium, high }

enum Water { present, absent }

enum RiskLevel { low, moderate, high }

enum Tier { protect, enhance, improve, restore, investigate }

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

class RiskIndicators {
  final bool pesticide;
  final bool chemical;
  final bool traffic;
  final bool other;

  const RiskIndicators({
    this.pesticide = false,
    this.chemical = false,
    this.traffic = false,
    this.other = false,
  });

  int get count => [pesticide, chemical, traffic, other].where((x) => x).length;

  RiskIndicators copyWith({bool? pesticide, bool? chemical, bool? traffic, bool? other}) =>
      RiskIndicators(
        pesticide: pesticide ?? this.pesticide,
        chemical: chemical ?? this.chemical,
        traffic: traffic ?? this.traffic,
        other: other ?? this.other,
      );

  Map<String, dynamic> toJson() => {
        'pesticide': pesticide,
        'chemical': chemical,
        'traffic': traffic,
        'other': other,
      };

  factory RiskIndicators.fromJson(Map<String, dynamic>? j) => RiskIndicators(
        pesticide: j?['pesticide'] == true,
        chemical: j?['chemical'] == true,
        traffic: j?['traffic'] == true,
        other: j?['other'] == true,
      );
}

/// Complete, validated inputs for one assessment. Drafts live in the
/// Assessment model with nullable fields; only a complete draft becomes this.
class AssessmentInputs {
  final int visits;
  final int durationMinutes;
  final Level flowers;
  final Level nesting;
  final Level shelter;
  final Water water;
  final double temperatureC;
  final double humidityPct;
  final double co2Ppm;
  final RiskIndicators risk;

  /// Selected by the user in the Risk Level dropdown (as per the design).
  final RiskLevel riskLevel;

  /// Optional soil moisture reading from ESP32 node or manual entry.
  final SoilReading? soil;
  final double? soilMoisturePercent;

  const AssessmentInputs({
    required this.visits,
    required this.durationMinutes,
    required this.flowers,
    required this.nesting,
    required this.shelter,
    required this.water,
    required this.temperatureC,
    required this.humidityPct,
    required this.co2Ppm,
    required this.risk,
    required this.riskLevel,
    this.soil,
    this.soilMoisturePercent,
  });
}

// ---------------------------------------------------------------------------
// Validation limits (sanity ranges for numeric inputs)
// ---------------------------------------------------------------------------

class Limits {
  static const int maxVisits = 500;
  static const double minTemp = -20;
  static const double maxTemp = 60;
  static const double minCo2 = 0;
  static const double maxCo2 = 10000;
  static const List<int> durations = [5, 10, 15, 20, 30];
}

// ---------------------------------------------------------------------------
// A. Pollinator Activity
// ---------------------------------------------------------------------------

/// Activity Score = (visits per 5 minutes ÷ 20) × 100, capped at 100.
/// Visits are normalised to a 5-minute window so a 10-minute count
/// isn't double-counted.
double activityScore(int visits, {int durationMinutes = 5}) {
  if (visits < 0 || visits > Limits.maxVisits) {
    throw ArgumentError.value(visits, 'visits', 'must be 0..${Limits.maxVisits}');
  }
  if (durationMinutes <= 0) {
    throw ArgumentError.value(durationMinutes, 'durationMinutes', 'must be > 0');
  }
  final visitsPer5Min = visits * 5 / durationMinutes;
  final score = visitsPer5Min * 5; // same as ÷20 ×100, without float noise
  return score > 100 ? 100.0 : score;
}

// ---------------------------------------------------------------------------
// B. Habitat Quality
// ---------------------------------------------------------------------------

int levelScore(Level l) => switch (l) {
      Level.low => 25,
      Level.medium => 60,
      Level.high => 90,
    };

int waterScore(Water w) => w == Water.present ? 100 : 0;

double habitatScore(Level flowers, Level nesting, Level shelter, Water water) =>
    (levelScore(flowers) + levelScore(nesting) + levelScore(shelter) + waterScore(water)) / 4;

// ---------------------------------------------------------------------------
// C. Environmental Conditions  (closed boundary rules, every value maps once)
// ---------------------------------------------------------------------------

void _checkFinite(double v, String name) {
  if (v.isNaN || v.isInfinite) throw ArgumentError.value(v, name, 'must be a number');
}

/// Suitable 18 ≤ T ≤ 30 → 100
/// Moderate 15 ≤ T < 18 or 30 < T ≤ 34 → 60
/// Stressful T < 15 or T > 34 → 20
int temperatureScore(double t) {
  _checkFinite(t, 'temperatureC');
  if (t < Limits.minTemp || t > Limits.maxTemp) {
    throw ArgumentError.value(t, 'temperatureC', 'must be ${Limits.minTemp}..${Limits.maxTemp}');
  }
  if (t >= 18 && t <= 30) return 100;
  if ((t >= 15 && t < 18) || (t > 30 && t <= 34)) return 60;
  return 20;
}

/// Suitable 50 ≤ H ≤ 70 → 100
/// Moderate 35 ≤ H < 50 or 70 < H ≤ 85 → 60
/// Stressful H < 35 or H > 85 → 20
int humidityScore(double h) {
  _checkFinite(h, 'humidityPct');
  if (h < 0 || h > 100) throw ArgumentError.value(h, 'humidityPct', 'must be 0..100');
  if (h >= 50 && h <= 70) return 100;
  if ((h >= 35 && h < 50) || (h > 70 && h <= 85)) return 60;
  return 20;
}

/// Suitable C < 800 → 100
/// Moderate 800 ≤ C ≤ 1000 → 60
/// Stressful C > 1000 → 20
int co2Score(double c) {
  _checkFinite(c, 'co2Ppm');
  if (c < Limits.minCo2 || c > Limits.maxCo2) {
    throw ArgumentError.value(c, 'co2Ppm', 'must be ${Limits.minCo2}..${Limits.maxCo2}');
  }
  if (c < 800) return 100;
  if (c <= 1000) return 60;
  return 20;
}

double environmentalScore(
  double temperatureC,
  double humidityPct,
  double co2Ppm, [
  double? soilPercent,
]) {
  final tp = temperatureScore(temperatureC);
  final hp = humidityScore(humidityPct);
  final cp = co2Score(co2Ppm);
  if (soilPercent != null && !soilPercent.isNaN) {
    final sp = soilScore(soilPercent);
    return (tp + hp + cp + sp) / 4.0;
  }
  return (tp + hp + cp) / 3.0;
}

// ---------------------------------------------------------------------------
// D. Potential Environmental / Chemical Risk
// ---------------------------------------------------------------------------

/// The Risk Level itself is picked by the user in the dropdown (design choice).
/// This function only gives a SUGGESTION shown under the dropdown, e.g.
/// "Based on your selections we suggest: High". Prototype rule, to be
/// reviewed with an environmental expert:
///  - High:     pesticide spraying or chemical use observed, or 2+ indicators
///  - Moderate: exactly one indicator (traffic/pollution or other concern)
///  - Low:      no indicators
RiskLevel suggestedRiskLevel(RiskIndicators r) {
  if (r.pesticide || r.chemical || r.count >= 2) return RiskLevel.high;
  if (r.count == 1) return RiskLevel.moderate;
  return RiskLevel.low;
}

int riskScore(RiskLevel level) => switch (level) {
      RiskLevel.low => 90,
      RiskLevel.moderate => 50,
      RiskLevel.high => 10,
    };

// ---------------------------------------------------------------------------
// PHI
// ---------------------------------------------------------------------------

const double wActivity = 0.30;
const double wHabitat = 0.30;
const double wEnvironmental = 0.20;
const double wRisk = 0.20;

/// Rounds half up (90.5 → 91). The epsilon guards against float noise such
/// as 79.49999999 when the true value is 79.5.
int roundHalfUp(double v) => (v + 0.5 + 1e-9).floor();

/// Unrounded PHI, computed with integer weights to keep float noise down.
double rawPhi(double activity, double habitat, double environmental, double risk) =>
    (activity * 30 + habitat * 30 + environmental * 20 + risk * 20) / 100;

/// Tier is ALWAYS assigned from the rounded PHI.
Tier tierFor(int phi) {
  if (phi < 0 || phi > 100) throw ArgumentError.value(phi, 'phi', 'must be 0..100');
  if (phi >= 80) return Tier.protect;
  if (phi >= 60) return Tier.enhance;
  if (phi >= 40) return Tier.improve;
  if (phi >= 20) return Tier.restore;
  return Tier.investigate;
}

class PhiResult {
  final double activity;
  final double habitat;
  final double environmental;
  final int risk;
  final RiskLevel riskLevel;
  final int temperaturePoints;
  final int humidityPoints;
  final int co2Points;
  final double raw;
  final int phi;
  final Tier tier;
  final String version;
  final double? soilScore;
  final SoilReading? soil;
  final String formulaVersion;
  final List<String> environmentalBreakdown;

  const PhiResult({
    required this.activity,
    required this.habitat,
    required this.environmental,
    required this.risk,
    required this.riskLevel,
    required this.temperaturePoints,
    required this.humidityPoints,
    required this.co2Points,
    required this.raw,
    required this.phi,
    required this.tier,
    this.version = scoringVersion,
    this.soilScore,
    this.soil,
    this.formulaVersion = 'v1',
    this.environmentalBreakdown = const [],
  });

  bool get highRiskAlert => riskLevel == RiskLevel.high;

  Map<String, dynamic> toJson() => {
        'activity': activity,
        'habitat': habitat,
        'environmental': environmental,
        'risk': risk,
        'riskLevel': riskLevel.name,
        'temperaturePoints': temperaturePoints,
        'humidityPoints': humidityPoints,
        'co2Points': co2Points,
        'raw': raw,
        'phi': phi,
        'tier': tier.name,
        'version': version,
        'soilScore': soilScore,
        if (soil != null) 'soil': soil!.toJson(),
        'formulaVersion': formulaVersion,
        'environmentalBreakdown': environmentalBreakdown,
      };

  factory PhiResult.fromJson(Map<String, dynamic> j) => PhiResult(
        activity: (j['activity'] as num).toDouble(),
        habitat: (j['habitat'] as num).toDouble(),
        environmental: (j['environmental'] as num).toDouble(),
        risk: (j['risk'] as num).toInt(),
        riskLevel: RiskLevel.values.byName(j['riskLevel'] as String),
        temperaturePoints: (j['temperaturePoints'] as num).toInt(),
        humidityPoints: (j['humidityPoints'] as num).toInt(),
        co2Points: (j['co2Points'] as num).toInt(),
        raw: (j['raw'] as num).toDouble(),
        phi: (j['phi'] as num).toInt(),
        tier: Tier.values.byName(j['tier'] as String),
        version: (j['version'] as String?) ?? scoringVersion,
        soilScore: (j['soilScore'] as num?)?.toDouble(),
        soil: j['soil'] != null
            ? SoilReading.fromJson(Map<String, dynamic>.from(j['soil'] as Map))
            : null,
        formulaVersion: (j['formulaVersion'] as String?) ??
            (j['soilScore'] != null || j['soil'] != null ? 'v1.1-soil' : 'v1'),
        environmentalBreakdown: (j['environmentalBreakdown'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// The single entry point screens and the backend should call.
PhiResult calculatePhi(AssessmentInputs i, {SoilReading? soil}) {
  final a = activityScore(i.visits, durationMinutes: i.durationMinutes);
  final h = habitatScore(i.flowers, i.nesting, i.shelter, i.water);
  final tp = temperatureScore(i.temperatureC);
  final hp = humidityScore(i.humidityPct);
  final cp = co2Score(i.co2Ppm);

  final effectiveSoil = soil ?? i.soil;
  final sPct = effectiveSoil?.percent ?? i.soilMoisturePercent;

  final double e;
  final double? sp;
  final String formulaVer;
  final List<String> envBreakdown = [];

  if (sPct != null && !sPct.isNaN) {
    final clampedPct = sPct.clamp(0.0, 100.0);
    final scoreS = soilScore(clampedPct);
    sp = scoreS;
    e = (tp + hp + cp + scoreS) / 4.0;
    formulaVer = 'v1.1-soil';
    final intScoreS = scoreS.toInt();
    final eFmt = e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1);
    envBreakdown.add('Environmental = ($tp + $hp + $cp + $intScoreS) / 4 = $eFmt');
  } else {
    sp = null;
    e = (tp + hp + cp) / 3.0;
    formulaVer = 'v1';
    final eFmt = e == e.roundToDouble() ? e.toStringAsFixed(0) : e.toStringAsFixed(1);
    envBreakdown.add('Environmental = ($tp + $hp + $cp) / 3 = $eFmt');
  }

  final level = i.riskLevel;
  final r = riskScore(level);
  final raw = rawPhi(a, h, e, r.toDouble());
  final phi = roundHalfUp(raw).clamp(0, 100).toInt();

  return PhiResult(
    activity: a,
    habitat: h,
    environmental: e,
    risk: r,
    riskLevel: level,
    temperaturePoints: tp,
    humidityPoints: hp,
    co2Points: cp,
    raw: raw,
    phi: phi,
    tier: tierFor(phi),
    soilScore: sp,
    soil: effectiveSoil,
    formulaVersion: formulaVer,
    environmentalBreakdown: envBreakdown,
  );
}
