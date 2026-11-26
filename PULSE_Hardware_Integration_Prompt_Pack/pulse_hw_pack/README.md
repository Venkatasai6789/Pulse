# P.U.L.S.E. Hardware Integration: Antigravity Prompt Pack

This pack integrates the ESP32 soil-moisture node (with the I2C LCD) into the existing P.U.L.S.E. Flutter app, and fixes the UI issues found in the screenshot review. It replaces the single prompt I gave earlier.

## What's in the pack

| File | Where it goes | What it does |
|---|---|---|
| `00_MASTER_CONTEXT_PROMPT.md` | Paste into Antigravity first | Project context, ground rules, and design rules for every phase |
| `PHASE_1_FIRMWARE.md` | Paste as the Phase 1 prompt | ESP32 firmware: sensor, Wi-Fi, REST API, LCD layout |
| `PHASE_2_PHI_ENGINE.md` | Phase 2 prompt | Soil scoring and the PHI logic change (backward compatible) |
| `PHASE_3_DEVICE_CONNECTIVITY.md` | Phase 3 prompt | App-side device layer: discovery, pairing, polling, storage |
| `PHASE_4_UI_SENSOR_INTEGRATION.md` | Phase 4 prompt | Device status and live readings in Home, Monitor, Review, Results, Locations, Profile |
| `PHASE_5_UI_AUDIT_FIXES.md` | Phase 5 prompt | Fixes for the existing screens (from the screenshot audit) |
| `PHASE_6_AI_AND_FIRESTORE.md` | Phase 6 prompt | Gemini soil context, Firestore fields, and the security rules |
| `PHASE_7_QA_RELEASE.md` | Phase 7 prompt | Tests, end-to-end hardware test script, release build |
| `docs/IMPLEMENTATION_PLAN.md` | Commit to the repo at `docs/` | Plan of record: scope, architecture, files, acceptance criteria |
| `docs/HARDWARE_INTEGRATION.md` | Commit to the repo at `docs/` | README for the sensor node: wiring, flashing, calibration, API, LCD screens, troubleshooting |
| `docs/UI_AUDIT.md` | Commit to the repo at `docs/` | Screen-by-screen findings behind Phase 5 |

## How to run it in Antigravity

1. Copy the `docs/` folder into the repo root (so you get `docs/IMPLEMENTATION_PLAN.md` and the others). Optionally put the 31 screenshots in `docs/screens/` so the agent can open them.
2. Open a new agent conversation in **Planning mode**. Paste `00_MASTER_CONTEXT_PROMPT.md`. The agent reads the repo and the docs and returns an Implementation Plan artifact. It writes no code yet.
3. Review the plan, then paste `PHASE_1_FIRMWARE.md`. When it's done, flash the board and test with the curl commands in `docs/HARDWARE_INTEGRATION.md` before going further.
4. Paste Phases 2 → 7 one at a time. After each phase, check:
   - `flutter analyze` is clean
   - `flutter test` is green: 93 existing tests plus the new ones
   - the phase walkthrough lists every touched file
5. Don't paste the next phase until the current one is green. If the agent drifts (renames things, refactors untouched code), reply with: "Revert changes outside the phase scope listed in 00_MASTER_CONTEXT_PROMPT.md."

## Phase order and why

Firmware comes first so you have a real device to test against. The PHI engine comes second because it is pure Dart and can be proven with tests before any UI exists. The device layer is third, then the UI that uses it. UI fixes are a separate phase, so a regression can be traced to either "new feature" or "fix". AI and Firestore come late because the rules change needs your backend teammate to deploy it.

## Decisions baked into this pack (change them before starting if you disagree)

- Soil moisture is a fourth input to the **Environmental** sub-score. The PHI weights stay 30/30/20/20. Without a soil reading, PHI is identical to today.
- Soil bands: Optimal 40–60 %, Low 25–39 %, Moist 61–75 %, Dry < 25 %, Waterlogged > 75 %.
- The LCD is 16x2. A 20x4 layout is included as an option.
- No DHT22. Temperature, humidity and CO₂ remain manual inputs.
- The ESP32 has no GPS. A reading belongs to the assessment's selected location, and the phone's GPS is stored with it as an audit trail.
