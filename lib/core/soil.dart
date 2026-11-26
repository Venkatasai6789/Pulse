/// Soil moisture scoring and classification for P.U.L.S.E.
///
/// Single source of truth mirroring firmware `soil_sensor.cpp`.
/// Prototype bands based on calibrated probe percentage.
library;

enum SoilStatus { dry, low, optimal, moist, wet }

/// Wire codes used across Firmware, App, and Firestore
const Map<SoilStatus, String> _soilStatusCodes = {
  SoilStatus.dry: 'DRY',
  SoilStatus.low: 'LOW',
  SoilStatus.optimal: 'OPTIMAL',
  SoilStatus.moist: 'MOIST',
  SoilStatus.wet: 'WET',
};

const Map<SoilStatus, String> _soilStatusLabels = {
  SoilStatus.dry: 'Dry',
  SoilStatus.low: 'Low',
  SoilStatus.optimal: 'Optimal',
  SoilStatus.moist: 'Moist',
  SoilStatus.wet: 'Waterlogged',
};

const Map<SoilStatus, String> _soilBandLabels = {
  SoilStatus.dry: 'Stressful',
  SoilStatus.low: 'Moderate',
  SoilStatus.optimal: 'Suitable',
  SoilStatus.moist: 'Moderate',
  SoilStatus.wet: 'Stressful',
};

const Map<SoilStatus, String> _soilAdviceKeys = {
  SoilStatus.dry: 'dry',
  SoilStatus.low: 'low',
  SoilStatus.optimal: 'optimal',
  SoilStatus.moist: 'moist',
  SoilStatus.wet: 'wet',
};

/// Classifies a calibrated moisture percentage (0-100) into a [SoilStatus].
SoilStatus soilStatusFor(double percent) {
  if (percent.isNaN) return SoilStatus.optimal;
  final p = percent.clamp(0.0, 100.0);
  if (p < 25.0) return SoilStatus.dry;
  if (p < 40.0) return SoilStatus.low;
  if (p <= 60.0) return SoilStatus.optimal;
  if (p <= 75.0) return SoilStatus.moist;
  return SoilStatus.wet;
}

/// Computes the environmental points awarded for soil moisture (100, 60, or 20).
double soilScore(double percent) {
  final status = soilStatusFor(percent);
  switch (status) {
    case SoilStatus.optimal:
      return 100.0;
    case SoilStatus.low:
    case SoilStatus.moist:
      return 60.0;
    case SoilStatus.dry:
    case SoilStatus.wet:
      return 20.0;
  }
}

String soilStatusCode(SoilStatus s) => _soilStatusCodes[s] ?? 'OPTIMAL';

SoilStatus? soilStatusFromCode(String? code) {
  if (code == null) return null;
  final upper = code.trim().toUpperCase();
  for (final entry in _soilStatusCodes.entries) {
    if (entry.value == upper) return entry.key;
  }
  return null;
}

String soilStatusLabel(SoilStatus s) => _soilStatusLabels[s] ?? 'Optimal';

String soilLabel(SoilStatus s) => soilStatusLabel(s);

String soilBandLabel(SoilStatus s) => _soilBandLabels[s] ?? 'Suitable';

String soilAdviceKey(SoilStatus s) => _soilAdviceKeys[s] ?? 'optimal';
