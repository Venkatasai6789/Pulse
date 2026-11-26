# Phase 6 — Gemini Soil Context, Firestore Fields and Security Rules

Scope: `AiService` (prompt and schema additions only), the assessment/location models and serialisers, the Firestore service, `firestore.rules`, and the AI insights card's soil row.

## 6.1 Gemini (advisory only, score invariance kept)

Don't touch the model cascade, quota/exhaustion logic, the REST fallback, or the existing schema fields.

**Context.** When the assessment has soil, add this block to the context the model already receives:
```
Soil moisture: 46 % (status OPTIMAL, band Suitable), source esp32 sensor,
captured 14 Nov 2026 10:42. Optimal band for this app is 40–60 %.
```
When there's no soil, add nothing. Don't write "soil: unknown", because the model will speculate.

**Schema.** Add one optional string property: `soilAdvice`.

**Instruction** (append to the existing system or task prompt, in the same voice):
> If a soil moisture reading is provided, write `soilAdvice`: one or two plain sentences that connect the reading to what is visible in the photos (bare ground for ground-nesting bees, wilting or lush flowers, standing water, mulch) and give one practical action. If no reading is provided, return an empty string for `soilAdvice`. Never suggest a change to the PHI score.

**Habitat photo validation** (the `isHabitatPhoto` flow) doesn't change.

**Parsing:** a missing or null `soilAdvice` becomes `''`. Cached insights from before this change still render.

**UI:** in the AI insights card (already restyled by F10), when `soilAdvice` isn't empty, add a row before the tips: a forest `Icons.water_drop_outlined` icon, the label "Soil", then the text. No new card.

**Tests** (`test/ai_service_soil_test.dart`, without editing `ai_service_test.dart`):
- the context includes the soil block only when soil is present
- the schema contains `soilAdvice` as optional
- the parser tolerates its absence
- the PHI result object is identical before and after insights are generated with soil present (score invariance)

## 6.2 Firestore data model (all new fields optional)

`assessments/{assessmentId}`: inside the existing inputs map (match the current naming, for example if inputs live under `inputs.environment`, put `soil` there):
```json
"soil": {
  "percent": 46,
  "raw": 2310,
  "status": "OPTIMAL",
  "source": "esp32",
  "deviceId": "a1b2c3d4",
  "firmware": "1.0.0",
  "stable": true,
  "capturedAt": "<Timestamp>",
  "capturedLat": 13.0337,
  "capturedLng": 80.2533
}
```
Also add these to the result section:
- `"soilScore": 100` (or `null`)
- `"formulaVersion": "v1.1-soil"`. Write `"v1"` on new assessments without soil. Old documents have no field, and the reader treats that as `"v1"`.

`locations/{locationId}`: `"sensorNodeId": "a1b2c3d4"` (optional), plus the fields F01 made sure of (`latestPhi`, `latestTier`, `lastAssessedAt`) if they weren't already allowed.

New collection `devices/{deviceId}` (mirrors paired nodes for users who sign in on a second phone):
```json
{ "ownerUid": "...", "name": "PULSE-Node-A1B2", "firmware": "1.0.0",
  "linkedLocationId": "...", "lastSeenAt": "<Timestamp>", "createdAt": "<Timestamp>" }
```
**Never write the pairing token, IP address, or Wi-Fi SSID to Firestore.** In guest mode, skip all `devices/` writes.

The serialisers must round-trip, and must read legacy documents without the new fields. The submit `WriteBatch` stays a single atomic batch. Soil travels inside the assessment document.

## 6.3 `firestore.rules` (critical)

The existing `isValidAssessment` and `isValidLocation` reject keys that aren't on their allow-list. **Without this change, every submission with soil will be denied.**

1. Add `soil`, `soilScore` and `formulaVersion` to the assessment allow-list (at the correct nesting level). Add `sensorNodeId` (and `latestPhi`, `latestTier`, `lastAssessedAt` if they're missing) to the location allow-list.
2. Add `isValidSoil(s)`:
   - `s.keys().hasOnly([...the 10 keys...])`
   - `s.percent is number && s.percent >= 0 && s.percent <= 100`
   - `!('raw' in s) || (s.raw is int && s.raw >= 0 && s.raw <= 4095)`
   - `s.status in ['DRY','LOW','OPTIMAL','MOIST','WET']`
   - `s.source in ['esp32','manual']`
   - `s.capturedAt is timestamp`
   - optional strings at most 64 characters long
3. Add `formulaVersion in ['v1','v1.1-soil']`.
4. Add a `devices/{deviceId}` match: owner-only read/write, an `isValidDevice` function, and **the token key explicitly forbidden**.
5. Keep ownership checks and submission immutability exactly as they are.
6. Add rules tests with the Firebase emulator (`@firebase/rules-unit-testing`) if the repo already has an emulator setup. If it doesn't, write the test cases as a checklist in the Walkthrough:
   - legacy assessment allowed
   - assessment with valid soil allowed
   - percent 120 denied
   - unknown status denied
   - an extra key inside `soil` denied
   - a device doc with a `token` key denied
   - another user's device denied

**Deliver the rules diff as a separate artifact.** The backend is maintained by a teammate, who will review it and deploy it with `firebase deploy --only firestore:rules`. The app release must not ship before the rules are deployed.

## 6.4 Reports and Home compatibility

- Reports and the trend charts read assessments with and without soil with no visual difference, except the Environmental detail text.
- Home's "Includes soil moisture" caption (Phase 4 §4.2c) reads the `soil` field from the latest assessments.

## 6.5 Done when

All tests pass (including the new AI tests), the rules diff artifact is ready, and a manual check confirms a soil assessment is written and read back in the Firestore console with the expected shape (include a screenshot of the document).
