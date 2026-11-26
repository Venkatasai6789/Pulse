/// Turns a PhiResult + inputs into the text the Results screen shows:
/// tier content, sub-score labels, "Why this score?" and "What to do next?".
/// Pure Dart, no Flutter imports. Everything is generated from the
/// submitted data; nothing is hard-coded per location.
library;

import 'phi.dart';
import 'soil.dart';

class TierInfo {
  final Tier tier;
  final String label; // PROTECT
  final String categoryName; // Pollinator Paradise
  final String recommendation;
  final String range; // 80–100
  final int colorHex; // 0xFF2E7D32

  const TierInfo(this.tier, this.label, this.categoryName, this.recommendation, this.range,
      this.colorHex);
}

const Map<Tier, TierInfo> tierInfo = {
  Tier.protect: TierInfo(Tier.protect, 'PROTECT', 'Pollinator Paradise',
      'Maintain an excellent habitat and help neighbouring spaces improve.', '80–100', 0xFF2E7D32),
  Tier.enhance: TierInfo(Tier.enhance, 'ENHANCE', 'Pollinator Potential',
      'Add targeted habitat features and increase biodiversity.', '60–79', 0xFF7CB342),
  Tier.improve: TierInfo(Tier.improve, 'IMPROVE', 'Pollinator Recovery Zone',
      'Implement practical interventions that address the weakest ecological factors.', '40–59',
      0xFFF9A825),
  Tier.restore: TierInfo(Tier.restore, 'RESTORE', 'Pollinator Rescue Mission',
      'Rebuild essential habitat features through high-impact actions.', '20–39', 0xFFEF6C00),
  Tier.investigate: TierInfo(Tier.investigate, 'INVESTIGATE', 'Pollinator Emergency Audit',
      'Investigate possible threats, identify habitat gaps and seek expert or local authority support where appropriate.',
      '0–19', 0xFFC62828),
};

// ---------------------------------------------------------------------------
// Sub-score chips ("Good", "Ideal", "Low Risk" on the Results cards)
// ---------------------------------------------------------------------------

String activityLabel(double s) => _band(s);
String habitatLabel(double s) => _band(s);

String environmentLabel(double s) {
  if (s >= 100) return 'Ideal';
  if (s >= 80) return 'Good';
  if (s >= 50) return 'Moderate';
  return 'Stressful';
}

String riskLabel(RiskLevel l) => switch (l) {
      RiskLevel.low => 'Low Risk',
      RiskLevel.moderate => 'Moderate Risk',
      RiskLevel.high => 'High Risk',
    };

String _band(double s) {
  if (s >= 80) return 'Good';
  if (s >= 60) return 'Fair';
  if (s >= 40) return 'Needs work';
  return 'Critical';
}

String levelName(Level l) => switch (l) {
      Level.low => 'Low',
      Level.medium => 'Medium',
      Level.high => 'High',
    };

String bandName(int points) => switch (points) {
      100 => 'suitable',
      60 => 'moderate',
      _ => 'stressful',
    };

// ---------------------------------------------------------------------------
// "Why this score?"
// ---------------------------------------------------------------------------

String explainScore(AssessmentInputs i, PhiResult r) {
  final strengths = <String>[];
  final gaps = <String>[];

  if (r.activity >= 80) {
    strengths.add('high pollinator activity');
  } else if (r.activity < 60) {
    gaps.add('low pollinator activity (${i.visits} visits in ${i.durationMinutes} min)');
  }

  if (r.habitat >= 80) {
    strengths.add('good habitat features');
  } else if (r.habitat < 60) {
    final weak = <String>[
      if (i.flowers == Level.low) 'flowers',
      if (i.nesting == Level.low) 'nesting spaces',
      if (i.shelter == Level.low) 'shelter',
      if (i.water == Water.absent) 'water',
    ];
    gaps.add(weak.isEmpty ? 'limited habitat features' : 'limited ${_join(weak)}');
  }

  if (r.environmental >= 100) {
    strengths.add('suitable environmental conditions');
  } else {
    final off = <String>[
      if (r.temperaturePoints < 100) '${bandName(r.temperaturePoints)} temperature',
      if (r.humidityPoints < 100) '${bandName(r.humidityPoints)} humidity',
      if (r.co2Points < 100) '${bandName(r.co2Points)} CO₂ levels',
    ];
    if (r.environmental < 80) {
      gaps.add(_join(off));
    } else {
      strengths.add('mostly suitable conditions');
    }
  }

  // Soil phrases appear only when soil is present
  final soil = r.soil ?? i.soil;
  if (soil != null) {
    final pctInt = soil.percent.round();
    switch (soil.status) {
      case SoilStatus.optimal:
        strengths.add('soil moisture in the optimal range ($pctInt %)');
        break;
      case SoilStatus.dry:
        gaps.add('dry soil ($pctInt %) limiting flowering');
        break;
      case SoilStatus.wet:
        gaps.add('waterlogged soil ($pctInt %)');
        break;
      case SoilStatus.low:
      case SoilStatus.moist:
        gaps.add('soil moisture slightly outside the optimal range');
        break;
    }
  }

  if (r.riskLevel == RiskLevel.low) {
    strengths.add('low risk factors');
  } else {
    gaps.add(r.riskLevel == RiskLevel.high
        ? 'potentially serious risk indicators nearby'
        : 'a potential risk indicator nearby');
  }

  final b = StringBuffer();
  if (strengths.isNotEmpty) {
    b.write('Your location has ${_join(strengths)}');
    b.write(gaps.isEmpty ? ', making it a healthy habitat for pollinators.' : '. ');
  }
  if (gaps.isNotEmpty) {
    b.write(strengths.isEmpty ? 'Your score is held back by ' : 'It is held back by ');
    b.write('${_join(gaps)}.');
  }
  return b.toString().trim();
}

String _join(List<String> xs) {
  if (xs.isEmpty) return '';
  if (xs.length == 1) return xs.first;
  return '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
}

// ---------------------------------------------------------------------------
// "What to do next?"  (weakest factors first, max 4, then tier defaults)
// ---------------------------------------------------------------------------

List<String> nextSteps(AssessmentInputs i, PhiResult r, {int max = 4}) {
  final steps = <String>[];

  // Risk first: a serious local concern always leads.
  if (i.risk.pesticide || i.risk.chemical) {
    steps.add('Talk to neighbours or site management about pesticide-free and organic practices');
  }
  if (r.riskLevel == RiskLevel.high) {
    steps.add('Record dates and photos of the concern and contact the local authority if it continues');
  }
  if (i.risk.traffic) steps.add('Plant a hedge or dense shrubs as a buffer against traffic and pollution');

  if (i.water == Water.absent) steps.add('Add a shallow water dish with stones so pollinators can land');
  if (i.flowers != Level.high) {
    steps.add('Plant native flowering species with staggered bloom times across the seasons');
  }
  if (i.nesting != Level.high) {
    steps.add('Leave bare soil patches, dead wood or a bee hotel for nesting');
  }
  if (i.shelter != Level.high) steps.add('Add shrubs, hedgerows or leaf litter for shelter');

  if (r.temperaturePoints < 100) steps.add('Add shade plants or trees to soften temperature extremes');
  if (r.humidityPoints < 100) steps.add('Mulch beds and water plants in the morning to steady humidity');
  if (r.co2Points < 100) steps.add('Increase greenery and discourage idling vehicles nearby');

  // Soil actions (at most 2 when soil is present)
  final soil = r.soil ?? i.soil;
  if (soil != null) {
    if (soil.status == SoilStatus.dry || soil.status == SoilStatus.low) {
      steps.add('Mulch beds 5–7 cm to hold moisture');
      steps.add('Water early morning during dry spells');
    } else if (soil.status == SoilStatus.wet || soil.status == SoilStatus.moist) {
      steps.add('Improve drainage around the bed');
      steps.add('Leave some bare, well-drained soil for ground-nesting bees');
    }
  }

  if (r.activity < 60) {
    steps.add('Repeat the 5-minute count between 10 and 11 AM on a calm, sunny day to confirm activity');
  }

  // Tier defaults fill any remaining slots.
  final defaults = switch (r.tier) {
    Tier.protect => [
        'Keep maintaining native flowering plants',
        'Ensure water sources remain available',
        'Continue regular monitoring',
        'Share what works with neighbouring spaces',
      ],
    Tier.enhance => [
        'Add one new habitat feature this month',
        'Increase plant variety to boost biodiversity',
        'Reassess in four weeks to track progress',
      ],
    Tier.improve => [
        'Focus on the weakest parameter first',
        'Reassess in two to four weeks',
      ],
    Tier.restore => [
        'Prioritise flowers and water as high-impact first steps',
        'Involve your community or society in a planting day',
      ],
    Tier.investigate => [
        'Investigate possible threats around the site',
        'Seek expert or local authority support',
      ],
  };
  for (final d in defaults) {
    if (!steps.contains(d)) steps.add(d);
  }
  return steps.take(max).toList();
}
