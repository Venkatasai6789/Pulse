# 00 — Master Context Prompt (paste this first)

You are joining an existing, working Flutter project: **P.U.L.S.E.** (Pollinator Unified Landscape & Sustainability Ecosystem), an Android app that scores pollinator habitat with a Pollinator Health Index (PHI, 0–100). Read `README.md` in the repo root for the full feature list before doing anything else.

We are now adding a hardware sensor node, an **ESP32 with a soil moisture sensor and an I2C 16x2 LCD**. We are also fixing a set of UI defects found in a screenshot review. The work is split into seven phases, and I will paste each phase prompt separately. This message sets the rules that apply to all of them.

## 1. First task (this message only)

Use Planning mode. Do not write or change any code yet.

1. Read `README.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/HARDWARE_INTEGRATION.md`, and `docs/UI_AUDIT.md`. If `docs/screens/` exists, open the screenshots too.
2. Map the codebase. Find and list, with file paths:
   - the PHI engine (`lib/core/phi.dart`) and its input/result models
   - the Monitor stepper screen, each step widget, the draft autosave code, and the completeness guard ("N required fields left")
   - the Results screen and its widgets: gauge, parameter cards, calculation expander, "What to do next", AI insights card, trend chart
   - the Home screen and its widgets: HomeHeader, HealthSummaryCard, StatTile grid, Four Parameters card, ActivityTimeline, CommunityHighlight, QuickActions
   - the Locations list, Location detail, and Register Location screens
   - the Profile screen and the Gemini settings card
   - `AiService`, `ApiService` / the Firestore service, the SQLite helper (including its DB version), the router, the Provider setup in `main.dart`, `AppColors`, `AppRadius`, and the theme
   - `firestore.rules` and the validation functions
   - every test file, with the current test count
3. Produce an **Implementation Plan artifact** that maps each phase in `docs/IMPLEMENTATION_PLAN.md` to the real files you found. Flag anything in the plan that doesn't match the code, such as a widget with a different name or a model with a different structure.
4. Run `flutter analyze` and `flutter test` and report the baseline numbers. If the baseline is not green, stop and tell me. Don't start fixing things.

Then wait for the Phase 1 prompt.

## 2. Ground rules for every phase

1. **Additive by default.** Add new files for new features. Touch an existing file only when a phase prompt says to, or when wiring a new feature in is impossible otherwise. Keep that edit minimal.
2. **No collateral changes.** Don't rename, move, reformat, or "clean up" code outside the phase scope. Don't upgrade packages that aren't listed. Don't change routes, tab order, or the `StatefulShellRoute` structure.
3. **Existing features keep working.** All 15 screens, the 5-step stepper, autosave drafts, guest/demo mode, Google sign-in, Gemini fallback cascade, offline sync, the community feed, and concern reporting.
4. **PHI is sacred.** The weights (Activity 30 %, Habitat 30 %, Environment 20 %, Risk 20 %), the tier boundaries, and the existing sub-score rules don't change. An assessment without a soil reading must score exactly what it scores today.
5. **Hardware is optional.** A user without the ESP32 completes assessments exactly as today. Soil moisture is never a required field.
6. **Tests.** The 93 existing tests must pass without being edited. If one fails, your change is wrong. Phase 5 is the only exception: a test may assert the exact buggy behaviour that a listed fix removes (a duplicate arrow, a stale label). In that case, name the test and explain why before changing it.
7. **Every phase ends with:** `flutter analyze` (no new warnings) and `flutter test` (all green), then a **Walkthrough artifact** containing: files added, files touched with a one-line reason each, test count before and after, and screenshots of every changed screen at 360 dp and 412 dp widths.
8. **No DHT22.** It isn't connected. Temperature, humidity and CO₂ stay manual. Don't add DHT code or a DHT option anywhere.
9. **Never store secrets in Firestore.** The device pairing token stays on the phone (SQLite) and on the ESP32 (NVS).
10. If a phase prompt conflicts with something you find in the code, stop and ask. Don't guess.

## 3. Design rules (all UI work)

The new screens must look as if they shipped with the originals.

- **Colours.** Use only the `AppColors` tokens: forest `#1E4D2B`, forestDark `#173D22`, leaf `#3E8E3A`, leafLight `#7CB342`, sage `#E3EDD6`, sageBorder `#CFDDBF`, cream `#FAF6EC`, card `#FFFDF7`, ink `#1F2A1F`, muted `#5C6B5C`, honey `#F4C542`, alert `#C62828`, alertSoft `#FDECEA`, plus the five PHI tier colours. No purple, no blue, no gradients except the ones that already exist.
- **Type.** Lora 600/700 for titles and section headings. Inter for everything else. Every number uses `FontFeature.tabularFigures()`.
- **Shape.** Cards have a 20 dp radius with a 1 px sageBorder outline on a card surface. Chips use 12 dp, buttons 28 dp (stadium). Card padding is 16 dp. Gaps between sections are 24 dp, and 12 dp inside a card.
- **Motion.** Use `PressableScale` on tappable cards and buttons, `HapticFeedback.selectionClick()` on toggles, and existing animation durations only.
- **Icons.** Material Rounded/Outlined only, tinted forest or ink on a sage circle. Sensor icons: `Icons.sensors_rounded` (node), `Icons.water_drop_outlined` (soil), `Icons.wifi_rounded` / `Icons.wifi_off_rounded` (network).
- **Copy.** Plain, short, and specific, the way a field ecologist talks. No marketing phrases ("unlock", "supercharge", "seamless"), no emoji in UI text, no exclamation marks except the existing greeting. Sentence case for labels; uppercase only for tier badges.
- **States.** Every new data widget has loading, empty, error, and offline states, designed rather than left blank.
- **Layout.** Nothing overflows or truncates mid-word at 360 dp width or at 1.3x text scale. Use `FittedBox(fit: BoxFit.scaleDown)` or two-line wrapping, not ellipsis, for labels that matter.
- **Accessibility.** Tap targets are at least 48 dp, and every icon-only control has a `Semantics` label. Status is never shown by colour alone: always add a word.

## 4. Glossary used in the phase prompts

- **Node:** the ESP32 sensor device.
- **Reading:** one JSON payload from `GET /api/reading`.
- **Capture:** the moment a reading is attached to an assessment draft.
- **Soil status codes:** `DRY`, `LOW`, `OPTIMAL`, `MOIST`, `WET`. These are the same codes in firmware, app, and Firestore.
- **Source:** `esp32` or `manual`.
