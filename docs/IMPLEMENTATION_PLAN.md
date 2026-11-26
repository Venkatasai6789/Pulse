# P.U.L.S.E. — Hardware Integration Implementation Plan

| | |
|---|---|
| Feature | ESP32 soil-moisture sensor node with I2C LCD, integrated into the PHI assessment |
| Also in scope | Fixes for the existing UI, from the screenshot audit (`docs/UI_AUDIT.md`) |
| Out of scope | DHT22 (not connected), cloud push from the ESP32, OTA firmware updates, iOS |
| Baseline | 15 screens, 5-step stepper, 93 passing tests |
| Status | Planned |

## 1. Goals

1. A user connects the ESP32 to Wi-Fi (or directly to the phone), pairs it once, and from then on the app reads live soil moisture without manual entry.
2. Soil moisture feeds the PHI through the Environmental sub-score. It also feeds the Gemini advice and the Results recommendations.
3. The LCD shows live soil moisture, the most recent PHI for the linked site, the trend, and device health, in a clean, aligned layout.
4. Nothing that works today breaks. A user without hardware sees the same app, minus the fixed defects.

## 2. Architecture

```
┌──────────────── ESP32 node ────────────────┐         ┌──────────────── Flutter app ──────────────────┐
│ Soil probe ─ADC(GPIO34)─▶ soil_sensor       │         │ SensorDiscovery (mDNS / SoftAP / manual IP)   │
│   32x sample · trimmed mean · EMA · %       │  HTTP   │ SensorNodeClient (token, timeouts)            │
│   status DRY/LOW/OPTIMAL/MOIST/WET          │◀──────▶│ SensorNodeController (ChangeNotifier)         │
│ api (WebServer :80, JSON, X-PULSE-Token)    │  JSON   │   poll 3 s while visible · capture · pushPhi  │
│ net (WiFiManager, AP+STA, mDNS, NTP)        │         │ SQLite sensor_nodes (token stays local)       │
│ lcd_ui (16x2, frame buffer, pages, alerts)  │         │ phi.dart + soil.dart  ──▶  PHI result         │
│ store (NVS: calibration, token, PHI history)│         │ AiService (+ soil context, soilAdvice)        │
└─────────────────────────────────────────────┘         │ Firestore: assessments.soil, devices/{id}     │
                                                         └───────────────────────────────────────────────┘
```

**Data flow for one assessment**
1. The Monitor Step 3 panel acquires the controller, which starts polling `GET /api/reading`.
2. The user taps *Use sensor reading* (or it auto-captures on leaving the step). A `SoilReading` is stored in the draft.
3. Review and the live preview recalculate through `phi.dart`.
4. Calculate PHI sends one atomic Firestore `WriteBatch`: the assessment with `soil`, `soilScore` and `formulaVersion`, plus the location's `latestPhi`, `latestTier` and `lastAssessedAt`.
5. Fire-and-forget `POST /api/display` updates the LCD's Last PHI, Trend and Location pages.

## 3. PHI rule (backward compatible)

```
Env (no soil)   = (T + H + CO₂) / 3            Env (soil) = (T + H + CO₂ + Soil) / 4
PHI = round(0.30·Activity + 0.30·Habitat + 0.20·Env + 0.20·Risk)       weights unchanged
```

| Soil % | Status | Points | Chip |
|---|---|---|---|
| < 25 | Dry | 20 | Stressful |
| 25–39 | Low | 60 | Moderate |
| 40–60 | Optimal | 100 | Suitable |
| 61–75 | Moist | 60 | Moderate |
| > 75 | Waterlogged | 20 | Stressful |

The maximum effect of soil on PHI is −4 points (Environmental from 100 to 80). The effect is honest but bounded. The model keeps the same four parameters, so historical comparisons hold. `formulaVersion` records which rule produced each score.

## 4. Phases

| # | Phase | Main output | Touches existing code? | Exit criteria |
|---|---|---|---|---|
| 0 | Context and baseline | Implementation Plan artifact, repo map, baseline test run | No | Plan approved, baseline green |
| 1 | Firmware | `firmware/pulse_node/` PlatformIO project | No | Builds; curl transcripts; LCD self-test output, all lines 16 chars |
| 2 | PHI engine | `soil.dart`, `soil_reading.dart`, `score_format.dart`, optional param in `phi.dart` | `phi.dart` (small) | Regression tests prove identical PHI without soil |
| 3 | Device layer | `lib/hardware/*`, pairing screen, SQLite migration, Android permissions | `main.dart`, DB helper, router, manifest | Real device pairs; migration keeps the Gemini key |
| 4 | Sensor UI | Home button + card, Step 3 panel, Review/Results/Locations/Profile additions | insertion points only | All states screenshotted; widget + golden tests |
| 5 | UI fixes | F01–F29 from the audit | targeted | P0 + P1 done, before/after screenshots |
| 6 | AI + Firestore | soil context, `soilAdvice`, model fields, rules diff | `AiService`, models, rules | Rules diff delivered; round-trip verified |
| 7 | QA + release | Regression sweep, hardware E2E, release APK, README update | docs | E2E checklist passed on the release build |

## 5. Files

**New**
```
firmware/pulse_node/**                     (Phase 1)
lib/core/soil.dart, soil_reading.dart, score_format.dart   (Phase 2)
lib/hardware/models/{sensor_node,node_reading,node_connection}.dart
lib/hardware/{sensor_node_client,sensor_discovery,sensor_node_repository,sensor_node_controller}.dart
lib/screens/sensor/sensor_pairing_screen.dart               (Phase 3)
lib/widgets/sensor/{sensor_status_dot,soil_moisture_bar,soil_value_block,sensor_status_button,
                    sensor_detail_sheet,field_sensor_card,soil_sensor_panel,
                    field_sensor_settings_card,calibration_sheet}.dart          (Phase 4)
test/soil_phi_test.dart, test/hardware/*, test/widgets/sensor/*, test/ai_service_soil_test.dart
docs/IMPLEMENTATION_PLAN.md, docs/HARDWARE_INTEGRATION.md, docs/UI_AUDIT.md
```
**Touched (expected, to be confirmed in Phase 0)**
```
lib/core/phi.dart                      optional soil param, env branch, formulaVersion
lib/main.dart                          register SensorNodeController
<sqlite helper>                        version +1, sensor_nodes table
<router>                               /sensor/pair route
android/app/src/main/AndroidManifest.xml   wifi/multicast/nearby permissions
<home screen + header>                 insert button + card
<monitor step 3, location card, review, draft model>   insert panel/rows; draft field
<results widgets>                      env detail, expander, recommendations, insights soil row
<locations list/detail, profile>       glyph, node row, settings card
<AiService>                            context + optional schema field
<assessment/location models, firestore service>    optional fields
firestore.rules                        allow-lists + isValidSoil + devices/
+ Phase 5 targeted fixes (see UI_AUDIT.md)
```

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Firestore rules reject the new fields, so submissions fail | Rules diff delivered in Phase 6; release blocked until it's deployed; legacy docs stay valid |
| mDNS blocked on some routers or campus Wi-Fi | Manual IP entry and the SoftAP direct mode |
| Android routes SoftAP traffic over mobile data | `wifi_iot.forceWifiUsage(true)` while in direct mode |
| Cleartext HTTP behaves differently in release builds | Release-APK testing in Phase 7; scoped network security config only if needed |
| Resistive probe drift or corrosion | Two-point calibration, fault detection, stability flag; docs suggest a capacitive probe as an upgrade |
| Reading flickers at band edges | 2-point hysteresis in firmware; the app shows `stable` and captures deliberately |
| Polling drains the battery | Reference-counted polling only while visible; stops in the background |
| SQLite migration loses the Gemini key | Migration test with the old schema plus a key row |
| Scope creep / unrelated refactors | Master ground rules; one Walkthrough per phase listing touched files |
| 5V LCD pull-ups on 3.3V I2C lines | Documented; level shifter recommended for long-term deployment |

## 7. Acceptance criteria

- [ ] Without a node: every existing flow works, and the reference assessment still scores **66 ENHANCE**.
- [ ] With a node: pairing in under 1 minute using the LCD PIN; live value on Home within 6 s.
- [ ] A soil capture changes the Environmental score and PHI according to §3; tests cover every band edge.
- [ ] The LCD shows the same PHI and tier as the app within 5 s of submit, and every LCD line is exactly 16 characters.
- [ ] Node offline or faulty: clear states in the app and on the LCD; manual entry is still possible.
- [ ] Locations list, Home and picker agree (F01); all P0/P1 audit items are fixed.
- [ ] `flutter analyze` is clean; 93 baseline tests unchanged and green, plus the new tests.
- [ ] Rules diff reviewed and deployed before release.

## 8. Deviations

(To be filled in during implementation.)
