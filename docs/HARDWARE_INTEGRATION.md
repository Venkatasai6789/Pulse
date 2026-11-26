# P.U.L.S.E. Sensor Node — Hardware Integration Guide

The P.U.L.S.E. sensor node is an ESP32 with a soil moisture probe and a 16x2 I2C LCD. It measures soil moisture at a monitoring site and serves the readings to the P.U.L.S.E. app over Wi-Fi. It also displays the site's latest Pollinator Health Index. The app scores soil moisture as part of the Environmental parameter.

## 1. Bill of materials

| Part | Notes |
|---|---|
| ESP32 DevKit (ESP32-WROOM-32, 30 or 38 pin) | Any `esp32dev`-compatible board |
| Soil moisture module, resistive probe + LM393 board (A0/D0) | A capacitive v1.2+ probe also works; it uses the same A0 wiring and needs recalibration |
| 16x2 LCD with PCF8574 I2C backpack | Address 0x27 or 0x3F (auto-detected) |
| Jumper wires, USB cable (data-capable) | |
| Optional: I2C level shifter (BSS138) | Recommended for long-term deployments (see §2) |

## 2. Wiring

| Soil sensor module | ESP32 |
|---|---|
| VCC | 3.3V |
| GND | GND |
| A0 | GPIO 34 |
| D0 | Not connected |

| I2C LCD | ESP32 |
|---|---|
| VCC | 5V (VIN) |
| GND | GND |
| SDA | GPIO 21 |
| SCL | GPIO 22 |

Notes:
- GPIO 34 is an ADC1 input-only pin, so it reads correctly while Wi-Fi is on. Don't move the sensor to an ADC2 pin (GPIO 0, 2, 4, 12–15, 25–27); those don't work with Wi-Fi active.
- The LCD backpack pulls SDA/SCL up to 5V while the ESP32 runs at 3.3V. Most units work as wired, but for a permanent install, either fit a level shifter or remove the backpack's pull-up resistors and use 3.3V pull-ups.
- Resistive probes corrode when powered continuously in wet soil. For a long-running site, switch to a capacitive probe, or power the probe from a GPIO only during sampling (a firmware option for a future version).
- There is no temperature/humidity sensor on this node. Temperature, humidity and CO₂ are still entered manually in the app.

## 3. Flashing the firmware

Requirements: VS Code + PlatformIO, or the PlatformIO CLI.

```bash
cd firmware/pulse_node
pio run                         # build
pio run -t upload               # flash (hold BOOT if the upload doesn't start)
pio device monitor -b 115200    # serial log
```

The first boot log shows `[BOOT] fw 1.0.0`, the LCD I2C address, and `[WIFI] portal PULSE-Node-XXXX`.

## 4. First-time setup

1. Power the node. The LCD shows `Wi-Fi setup mode` and `PULSE-Node-XXXX`.
2. On the phone, join Wi-Fi `PULSE-Node-XXXX` (password `pulse1234`). A setup page opens; if it doesn't, browse to `192.168.4.1`.
3. Pick the site's Wi-Fi network and enter its password. The node reboots into station mode and shows the Soil page.
4. In the app: **Profile → Field sensor → Pair a node → Same Wi-Fi**. Select the node, then type the 6-digit PIN shown on the LCD.
5. Optional: link the node to a location (Location detail → Sensor node → Link). The LCD then shows that location's name and PHI.

**No router in the field?** Leave the phone joined to `PULSE-Node-XXXX` and pick **Direct to node** when pairing. The node always keeps this access point running alongside the station connection.

## 5. Calibration

Raw readings vary between probes and soils, so calibrate each probe once:
1. App → Profile → Field sensor → **Calibrate**.
2. Hold the probe in dry air → **Capture dry** (typically 3900–4095).
3. Put the probe in a glass of water up to the marked line → **Capture wet** (typically 1300–1800).
4. **Save.** The values are stored on the node and survive power loss.

If dry minus wet is under 500, the app rejects the calibration. Dry the probe completely and repeat.

## 6. How soil moisture affects the PHI

| Soil % | Status (app) | LCD | Points | Chip |
|---|---|---|---|---|
| < 25 | Dry | `DRY` | 20 | Stressful |
| 25–39 | Low | `LOW` | 60 | Moderate |
| 40–60 | Optimal | `IDEAL` | 100 | Suitable |
| 61–75 | Moist | `MOIST` | 60 | Moderate |
| > 75 | Waterlogged | `WET` | 20 | Stressful |

The Environmental sub-score becomes the average of four inputs (temperature, humidity, CO₂, soil) instead of three. The parameter weights don't change (30/30/20/20). Assessments without a soil reading score exactly as before. These are prototype bands for the calibrated sensor percentage, not laboratory volumetric water content.

## 7. The LCD

Pages rotate every 4 s. Soil appears on every other page because it's the live reading. Short-press BOOT to skip to the next page.

```
Soil            |◆ Soil moist 46%|     Last PHI      |Last PHI  66/100|
                |▮▮▮▮▌∙∙∙∙∙ IDEAL|                   |ENHANCE       2h|

Location/trend  |Community Garden|     Network       |◆ Online  -58dBm|
                |Change  58▲66 +8|                   |192.168.1.42    |

System          |App sync     12s|
                |Up 03:42  v1.0.0|
```

Alerts appear before the Soil page while they're active:

| Alert | Line 1 | Line 2 |
|---|---|---|
| Dry soil | `! Soil too dry` | `12%  Water today` |
| Waterlogged | `! Waterlogged` | `88% Check drains` |
| Probe fault | `! Sensor fault` | `Check A0->GPIO34` |
| Wi-Fi lost | `! Wi-Fi lost` | `Reconnecting...` |
| Bad calibration | `! Calibrate node` | `dry <= wet value` |

**Button (BOOT / GPIO 0):** short press = next page · hold 2 s = network page for 15 s (to read the IP) · hold 5 s = factory reset of Wi-Fi and pairing (release during the countdown to cancel).

## 8. REST API

Base URL `http://<node-ip>` (or `http://192.168.4.1` in direct mode). All endpoints except `/api/health` and `/api/pair/*` need the header `X-PULSE-Token: <token>`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Liveness, firmware, paired flag |
| GET | `/api/info` | Device, network and calibration details |
| GET | `/api/reading` | Live soil reading, network, last PHI |
| POST | `/api/pair/start` | Show a 6-digit PIN on the LCD (120 s) |
| POST | `/api/pair/confirm` | `{ "pin": "482913" }` → `{ "token": "..." }` |
| POST | `/api/calibrate` | `{ "point": "dry" }`, `{ "point": "wet" }`, `{ "dryRaw":..., "wetRaw":... }`, `{ "reset": true }` |
| POST | `/api/display` | `{ "phi":66, "tier":"ENHANCE", "locationName":"Community Garden", "ts":1795600000 }` |
| POST | `/api/config` | `{ "name"?, "locationId"?, "locationName"? }` |
| POST | `/api/identify` | Flash the backlight 3 times |

Try it with curl:
```bash
curl http://192.168.1.42/api/health
curl -X POST http://192.168.1.42/api/pair/start
curl -X POST http://192.168.1.42/api/pair/confirm -H 'Content-Type: application/json' -d '{"pin":"482913"}'
curl http://192.168.1.42/api/reading -H 'X-PULSE-Token: <token>'
```

Sample reading:
```json
{ "deviceId":"a1b2c3d4", "fw":"1.0.0", "seq":1532, "uptimeS":13320, "sampleAgeMs":420,
  "soil": { "raw":2310, "percent":46, "status":"OPTIMAL", "sensorOk":true, "stable":true, "min30s":45, "max30s":47 },
  "net":  { "mode":"sta", "rssi":-58, "ip":"192.168.1.42" },
  "lastPhi": { "phi":66, "tier":"ENHANCE", "locationName":"Community Garden", "ts":1795600000, "prevPhi":58 } }
```

## 9. Data and privacy

- The pairing token is stored only on the phone (SQLite) and on the node (NVS). It's never sent to Firestore.
- Firestore stores the soil reading inside the assessment (percent, raw, status, source, device ID, firmware, capture time and the phone's GPS at capture), plus a `devices/{deviceId}` record with the name, firmware and linked location.
- The node stores calibration, the token, its name, the linked location and the last 5 PHI values. A 5-second BOOT hold erases the Wi-Fi credentials and the token.

## 10. Troubleshooting

| Symptom | Check |
|---|---|
| LCD backlight on but no text | Turn the blue contrast potentiometer on the backpack; check the serial log for the detected I2C address |
| LCD blank, no backlight | 5V/VIN and GND wiring; some boards only put 5V on VIN when powered over USB |
| Reading stuck at 0 % or 100 %, "Sensor fault" | A0 must go to GPIO 34; the probe must be connected to the LM393 board; recalibrate |
| Value jumps around | Normal for 30 s after moving the probe (the app waits for `stable`); firm the soil around the probe |
| App can't find the node | Phone and node on the same network; some routers block mDNS, so use *Enter IP address* (hold BOOT 2 s to see the IP) |
| Works on home Wi-Fi, not in the field | Use **Direct to node**; if Android warns "no internet", choose *Stay connected* |
| "Pairing expired" in the app | The node was reset or re-paired from another phone. Pair again |
| Setup page doesn't open | Browse to `192.168.4.1` while joined to `PULSE-Node-XXXX` |
