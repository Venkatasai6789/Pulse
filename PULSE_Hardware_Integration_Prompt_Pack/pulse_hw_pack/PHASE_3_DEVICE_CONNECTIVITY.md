# Phase 3 — App Device Layer: Discovery, Pairing, Polling, Storage

Scope: new files under `lib/hardware/`, plus minimal wiring in `main.dart` (Provider), the SQLite helper (migration), the router (one new route), and Android config. No visible UI except the pairing screen.

## 3.1 Packages

Add only these. Check pub.dev for versions compatible with the project's Dart SDK, and pin them.
- `multicast_dns`: mDNS discovery of `_pulse._tcp`
- `wifi_iot`: **only** for `forceWifiUsage(true/false)` when the phone is joined to the node's SoftAP (Android otherwise sends requests over mobile data because that Wi-Fi has no internet)
- Reuse the existing `http`, `sqflite`, `provider`, and `geolocator`. Don't add Dio, Riverpod, or Bloc.

## 3.2 Files

```
lib/hardware/
├── models/
│   ├── sensor_node.dart          # SensorNode {deviceId, name, host, port, mode(sta|ap), token, fw,
│   │                             #   linkedLocationId, linkedLocationName, dryRaw, wetRaw, pairedAt, lastSeenAt}
│   ├── node_reading.dart         # parsed /api/reading (soil, net, lastPhi, seq, sampleAgeMs, uptimeS)
│   └── node_connection.dart      # enum NodeConnection {notPaired, searching, online, stale, offline, fault, unauthorized}
├── sensor_node_client.dart       # HTTP calls, headers, timeouts, error mapping
├── sensor_discovery.dart         # mDNS + manual IP + SoftAP probe
├── sensor_node_repository.dart   # SQLite CRUD for paired nodes
└── sensor_node_controller.dart   # ChangeNotifier: state machine, polling, capture, display push
lib/screens/sensor/
└── sensor_pairing_screen.dart    # route /sensor/pair
```

Reuse `SoilReading` and `SoilStatus` from Phase 2. Don't redefine them.

## 3.3 `SensorNodeClient`

- Base URL `http://<host>:<port>`. Headers on every call: `X-PULSE-Token` (when paired) and `X-PULSE-Time: <epoch seconds>`.
- Timeouts: 2.5 s for reads, 4 s for pairing and calibration.
- Methods: `health()`, `info()`, `reading()`, `pairStart()`, `pairConfirm(pin)`, `calibrate({point|dryRaw,wetRaw|reset})`, `pushDisplay({phi, tier, locationName, ts})`, `config({name, locationId, locationName})`, `identify()`.
- Error mapping to a sealed `NodeError`: `unreachable` (socket or timeout), `unauthorized` (401), `pairingLocked` (429), `badResponse` (parse failure), `calibrationInvalid` (400 from calibrate). The UI shows these messages:
  - unreachable → "Node not reachable on this network"
  - unauthorized → "Pairing expired. Pair the node again"
  - pairingLocked → "Too many wrong PINs. Try again in a minute"
  - badResponse → "Unexpected reply from the node. Check the firmware version"
- `pushDisplay` never throws to callers. It returns `bool` and logs failures with `debugPrint` tagged `[NODE]`.

## 3.4 `SensorDiscovery`

Three paths. The pairing screen offers all of them.
1. **Same Wi-Fi (default):** mDNS query for `_pulse._tcp.local` for 6 s, resolve SRV/A records, and return a `List<DiscoveredNode {name, host, port, deviceId, fw}>` from the TXT records. Hold an Android `MulticastLock` during the scan. Add a small platform channel in `MainActivity.kt` if `multicast_dns` doesn't acquire it, and release it in `finally`.
2. **Direct to node:** the user joins `PULSE-Node-XXXX` in Android settings. The app probes `http://192.168.4.1/api/health`. Before the probe call `WiFiForIoTPlugin.forceWifiUsage(true)`, and on leave or dispose call `forceWifiUsage(false)`. Mark the node `mode = ap`.
3. **Manual IP:** validate an IPv4 address or `.local` hostname, then probe `/api/health`.

## 3.5 `SensorNodeController` (ChangeNotifier, registered in `main.dart`)

State machine:
```
notPaired ──pair──▶ searching ──200──▶ online ──no seq change 15 s──▶ stale
    ▲                    │                 │                              │
    └──unpair────────────┤                 ├─3 failures─▶ offline ◀───────┘
                         │                 ├─sensorOk=false─▶ fault
                         └─401────────────▶ unauthorized
```
- **Polling:** `GET /api/reading` every 3 s, **only while a consumer is subscribed**. Expose `acquire()` / `release()` reference counting. Home card, Monitor Step 3, Profile card and the pairing screen each call `acquire` in `initState`/visibility and `release` in `dispose`. Stop all polling when the app goes to the background (`AppLifecycleListener`) and resume on foreground.
- **Backoff when offline:** 3 s → 6 s → 12 s → 30 s max. Reset on success.
- **Freshness:** a reading is *fresh* if `sampleAgeMs < 10 000` and `seq` advanced within the last 15 s.
- Public API:
  - `NodeConnection state`, `NodeReading? latest`, `SensorNode? node`, `DateTime? lastUpdated`
  - `Future<SoilReading?> capture()`: returns a `SoilReading` from the latest **fresh, sensorOk** reading, with `source: esp32`, `stable` from firmware, and phone GPS through the existing location service (best effort, 3 s timeout, null on denial; never prompt for permission from here). Returns null with a reason if not capturable.
  - `Future<void> pushPhi(AssessmentResult r, String locationName)`: fire-and-forget wrapper around `pushDisplay`
  - `pair(DiscoveredNode, pin)`, `unpair()`, `calibrate(...)`, `rename(name)`, `linkLocation(id, name)`, `unlinkLocation()`, `identify()`
- Multiple nodes: store many, but keep one **active** node. Per assessment, the active target is the node linked to the selected location if there is one, otherwise the single paired node. Expose `nodeForLocation(locationId)`.
- Guest/demo mode works the same. The node is local and needs no Firebase auth.
- **Do not modify `AuthState`.** Do not put node state into Firestore here (that's Phase 6).

## 3.6 SQLite migration

- Bump the existing DB version by exactly 1. In `onUpgrade`, `CREATE TABLE IF NOT EXISTS sensor_nodes (...)` with the columns from §3.2 (`device_id TEXT PRIMARY KEY`, `is_active INTEGER`).
- **The existing settings table and the stored Gemini API key must survive.** No drop or recreate.
- `onCreate` must also create the table for fresh installs.

## 3.7 Pairing screen `/sensor/pair` (functional UI; visual polish follows the master design rules)

Top-level `GoRoute` next to the existing top-level routes. **Don't touch the shell branches.** Push it with `context.push`.

Layout, top to bottom:
1. App bar "Pair a sensor node", back arrow, cream background, no scroll tint.
2. A segmented choice with two options: **Same Wi-Fi** and **Direct to node**, plus a text link "Enter IP address" under it.
3. **Same Wi-Fi:** a scanning row (small progress indicator + "Looking for nodes on this network…"), then a list of found nodes. Each row has the sensors icon, the name, `deviceId · fw 1.0.0`, and a chevron. Empty result: "No nodes found. Check the node shows 'Online' on its display, or use Direct to node." with a `Scan again` button.
4. **Direct to node:** three numbered steps: open Wi-Fi settings (button deep-links with `AppSettings` / `Intent` if available, otherwise plain text), join `PULSE-Node-XXXX` with password `pulse1234`, come back and tap `Check connection`.
5. **PIN step:** after tapping a node → `pairStart()` → six single-digit boxes with the auto-advance pattern, the hint "Enter the 6-digit PIN shown on the node's display", and a countdown "Expires in 1:58". `Pair` is a full-width stadium button.
6. **Success:** a check in a sage circle, "Node paired", the node name, a `Link to a location` dropdown (optional, lists the user's locations), and a `Done` button.

Permissions: request `NEARBY_WIFI_DEVICES` (Android 13+) only when the user taps scan, never at launch. Explain a denial inline.

## 3.8 Android config

- **Cleartext HTTP to the node.** The node speaks plain HTTP on the LAN. Resolve the mDNS name to an IPv4 address inside the app (`multicast_dns` returns the A record) and call the node by IP. Don't rely on Android resolving `.local` names. Flutter's `dart:io` HTTP client (used by `package:http`) doesn't apply Android's cleartext policy, but **verify it on a release APK** against both the STA IP and `192.168.4.1`. Only if release testing shows the calls are blocked, add `res/xml/network_security_config.xml` with a `domain-config` for `192.168.4.1`. For the STA IP (Android can't allow-list IP ranges), stop and ask me before enabling a broader cleartext `base-config`. All other app traffic (Firebase, Gemini) is HTTPS and must stay that way.
- Manifest permissions: `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and `NEARBY_WIFI_DEVICES` with `android:usesPermissionFlags="neverForLocation"`. Add nothing else.

## 3.9 Tests

- `test/hardware/sensor_node_client_test.dart`: uses `MockClient` from `package:http/testing.dart`. Covers reading parse; 401 → unauthorized; timeout → unreachable; malformed JSON → badResponse; `pushDisplay` failure returns false and doesn't throw; headers present.
- `test/hardware/sensor_node_controller_test.dart`: transitions notPaired → searching → online → stale → offline → online; `sensorOk=false` → fault; polling stops when the ref count hits 0 and when backgrounded; `capture()` refuses stale/fault and accepts fresh.
- `test/hardware/sensor_db_migration_test.dart`: uses `sqflite_common_ffi`. Create the DB at the old version with a Gemini key row, open it at the new version, and assert the key is unchanged and `sensor_nodes` exists.
- `test/hardware/discovery_test.dart`: manual IP validation, and the SoftAP probe through a mocked client.

## 3.10 Done when

The existing 93 tests and all new tests pass. On a real device the pairing screen finds the node, pairs with the LCD PIN, and the Walkthrough shows a screenshot of the success state plus a log of 10 consecutive readings.
