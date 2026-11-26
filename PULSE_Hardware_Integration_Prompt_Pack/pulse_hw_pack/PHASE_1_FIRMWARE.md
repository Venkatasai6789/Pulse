# Phase 1 — ESP32 Sensor Node Firmware

Scope: a new folder `firmware/pulse_node/` only. Do not touch any Flutter file in this phase.

## 1.1 Hardware (fixed, do not change)

| Soil sensor module | ESP32 |
|---|---|
| VCC | 3.3V |
| GND | GND |
| A0 | GPIO 34 |
| D0 | Not connected |

| I2C LCD (PCF8574 backpack) | ESP32 |
|---|---|
| VCC | 5V (VIN) |
| GND | GND |
| SDA | GPIO 21 |
| SCL | GPIO 22 |

- The sensor is the resistive LM393-type module (it has A0 + D0). **A higher raw value means drier soil.**
- GPIO 34 is ADC1 and input-only, so it is safe to read while Wi-Fi is on. Never use an ADC2 pin.
- The BOOT button (GPIO 0) is used as the user button.
- There is no DHT22. Don't include its library or code.

## 1.2 Project layout

PlatformIO, Arduino framework, `board = esp32dev`, `monitor_speed = 115200`.

```
firmware/pulse_node/
├── platformio.ini
├── include/
│   ├── config.h          # every tunable constant lives here
│   └── version.h         # FW_VERSION "1.0.0"
└── src/
    ├── main.cpp          # setup/loop, cooperative scheduler (millis-based, no delay() > 5 ms)
    ├── soil_sensor.h/.cpp
    ├── lcd_ui.h/.cpp     # frame buffer, pages, custom glyphs, alerts
    ├── net.h/.cpp        # WiFiManager, STA+AP, mDNS, reconnect, NTP
    ├── api.h/.cpp        # WebServer routes, JSON, auth
    ├── store.h/.cpp      # Preferences (NVS) wrapper: calibration, token, PHI history, config
    └── button.h/.cpp     # BOOT button: short press / 2 s / 5 s hold
```

`lib_deps`: `tzapu/WiFiManager`, `bblanchon/ArduinoJson@^7`, `marcoschwartz/LiquidCrystal_I2C@^1.1.4`. Built-ins: `WebServer`, `ESPmDNS`, `Preferences`, `time.h` (NTP).

`config.h` must include at least: `PIN_SOIL 34`, `PIN_SDA 21`, `PIN_SCL 22`, `PIN_BTN 0`, `LCD_COLS 16`, `LCD_ROWS 2`, `SAMPLE_INTERVAL_MS 2000`, `PAGE_MS 4000`, `DEFAULT_DRY_RAW 4095`, `DEFAULT_WET_RAW 1500`, `AP_PASSWORD "pulse1234"`, `PAIR_PIN_TTL_S 120`, `STALE_APP_SYNC_S 120`, `BACKLIGHT_TIMEOUT_MIN 0` (0 = always on).

## 1.3 Soil sampling (`soil_sensor`)

- At setup: `analogReadResolution(12)` and `analogSetPinAttenuation(PIN_SOIL, ADC_11db)`.
- Every `SAMPLE_INTERVAL_MS`: take 32 reads 1 ms apart, sort them, drop the 4 lowest and 4 highest, and average the rest to get `rawInstant`. Smooth with an EMA (α = 0.3) to get `raw`. Seed the EMA with the first reading.
- Percent: `pct = (dryRaw - raw) * 100.0 / (dryRaw - wetRaw)`, clamped to 0–100 and rounded to an integer. Guard against `dryRaw <= wetRaw` (report a calibration error).
- Keep a 30 s ring buffer of percent values (15 samples). Expose `min30s`, `max30s`, and `stable = (max30s - min30s) <= 3`.
- Status codes (**must match the app's `soil.dart` exactly**):

| Code | Range | LCD label |
|---|---|---|
| `DRY` | pct < 25 | `DRY` |
| `LOW` | 25 ≤ pct < 40 | `LOW` |
| `OPTIMAL` | 40 ≤ pct ≤ 60 | `IDEAL` |
| `MOIST` | 60 < pct ≤ 75 | `MOIST` |
| `WET` | pct > 75 | `WET` |

- Fault detection: if `rawInstant > 4090` or `< 50` for 10 consecutive samples, set `sensorOk = false` (probe unplugged or shorted). Clear it after 3 good samples.
- Use hysteresis on status changes: only switch status when the value is 2 points beyond the boundary. This stops the LCD and app from flickering between LOW and OPTIMAL at 40 %.

## 1.4 Networking (`net`)

- **Provisioning:** if there are no saved credentials, WiFiManager runs a non-blocking captive portal on SoftAP `PULSE-Node-XXXX` (the last 4 hex digits of the MAC, uppercase) with password `AP_PASSWORD`. Portal title "P.U.L.S.E. Sensor Node". The LCD shows the setup page (see §1.7).
- **Running mode:** `WIFI_AP_STA`. STA joins the saved network. The SoftAP stays up at `192.168.4.1` so a phone can connect directly in the field when there's no router.
- **mDNS:** host `pulse-node-xxxx` (lowercase), service `_pulse._tcp` port 80, TXT `id=<deviceId>`, `fw=<version>`, `name=<friendly name>`.
- **NTP** (`pool.ntp.org`, IST offset 19800 s configurable) once STA is up. If NTP isn't available, use the `X-PULSE-Time` header the app sends (epoch seconds) to set the clock.
- **Reconnect:** check every 10 s. Never block the loop. Raise the `WIFI_LOST` alert after 30 s disconnected.
- `deviceId` = the last 8 hex digits of the eFuse MAC, lowercase.

## 1.5 Pairing and auth

- `POST /api/pair/start` → generates a 6-digit PIN with `esp_random()`, shows the PAIR page for `PAIR_PIN_TTL_S`, and returns `{ "expiresInS": 120 }`.
- `POST /api/pair/confirm {"pin":"482913"}` → on a match, generates a 32-char hex token, saves it to NVS, returns `{ "token": "...", "deviceId": "...", "name": "..." }`, and leaves the PAIR page. After 5 wrong PINs, lock pairing for 60 s.
- Only one token is valid at a time. Pairing again replaces it.
- Every route except `/api/health` and `/api/pair/*` needs the header `X-PULSE-Token`. Reply `401 {"error":"unauthorized"}` without it.
- Every authenticated request updates `lastAppSyncMs` (shown on the System page). If the request carries `X-PULSE-Time`, it also sets the clock.

## 1.6 REST API (`api`)

All responses are JSON with `Content-Type: application/json`. Errors use the shape `{ "error": "code", "message": "..." }`.

| Method | Path | Body / Response |
|---|---|---|
| GET | `/api/health` | `{ ok, deviceId, fw, uptimeS, paired }` (no auth) |
| GET | `/api/info` | `{ deviceId, name, fw, mode, ip, apIp, rssi, ssid, lcdAddr, calibration:{dryRaw,wetRaw}, locationId, locationName }` |
| GET | `/api/reading` | see the example below |
| POST | `/api/calibrate` | `{ "point":"dry" }` or `{ "point":"wet" }` captures the current smoothed raw value; `{ "dryRaw":4010, "wetRaw":1620 }` sets both; `{ "reset":true }` restores defaults. Returns the new calibration. Rejects if dry − wet < 500. |
| POST | `/api/display` | `{ phi, tier, locationName, ts }`. Stores the latest PHI and pushes the previous one into a 5-entry NVS history. Returns `{ ok }`. |
| POST | `/api/config` | `{ name?, locationId?, locationName? }`, persisted to NVS |
| POST | `/api/identify` | flashes the LCD backlight 3 times so the user can tell which node is which |
| POST | `/api/pair/start`, `/api/pair/confirm` | see §1.5 |

Example `/api/reading` response:

```json
{
  "deviceId": "a1b2c3d4",
  "fw": "1.0.0",
  "seq": 1532,
  "uptimeS": 13320,
  "sampleAgeMs": 420,
  "soil": { "raw": 2310, "percent": 46, "status": "OPTIMAL", "sensorOk": true,
            "stable": true, "min30s": 45, "max30s": 47 },
  "net":  { "mode": "sta", "rssi": -58, "ip": "192.168.1.42" },
  "lastPhi": { "phi": 66, "tier": "ENHANCE", "locationName": "Community Garden",
               "ts": 1795600000, "prevPhi": 58 }
}
```

`seq` increments on every new sample so the app can detect a frozen node. `lastPhi` is `null` until the app has pushed one.

## 1.7 LCD UI (`lcd_ui`): exact layouts

**Rendering rules**
- Keep a frame buffer `char buf[LCD_ROWS][LCD_COLS+1]` plus a shadow copy of what's on the glass. Each tick, write only the characters that changed (`setCursor` per changed run). Never call `lcd.clear()` after boot. This removes flicker.
- Build every line with one helper, `fmtLine(left, right)`: left-aligned text, right-aligned text, space padding to exactly `LCD_COLS`. If the two collide, truncate the left text, never the right.
- I2C address: scan 0x20–0x3F at boot, prefer 0x27 then 0x3F, and fall back to 0x27. Print the address to serial.
- Custom glyphs (8 CGRAM slots): 0 water drop, 1 Wi-Fi arc, 2 up arrow, 3 down arrow, 4–7 bar partials (1–4 of 5 columns filled). Full cell = `0xFF`. Empty bar cell = `0xA5` (middle dot in the HD44780 A00 ROM, which makes a dotted track).

Legend for the diagrams: `·` = space, `◆` = custom glyph (named per line), `▮` = full block `0xFF`, `▌` = partial bar glyph, `∙` = empty bar cell `0xA5`. Every line between the bars is exactly 16 characters.

**Boot (1.5 s)**
```
|···P.U.L.S.E.···|
|Sensor·Node·v1.0|
```
**Connecting** (col 15 = spinner `| / - \`, SSID truncated to 14)
```
|Connecting·Wi-Fi|
|HomeNet_5G·····/|
```
**Setup / captive portal** (line 2 rotates every 2 s through three values)
```
|Wi-Fi·setup·mode|
|PULSE-Node-A1B2·|   |Pass:·pulse1234·|   |Open·192.168.4.1|
```
**Pairing** (countdown right-aligned, 4 cols)
```
|Pairing·PIN·118s|
|··4·8·2··9·1·3··|
```

**Normal rotation.** Each page shows for `PAGE_MS` = 4 s. Soil is the primary reading, so it alternates with the others:
`SOIL → LAST PHI → SOIL → LOCATION → SOIL → NETWORK → SOIL → SYSTEM → repeat`.
Before any PHI has been pushed, show the "no PHI" variant of LAST PHI and skip LOCATION.

Page SOIL (◆ = drop glyph; value right-aligned in cols 12–15; bar in cols 0–9 with 50 steps; status label right-aligned in cols 11–15)
```
|◆·Soil·moist·46%|
|▮▮▮▮▌∙∙∙∙∙·IDEAL|
```
At 12 % the same line reads `|▮∙∙∙∙∙∙∙∙∙···DRY|`: 10-cell bar, one space, then the label right-aligned in 5 columns.

Page LAST PHI (tier left; age right: `now`, `12m`, `2h`, `3d`, or `14Nov` when the clock is unknown)
```
|Last·PHI··66/100|
|ENHANCE·······2h|
```
No PHI yet:
```
|Last·PHI······--|
|Run·assessment··|
```
Page LOCATION / TREND (◆ = up or down arrow glyph; equal values show `=`)
```
|Community·Garden|
|Change··58◆66·+8|
```
No previous PHI: line 2 = `|First·reading···|`

Page NETWORK (◆ = Wi-Fi glyph). Line 1 variants: `Online` + RSSI, `Direct` + `AP` (phone on the SoftAP), `Offline`
```
|◆·Online··-58dBm|
|192.168.1.42····|
```
Page SYSTEM (`never` when the app has never synced; uptime is HH:MM up to 99 h, then `4d03h`)
```
|App·sync·····12s|
|Up·03:42··v1.0.0|
```

**Alerts.** An active alert is inserted before every SOIL page and held for 4 s. The backlight stays steady (no blinking).
```
DRY    |!·Soil·too·dry··|   |12%··Water·today|
WET    |!·Waterlogged···|   |88%·Check·drains|
FAULT  |!·Sensor·fault··|   |Check·A0->GPIO34|
WIFI   |!·Wi-Fi·lost····|   |Reconnecting...·|
CAL    |!·Calibrate·node|   |dry·<=·wet·value|
RESET  |Release·to·reset|   |Resetting·in·3s·|
```

Binding rule: **every line is exactly `LCD_COLS` characters, built with `fmtLine(left, right)`**. Add an `#ifdef LCD_SELFTEST` routine that prints every page and alert to serial wrapped in `|...|`, so widths can be checked at a glance.

**Button (BOOT / GPIO 0)**
- Short press: go to the next page now and reset the page timer.
- Hold 2 s: show the NETWORK page for 15 s (handy for reading the IP).
- Hold 5 s: line 1 shows `Release·to·reset` with a 3 s countdown on line 2. Releasing during the countdown cancels. Completing it clears Wi-Fi credentials and the pairing token, then reboots into setup.

**20x4 option.** If `LCD_ROWS == 4`, show SOIL (2 lines) and LAST PHI (2 lines) together on one screen, and rotate the bottom half through LOCATION, NETWORK and SYSTEM. Use the same `fmtLine` with 20 columns.

## 1.8 Loop timing

A cooperative scheduler on `millis()`:
- sample every 2 s
- LCD tick every 250 ms (spinner, countdowns, page switch)
- `server.handleClient()` every loop
- Wi-Fi check every 10 s
- button poll every 20 ms

The watchdog stays enabled. No `delay()` above 5 ms.

## 1.9 Serial log

Prefix every line with a tag: `[BOOT]`, `[WIFI]`, `[SOIL]`, `[API]`, `[LCD]`, `[PAIR]`. Log one `[SOIL]` line every 10 s: `raw=2310 pct=46 status=OPTIMAL stable=1 ok=1`.

## 1.10 Deliverables

- The PlatformIO project builds with `pio run` with zero warnings at the default level.
- Update `docs/HARDWARE_INTEGRATION.md` if anything differs from what's written there (API, pages, button behaviour).
- In the Walkthrough, include the serial output of the `LCD_SELFTEST` routine showing every page at 16 characters, plus `curl` transcripts of `/api/health`, `/api/pair/start`, `/api/pair/confirm`, and `/api/reading` with the token.

**Stop here.** I will flash the board and test it before sending Phase 2.
