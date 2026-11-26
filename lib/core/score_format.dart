/// Sub-score formatting and shared vocabulary helpers for P.U.L.S.E.
library;

/// Formats a sub-score (0-100) such that integers display without decimals
/// (e.g. 78 -> "78") and fractional numbers keep one decimal place (e.g. 77.5 -> "77.5").
String formatSubScore(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Unified status vocabulary for Activity, Habitat, and Environmental sub-scores.
String scoreBand(double s) {
  if (s >= 80) return 'Good';
  if (s >= 60) return 'Fair';
  if (s >= 40) return 'Moderate';
  if (s >= 20) return 'Low';
  return 'Critical';
}
