# Phase 4 — UI: Device Status and Live Readings

Scope: new widgets in `lib/widgets/sensor/`, with insertion points in Home, Monitor (Step 3, the location card, Review), Results, Locations, Location detail, and Profile. Follow the master design rules strictly. The new pieces must look like part of the original app.

## 4.0 Where the device status lives, and why

The user has to see the node's state in exactly the places where they act on it. Nowhere else.

| Place | What appears | Why there |
|---|---|---|
| **Home header** (left of the notification bell) | `SensorStatusButton`: sensors icon with a status dot. Hidden if no node is paired. | Always visible on the landing screen. It sits next to the other system indicators (bell, avatar), not inside content. |
| **Home**, directly under the PHI summary card | `FieldSensorCard`: live soil value, status, last PHI shown on the node | The second thing a returning user wants after their score: "what is the soil doing right now". |
| **Monitor → Step 3**, top of the existing "Sensor & Ambient Readings" section | `SoilSensorPanel`: live reading + capture | The section already exists and is titled "Sensor & Ambient Readings". Soil belongs with temperature, humidity and CO₂. |
| **Monitor location card** | a one-line status under the address: `● Sensor live · 46 %` | Confirms the right node is linked to the chosen location before the user starts. |
| **Review (Step 5)** | soil row in the Environmental summary + source | So the user can verify what will be submitted. |
| **Results** | soil in the Environmental card, the calculation expander, Why this score, What to do next | It explains the score. |
| **Locations list + Location detail** | sensor glyph on linked sites; a node row in detail | Linking a node to a site. |
| **Profile** | `FieldSensorSettingsCard`, placed **above** the Gemini card | Device management lives with settings. |

Don't add a floating overlay, a persistent banner, or anything inside the bottom navigation bar.

## 4.1 Shared widgets (new, `lib/widgets/sensor/`)

**`SensorStatusDot`**: an 8 dp circle plus an optional word, so status is never colour-only.

| State | Colour | Word |
|---|---|---|
| online | `AppColors.leaf` | Live |
| stale | `AppColors.honey` | Delayed |
| searching | `AppColors.honey` with a 1.2 s pulse | Connecting |
| offline | `AppColors.muted` | Offline |
| fault | `AppColors.alert` | Probe fault |
| unauthorized | `AppColors.alert` | Pair again |

**`SoilMoistureBar`**: a horizontal track 8 dp tall with a 4 dp radius.
- Track `sage`. The optimal band (40–60 %) is shaded `leafLight` at 35 % opacity.
- The fill is the status colour: DRY/WET use the RESTORE tier orange `#EF6C00`, LOW/MOIST use honey, OPTIMAL uses leaf.
- A 2 dp ink marker sits at the value, with tick labels `0`, `40`, `60`, `100` in Inter 11 sp muted underneath.
- The value animates over 400 ms `easeOutCubic` between readings.

**`SoilValueBlock`**: the big number `46` in Inter 34 sp w600 tabular, then `%` in 16 sp muted, baseline-aligned. To the right sits the status word "Optimal" (Inter 15 sp w600 ink), and the existing band chip ("Suitable" / "Moderate" / "Stressful") under it, **reusing the chip widget from the T/H/CO₂ fields**.

**`SensorDetailSheet`**: a modal bottom sheet used from the Home button and card.
- Node name + `SensorStatusDot`
- `SoilValueBlock` + `SoilMoistureBar`
- A key/value list: Raw ADC `2310`, Signal `−58 dBm`, Network `Home Wi-Fi · 192.168.1.42` (or `Direct`), Firmware `1.0.0`, Linked location, Last update `3 s ago`, Shown on display `PHI 66 · ENHANCE`
- Actions: `Start assessment here` (primary, pushes `/monitor?locationId=<linked>`), `Identify node` (flashes the backlight), `Sensor settings` (goes to Profile)

## 4.2 Home

**a) Header button.** Insert `SensorStatusButton` immediately left of the bell. It's a 40 dp circular hit area with `Icons.sensors_rounded` at 22 dp in ink and a `SensorStatusDot` (no word) at the bottom-right corner with a 2 dp cream ring. Semantics: "Sensor node, live, soil 46 percent". Tap opens `SensorDetailSheet`. It's hidden when `notPaired`, so the header stays as it is today for users without hardware.

**b) `FieldSensorCard`.** Insert it between the PHI summary card and the stat grid. It uses the standard card (20 dp radius, sageBorder, card surface, 16 dp padding).

Paired layout:
```
┌──────────────────────────────────────────────┐
│ (◉) Field sensor                ● Live · 3 s │  title Lora 18 w600; status right
│     PULSE-Node-A1B2 · Community Garden       │  Inter 13 muted
│                                              │
│ 46 %                      Optimal            │  SoilValueBlock
│                           [ Suitable ]       │
│ ▕██████████▓▓▓▓░░░░░░░░░░░░░░░░▏             │  SoilMoistureBar
│  0          40     60              100       │
│ ──────────────────────────────────────────── │  1 px sageBorder divider
│ On display: PHI 66 · ENHANCE · 2 h ago       │  Inter 13; tier word in the tier colour
│                          Assess this site →  │  text button, forest
└──────────────────────────────────────────────┘
```
- Stale / offline: the value turns muted, and a line reads "Last reading 4 min ago" with a `Retry` text button. The card never collapses or jumps in height between states.
- Fault: replace the value block with an `alertSoft` panel: "Probe not detected. Check the A0 wire to GPIO 34."
- **Not paired:** a slim card 72 dp tall with the sensors icon in a sage circle, the text "Add a field sensor for live soil moisture" and a `Set up` text button → `/sensor/pair`. Add a dismiss (×). Store the dismissal in SharedPreferences. After dismissal the card disappears, and Profile still offers pairing.

**c)** Home's existing "The Four Parameters" card stays as it is. If any of the latest assessments carry soil, add the muted caption `Includes soil moisture` under the Environmental row. That's the only change to that card.

**d)** Home pull-to-refresh also triggers one reading fetch if a node is paired.

## 4.3 Monitor

**a) Location card (top of the stepper).** If the selected location has a linked node, or there's a single active node, add one line under the address: `● Sensor live · 46 %` (Inter 12 sp, using `SensorStatusDot` with its word). If the node is offline, show `● Sensor offline`. If no node, show nothing.

**b) Step 3: `SoilSensorPanel`** goes at the top of the existing "Sensor & Ambient Readings" section, above Temperature. Its style matches the Temperature/Humidity/CO₂ field cards exactly: the same outlined card, a title row with an icon, the field name, a `*`-less label, and the range text on the right.

Title row: `Icons.water_drop_outlined` + **Soil moisture (%)**, and at the right in muted text `Optional · 0 to 100 %`.

States:
- **Online, not captured:** `SoilValueBlock` + `SoilMoistureBar`, then a meta line `PULSE-Node-A1B2 · Raw 2310 · updated 2 s ago`. If `stable=false`, add a honey hint: "Reading is still settling. Wait a few seconds." The primary outlined button is `Use sensor reading`. It's enabled when fresh and `sensorOk`; if the reading isn't stable it becomes enabled 30 s after it was first shown, so the user can't get stuck.
- **Captured:** a sage panel with a check, "Captured 10:42 · 46 % · Optimal", and two text buttons, `Refresh` (recapture) and `Remove`. The live value keeps updating below in muted text, "Now 47 %", so drift is visible without replacing the captured value.
- **Auto-capture:** if the user leaves Step 3 (Next or a tab tap) with no capture, and a fresh, sensorOk reading exists, capture it automatically and show a SnackBar: "Soil moisture 46 % captured from sensor".
- **Not paired / offline:** one line, "No live sensor. Enter soil moisture manually or pair a node.", then a numeric field with the same style as Humidity (suffix `%`, range 0–100, live status chip underneath once valid), and a `Pair a node` text button. Manual values are stored with `source: manual`.
- **Fault:** an `alertSoft` panel with the fault text. Manual entry is still available.

The Environmental Score summary row at the bottom of Step 3 ("Environmental Score 100 / 100") must use the new calculation, so it updates live when soil is captured or entered. Use `formatSubScore`.

**c) Draft.** The captured `SoilReading` is stored in the existing autosave draft. Old drafts without the field restore fine. "Save draft" persists it.

**d) Completeness guard:** unchanged. Soil is never counted as a required field.

**e) Stale capture check at submit:** if the captured reading is older than 30 minutes, show a dialog when the user taps Calculate PHI: title "Soil reading is 42 min old", body "Take a fresh reading from the sensor before calculating?", actions `Keep` and `Refresh`. Refresh is only shown when the node is online. Never block submission.

**f) Review (Step 5):**
- Environmental Conditions summary card: add the row `Soil moisture`, value `46 % · Optimal`, and under it a muted caption `Sensor PULSE-Node-A1B2 · 10:42` or `Entered manually`. Insert it between CO₂ and "Environmental sub-score".
- The Live PHI Preview gauge and mini score strip pick up soil through `phi.dart`. No layout change.

**g) After a successful submit:** call `controller.pushPhi(result, locationName)` without awaiting it, after the Firestore batch succeeds and before or alongside navigation to Results. Don't show any UI for a failure. On success, the Results screen shows a small muted line under the tier text: `Shown on sensor display`.

## 4.4 Results

- **Environmental card detail line:** `25 °C · 50 % humidity · 80 ppm CO₂ · 46 % soil` (the soil part only when present). If the source is manual, append ` (manual)`.
- **"How PHI is calculated" expander:** when soil is present, add the env line `Environmental = (100 + 100 + 100 + 100) / 4 = 100`, and keep the existing weighted line.
- **"Why this score?":** include the soil phrases from Phase 2 §2.4 through the existing sentence builder.
- **"What to do next?":** append at most 2 soil actions using the existing checklist row widget:
  - DRY / LOW: "Mulch beds 5–7 cm to hold moisture", "Water early morning during dry spells"
  - WET / MOIST: "Improve drainage around the bed", "Leave some bare, well-drained soil for ground-nesting bees"
  - OPTIMAL: none
- **AI insights card:** covered in Phase 6.

## 4.5 Locations

- **Locations list card:** if a node is linked, add a small `Icons.sensors_rounded` (16 dp, forest) after the location name, with the semantics label "Sensor linked".
- **Location detail:** under the address/typology block, add a row card "Sensor node" with `PULSE-Node-A1B2 · ● Live · 46 %` and actions `Unlink` / `Link sensor node`. Linking opens a picker of paired nodes, then calls `linkLocation` (which also `POST`s `/api/config` so the LCD shows the location name).

## 4.6 Profile: `FieldSensorSettingsCard`

Place it directly **above** the Gemini AI Settings card, with the same card anatomy: icon tile, title Lora "Field sensor", subtitle, and a status pill on the right.
- Not paired: subtitle "No node paired", primary stadium button `Pair a node`.
- Paired: subtitle `PULSE-Node-A1B2 · fw 1.0.0`, status pill (`Online` leaf / `Offline` muted), then key/value rows (Network, Signal, Linked location, Calibration `dry 4010 · wet 1620`), then actions in a wrap: `Test connection`, `Calibrate`, `Rename`, `Identify`, and the destructive text button `Unpair` in alert colour.
- **Calibrate sheet:** step 1 "Hold the probe in dry air", showing the live raw value updating, then `Capture dry`. Step 2 "Put the probe in water up to the line", live raw, `Capture wet`. A result row shows `Dry 4010 · Wet 1620`, with `Save` and `Reset to defaults`. Validation: if dry − wet < 500, show "Values too close. Check the probe is fully dry, then fully wet".

## 4.7 Widget tests (`test/widgets/sensor/`)

- `SoilSensorPanel`: all states at 360 dp and 1.3x text scale with no overflow; capture; auto-capture on leaving the step; manual entry chip; fault panel.
- `FieldSensorCard`: paired, stale, fault, not paired, and dismissed states.
- `SensorStatusButton` is hidden when not paired.
- Review shows the soil row only when soil is present.
- Results shows the env breakdown and soil actions only when soil is present.
- A golden test for `FieldSensorCard` and `SoilSensorPanel` (online state) to lock the visual design.

## 4.8 Done when

All tests are green, and the Walkthrough has screenshots at 360 dp and 412 dp of: Home (paired and not paired), the sensor sheet, Step 3 (online, captured, manual, fault), Review, Results with soil, Location detail, Profile card, and the calibration sheet. Also include a short screen recording of a live reading changing as the probe goes from air to water.
