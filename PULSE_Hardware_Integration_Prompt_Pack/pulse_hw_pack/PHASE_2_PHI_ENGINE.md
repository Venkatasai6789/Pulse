# Phase 2 — PHI Engine: Soil Moisture Scoring (pure Dart)

Scope: `lib/core/` and `test/` only. No UI, no Flutter imports in the new core files.

## 2.1 The rule in one line

Soil moisture becomes an **optional fourth input to the Environmental sub-score**. The parameter weights stay **30 / 30 / 20 / 20**. With no soil reading, every number is identical to today.

```
Environmental (no soil)   = (Score_T + Score_H + Score_C) / 3                  ← unchanged
Environmental (with soil) = (Score_T + Score_H + Score_C + Score_S) / 4
PHI = round(Activity×0.30 + Habitat×0.30 + Environmental×0.20 + Risk×0.20)     ← unchanged
```

Why this design: soil water drives nectar and pollen production, so it belongs with the other microclimate factors. Keeping it inside Environmental means the "Four Parameters" model that users see on Home, Review and Results doesn't change shape, and historical assessments stay comparable.

## 2.2 New file `lib/core/soil.dart`

```dart
enum SoilStatus { dry, low, optimal, moist, wet }   // wire codes: DRY LOW OPTIMAL MOIST WET

SoilStatus soilStatusFor(double percent);
double soilScore(double percent);                   // 100 / 60 / 20
String soilStatusCode(SoilStatus s);                // 'OPTIMAL'
SoilStatus? soilStatusFromCode(String? code);       // tolerant parse, null on unknown
String soilStatusLabel(SoilStatus s);               // 'Dry','Low','Optimal','Moist','Waterlogged'
String soilBandLabel(SoilStatus s);                 // 'Suitable','Moderate','Stressful' (same chip words as T/H/CO₂)
String soilAdviceKey(SoilStatus s);                 // used by Results "What to do next"
```

Scoring table. This is the single source of truth, and it mirrors the firmware `soil_sensor` (put a comment in both files pointing to the other).

| Percent S | Status | Points | Chip | Label |
|---|---|---|---|---|
| S < 25 | `DRY` | 20 | Stressful | Dry |
| 25 ≤ S < 40 | `LOW` | 60 | Moderate | Low |
| 40 ≤ S ≤ 60 | `OPTIMAL` | 100 | Suitable | Optimal |
| 60 < S ≤ 75 | `MOIST` | 60 | Moderate | Moist |
| S > 75 | `WET` | 20 | Stressful | Waterlogged |

Input validation: clamp to 0–100. `NaN` and negative values are a programming error, so assert in debug and treat as null (no soil) in release.

Note for `docs/`: these are prototype bands based on the sensor's calibrated percent, not lab volumetric water content. Say this in the existing "About PHI Formula" info sheet the same way the CO₂ ranges are described as prototype ranges.

## 2.3 New model `lib/core/soil_reading.dart` (pure Dart, JSON in and out)

```dart
class SoilReading {
  final double percent;            // 0–100
  final int? raw;                  // 0–4095, null for manual
  final SoilStatus status;
  final SoilSource source;         // esp32 | manual
  final String? deviceId;
  final String? firmware;
  final bool stable;               // from firmware; manual = true
  final DateTime capturedAt;
  final double? capturedLat;       // phone GPS at capture (nullable)
  final double? capturedLng;
  Map<String, dynamic> toJson();
  factory SoilReading.fromJson(Map<String, dynamic> j);   // tolerant: missing fields → sensible defaults
}
```

## 2.4 Minimal change to `lib/core/phi.dart`

- Add `SoilReading? soil` (or `double? soilMoisturePercent`, whichever matches the existing input model's style) as an **optional named parameter defaulting to null** on the PHI input model and the calculate function. Existing call sites must compile unchanged.
- The Environmental computation branches on null exactly as in §2.1.
- Add to the result model:
  - `double? soilScore`: null when no soil
  - `String formulaVersion`: `'v1'` without soil, `'v1.1-soil'` with soil
  - `List<String>` environmental breakdown lines for the Results "How PHI is calculated" expander, for example `Env = (100 + 100 + 100 + 100) / 4 = 100`. If the result model already exposes a breakdown, extend it rather than adding a parallel one.
- Strengths and limiting factors (used by "Why this score?"): add soil phrases **only when soil is present**:
  - OPTIMAL → strength `"soil moisture in the optimal range (46 %)"`
  - DRY → limiting `"dry soil (18 %) limiting flowering"`
  - WET → limiting `"waterlogged soil (82 %)"`
  - LOW / MOIST → mild limiting `"soil moisture slightly outside the optimal range"`
- Rounding: keep the current rounding exactly. The Environmental sub-score with soil can be a fraction (for example 85.0 or 90.0). Store the unrounded value, as the other sub-scores do.

## 2.5 Display formatting helper (fixes an existing inconsistency)

The audit found Habitat shown as **77.5** on Step 2 and Results but **78** on the Review score strip. Add one helper in `lib/core/score_format.dart`:

```dart
String formatSubScore(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
```

Use it in Phase 4/5 wherever a sub-score is printed. In this phase, only create it and test it. The PHI total keeps its existing integer rounding.

## 2.6 Live preview ("predict as you go")

The Review step's Live PHI Preview already recalculates from draft inputs. Check that it reads the draft through the same calculate function, so it picks up soil automatically once the draft carries a `SoilReading`. If the preview duplicates the formula anywhere, **route it through `phi.dart` instead**. That is the only allowed edit outside `lib/core` in this phase. List it in the Walkthrough.

## 2.7 Tests — new file `test/soil_phi_test.dart`

1. **Bands:** 0, 24.9 → DRY/20 · 25, 39.9 → LOW/60 · 40, 60 → OPTIMAL/100 · 60.1, 75 → MOIST/60 · 75.1, 100 → WET/20.
2. **Regression:** for every reference sample already used in `test/phi_test.dart`, calculate with `soil: null` and assert PHI, every sub-score, and the tier are **identical** to the current expected values. Import the samples rather than copying them, if they're accessible.
3. **Worked example from the real app data** (Community Garden, 14 Nov, PHI 66):
   - Activity 15, Habitat 77.5, T 25 °C, H 50 %, CO₂ 80 ppm, Risk Low (90)
   - no soil → Env 100 → PHI 66 (65.75 rounded), formulaVersion `v1`
   - soil 46 % → Env (100+100+100+100)/4 = 100 → PHI 66, `v1.1-soil`
   - soil 18 % → Env (100+100+100+20)/4 = 80 → PHI round(4.5 + 23.25 + 16 + 18) = **62**
   - soil 30 % → Env 90 → PHI round(4.5 + 23.25 + 18 + 18) = **64**
4. **Tier movement:** build a case where soil moves the tier across a boundary (for example 62 ENHANCE without soil → 58 IMPROVE with DRY soil: with T/H/CO₂ all at 100, DRY soil drops Environmental from 100 to 80, which is −4 PHI), so the effect is visible and tested.
5. **JSON:** a `SoilReading` round-trips, and `fromJson` on `{}`-like legacy maps doesn't throw.
6. **Formatter:** `formatSubScore(77.5) == '77.5'`, `formatSubScore(78.0) == '78'`.
7. **Strengths and limiting factors:** soil phrases appear only when soil is present.

## 2.8 Done when

- `flutter test` = 93 existing (unchanged) + the new soil tests, all green
- `flutter analyze` is clean
- the Walkthrough shows the `phi.dart` diff (it should be small) and the regression test output
