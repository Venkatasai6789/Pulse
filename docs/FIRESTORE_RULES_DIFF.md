# Firestore Security Rules Diff (Phase 6)

## Overview
This document records the additions and security hardening made to [firestore.rules](file:///c:/projects/pulse/firestore.rules) during Phase 6 of the P.U.L.S.E. hardware sensor integration.

## 1. Locations Collection
### `isValidLocation(data)`
- **Allowed Keys Added:**
  - `sensorNodeId`: Optional string identifying the paired hardware node ($\le 128$ characters).
  - `lastAssessedAt`: Optional timestamp recording the last assessment time.
- **Affected Keys on Update:**
  - Added `'lastAssessedAt'` to the allowed non-owner delta key list:
    `request.resource.data.diff(resource.data).affectedKeys().hasOnly(['latestPhi', 'latestTier', 'latestAssessmentAt', 'lastAssessedAt'])`

## 2. Assessments Collection
### `isValidSoil(soil)` (New Validator)
- **Allowed Keys:**
  - `percent`: Number between 0 and 100.
  - `raw`: Integer between 0 and 4095 (12-bit ADC).
  - `status`: String ($\le 50$ characters).
  - `source`: String ($\le 50$ characters, e.g. `'esp32'`, `'manual'`).
  - `deviceId`: String ($\le 128$ characters).
  - `firmware`: String ($\le 50$ characters).
  - `stable`: Boolean.
  - `capturedAt`: Timestamp or ISO 8601 string.
  - `capturedLat` / `capturedLng`: Floating-point GPS coordinates.
  - Hardware telemetry telemetry extensions: `moistureRaw`, `moisturePct`, `condition`, `soilTempC`, `ambientTempC`, `humidityPct`, `heatIndexC`, `dewPointC`, `rssiDbm`.
### `isValidAssessment(data)`
- **Allowed Keys Added:**
  - `soil`: Optional map validated by `isValidSoil(soil)`.

## 3. Devices Collection (New Collection)
### `match /devices/{deviceId}`
- **Security Boundaries:**
  - Owner-only access for `read`, `create`, `update`, and `delete`.
  - Enforces `request.auth.uid == resource.data.ownerUid`.
- **Validation `isValidDevice(data)`:**
  - Allowed keys: `['deviceId', 'ownerUid', 'name', 'hardwareModel', 'firmwareVersion', 'locationId', 'lastSeenAt', 'updatedAt', 'createdAt']`.
  - **Explicitly Forbidden Keys:** `token`, `secret`, `pairingToken`, `wifiPassword`. Pairing secrets and network credentials are strictly prohibited from being persisted in Firestore.

---
*Generated: 2026-11-26 | P.U.L.S.E. Hardware Integration Phase 6*
