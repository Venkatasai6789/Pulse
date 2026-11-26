# Phase 7 — Verification, End-to-End Hardware Test, Release Build

Scope: tests, docs, and the build. No feature work. If you find a bug, fix it in the smallest possible change and list it.

## 7.1 Automated checks

1. `flutter analyze`: zero new issues compared with the baseline from the master prompt.
2. `flutter test`: report "93 baseline + N new = total, all passing", broken down by file.
3. `pio run` in `firmware/pulse_node`: builds clean.
4. Golden tests are regenerated only for the widgets changed in Phases 4–5, and each regeneration is listed.

## 7.2 Regression sweep: existing features (screen by screen)

Run on a real Android phone in **guest mode** and again **signed in with Google**, with **no node paired**. Tick each item:
- Splash → Sign-in → Profile setup (new account) → Home
- Home: the summary gauge, stats, Your Locations, Four Parameters, Recent Activity, Community highlight and Quick Actions all render. The header shows no sensor icon. The "Add a field sensor" card shows and can be dismissed.
- A full assessment with no soil gives the same PHI as before. Use the reference case Activity 3 visits / 5 min, Habitat High/Medium/Medium/Present, T 25, H 50, CO₂ 80, Risk Low → **66 ENHANCE**.
- Draft: start an assessment, leave mid-way, return, and the draft restores.
- Results: gauge, cards, expander, insights (with a Gemini key), trend chart, Record action, View location.
- Locations list = Home = picker (F01). Register a location with GPS and a photo.
- Community: post, like, report a concern.
- Reports page. Profile: the Gemini key flow, sign out.
- Offline: airplane mode → complete an assessment → the SyncIndicator shows Offline → reconnect → it syncs.

## 7.3 End-to-end hardware script

Give me this as a checklist I can follow with the board.
1. Flash the firmware. The LCD shows the Boot page, then `Wi-Fi setup mode`.
2. Join `PULSE-Node-XXXX` from the phone and set up home Wi-Fi in the portal. The LCD goes `Connecting Wi-Fi` → the Soil page.
3. App → Profile → Pair a node → Same Wi-Fi → the node appears → enter the PIN from the LCD → Paired → link to "Community Garden". The LCD Location page now shows "Community Garden".
4. Calibrate: probe in air → Capture dry; probe in a glass of water → Capture wet → Save.
5. Probe in dry soil (or air): within 6 s the Home card shows DRY in the orange fill, and the LCD shows the `! Soil too dry` alert in its rotation.
6. Probe in damp soil: the value moves to 40–60 % and shows **Optimal** in the app, `IDEAL` on the LCD.
7. Start an assessment for Community Garden. The location card shows `● Sensor live · xx %`. Step 3 shows the live panel → Use sensor reading. The Environmental score updates, and the Review live preview reflects soil.
8. Calculate PHI. Results shows soil in the Environmental card and the expander. Within 5 s the LCD's Last PHI page shows the same PHI and tier, and the Location page shows the change from the previous PHI.
9. Unplug A0: the app shows Probe fault within 20 s, and the LCD shows `! Sensor fault`.
10. Power off the node: the app shows Delayed at 15 s and then Offline. An assessment completes with manual soil entry.
11. Direct mode: turn off the router. Join the node's SoftAP from the phone, use Pair → Direct to node → reading works. Submit → the PHI pushes to the LCD.
12. Hold BOOT 5 s → `Release to reset` → the node resets to setup mode. The app shows Pair again.
13. Compare the PHI on the phone, the PHI on the LCD, and the PHI in the Firestore document. All three must match.

## 7.4 Performance and battery

- Polling runs only while a sensor widget is visible. Show a log proving no requests happen for 60 s on the Community tab.
- No dropped frames (>16 ms) on Home with the live card updating. Attach a DevTools frame chart screenshot.
- Every network call has a timeout. Nothing blocks the UI thread.

## 7.5 Documentation

- Update the root `README.md`, keeping its style. Add a "Hardware Sensor Node" section to the table of contents and body, linking to `docs/HARDWARE_INTEGRATION.md`. In the PHI Scoring Engine section, add the soil rule and the band table. Update the test count badge. Don't rewrite the other sections.
- Mark `docs/IMPLEMENTATION_PLAN.md` acceptance criteria as done, and add a short "Deviations" list.

## 7.6 Release

- `flutter build apk --release`. Install it on the device and repeat steps 3, 7 and 8 of §7.3 on the release build. Cleartext and mDNS behaviour can differ from debug.
- Final Walkthrough: the APK size compared with the previous build, the full file list (added and touched), the test totals, the rules deployment status (pending or deployed by the backend owner), and known limitations.
