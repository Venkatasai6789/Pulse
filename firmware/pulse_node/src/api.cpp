#include "api.h"
#include "net.h"
#include "soil_sensor.h"
#include "store.h"
#include "lcd_ui.h"
#include "version.h"
#include <ArduinoJson.h>

NodeApi Api;
uint32_t gLastAppSyncMs = 0;

void NodeApi::begin() {
  const char* headers[] = {"X-PULSE-Token", "X-PULSE-Time", "Authorization"};
  _server.collectHeaders(headers, 3);

  _server.on("/api/health", HTTP_GET, [this]() { _handleHealth(); });
  _server.on("/health", HTTP_GET, [this]() { _handleHealth(); });
  _server.on("/api/info", HTTP_GET, [this]() { _handleInfo(); });
  _server.on("/info", HTTP_GET, [this]() { _handleInfo(); });
  _server.on("/api/reading", HTTP_GET, [this]() { _handleReading(); });
  _server.on("/reading", HTTP_GET, [this]() { _handleReading(); });
  _server.on("/telemetry", HTTP_GET, [this]() { _handleReading(); });
  _server.on("/api/pair/start", HTTP_POST, [this]() { _handlePairStart(); });
  _server.on("/pair/start", HTTP_POST, [this]() { _handlePairStart(); });
  _server.on("/api/pair/confirm", HTTP_POST, [this]() { _handlePairConfirm(); });
  _server.on("/pair/confirm", HTTP_POST, [this]() { _handlePairConfirm(); });
  _server.on("/api/calibrate", HTTP_POST, [this]() { _handleCalibrate(); });
  _server.on("/calibrate", HTTP_POST, [this]() { _handleCalibrate(); });
  _server.on("/api/display", HTTP_POST, [this]() { _handleDisplay(); });
  _server.on("/api/config", HTTP_POST, [this]() { _handleConfig(); });
  _server.on("/api/identify", HTTP_POST, [this]() { _handleIdentify(); });

  _server.onNotFound([this]() {
    if (_server.method() == HTTP_OPTIONS) {
      _server.sendHeader("Access-Control-Allow-Origin", "*");
      _server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      _server.sendHeader("Access-Control-Allow-Headers", "Content-Type, X-PULSE-Token, X-PULSE-Time, Authorization");
      _server.send(204);
      return;
    }
    _server.send(404, "text/plain", "Not Found");
  });

  _server.enableDelay(false);
  _server.begin();
  Serial.println("[API] WebServer running on port 80");
}

void NodeApi::loop() {
  _server.handleClient();
}

void NodeApi::_sendJson(int code, const String& json) {
  _server.sendHeader("Access-Control-Allow-Origin", "*");
  _server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  _server.sendHeader("Access-Control-Allow-Headers", "Content-Type, X-PULSE-Token, X-PULSE-Time, Authorization");
  _server.sendHeader("Connection", "close");
  _server.send(code, "application/json", json);
}

void NodeApi::_sendError(int code, const char* err, const char* msg) {
  JsonDocument doc;
  doc["error"] = err;
  doc["message"] = msg;
  String out;
  serializeJson(doc, out);
  _sendJson(code, out);
}

bool NodeApi::_checkAuth() {
  if (!Store.isPaired()) {
    _sendError(401, "unauthorized", "Node is not paired yet");
    return false;
  }

  String token = "";
  if (_server.hasHeader("X-PULSE-Token")) {
    token = _server.header("X-PULSE-Token");
  } else if (_server.hasHeader("Authorization")) {
    String auth = _server.header("Authorization");
    if (auth.startsWith("Bearer ")) {
      token = auth.substring(7);
    } else {
      token = auth;
    }
  } else if (_server.hasArg("token")) {
    token = _server.arg("token");
  }

  token.trim();
  if (token.length() == 0) {
    _sendError(401, "unauthorized", "Missing X-PULSE-Token header");
    return false;
  }

  if (token != Store.getToken()) {
    Serial.printf("[AUTH] Token mismatch! Expected len=%d, Received len=%d\n",
                  Store.getToken().length(), token.length());
    _sendError(401, "unauthorized", "Invalid or expired token");
    return false;
  }

  // Update sync timestamp
  gLastAppSyncMs = millis();

  // If time header is present, sync clock only if unsynced or drifted > 60s
  if (_server.hasHeader("X-PULSE-Time")) {
    String tStr = _server.header("X-PULSE-Time");
    uint32_t ep = strtoul(tStr.c_str(), NULL, 10);
    if (ep > 1600000000) {
      time_t cur = time(nullptr);
      long diff = (cur > 1600000000) ? labs((long)ep - (long)cur) : 999999L;
      if (diff > 60) {
        Net.setClockFromEpoch(ep);
      }
    }
  }

  return true;
}

void NodeApi::_handleHealth() {
  JsonDocument doc;
  doc["ok"] = true;
  doc["deviceId"] = Net.getDeviceId();
  doc["fw"] = FW_VERSION;
  doc["uptimeS"] = millis() / 1000;
  doc["paired"] = Store.isPaired();

  String out;
  serializeJson(doc, out);
  _sendJson(200, out);
}

void NodeApi::_handleInfo() {
  if (!_checkAuth()) return;

  JsonDocument doc;
  doc["deviceId"] = Net.getDeviceId();
  doc["name"] = Net.getFriendlyName();
  doc["fw"] = FW_VERSION;
  doc["mode"] = (WiFi.status() == WL_CONNECTED) ? "sta" : "ap";
  doc["ip"] = Net.getIpAddress();
  doc["apIp"] = "192.168.4.1";
  doc["rssi"] = (int)WiFi.RSSI();
  doc["ssid"] = WiFi.SSID();
  doc["lcdAddr"] = "0x27";

  JsonObject cal = doc["calibration"].to<JsonObject>();
  cal["dryRaw"] = Store.getDryRaw();
  cal["wetRaw"] = Store.getWetRaw();

  doc["locationId"] = Store.getLocationId();
  doc["locationName"] = Store.getLocationName();

  String out;
  serializeJson(doc, out);
  _sendJson(200, out);
}

void NodeApi::_handleReading() {
  if (!_checkAuth()) return;

  const auto& s = Soil.getLatest();
  uint32_t now = millis();

  JsonDocument doc;
  doc["deviceId"] = Net.getDeviceId();
  doc["fw"] = FW_VERSION;
  doc["seq"] = s.seq;
  doc["uptimeS"] = now / 1000;
  doc["sampleAgeMs"] = (s.sampleTimeMs > 0) ? (now - s.sampleTimeMs) : 0;

  JsonObject soilObj = doc["soil"].to<JsonObject>();
  soilObj["raw"] = s.raw;
  soilObj["percent"] = s.percent;
  soilObj["status"] = s.statusCode;
  soilObj["sensorOk"] = s.sensorOk;
  soilObj["stable"] = s.stable;
  soilObj["min30s"] = s.min30s;
  soilObj["max30s"] = s.max30s;

  JsonObject netObj = doc["net"].to<JsonObject>();
  netObj["mode"] = (WiFi.status() == WL_CONNECTED) ? "sta" : "ap";
  netObj["rssi"] = (int)WiFi.RSSI();
  netObj["ip"] = Net.getIpAddress();

  PhiRecord phi;
  if (Store.getLatestPhi(phi)) {
    JsonObject phiObj = doc["lastPhi"].to<JsonObject>();
    phiObj["phi"] = phi.phi;
    phiObj["tier"] = phi.tier;
    phiObj["locationName"] = phi.locationName;
    phiObj["ts"] = phi.ts;
    phiObj["prevPhi"] = (phi.prevPhi >= 0) ? phi.prevPhi : (int)phi.phi;
  } else {
    doc["lastPhi"] = nullptr;
  }

  String out;
  serializeJson(doc, out);
  _sendJson(200, out);
}

void NodeApi::_handlePairStart() {
  uint32_t now = millis();
  if (now < _lockoutUntilMs) {
    _sendError(429, "pairingLocked", "Too many wrong PINs. Try again in a minute");
    return;
  }

  // Generate 6-digit random PIN
  uint32_t randVal = esp_random();
  uint32_t pinNum = (randVal % 900000) + 100000;
  snprintf(_activePin, sizeof(_activePin), "%06lu", (unsigned long)pinNum);
  _pinGeneratedMs = now;
  _pinActive = true;

  Lcd.showPairing(_activePin, PAIR_PIN_TTL_S);
  Serial.printf("[PAIR] Started, PIN: %s (expires in %ds)\n", _activePin, PAIR_PIN_TTL_S);

  JsonDocument doc;
  doc["expiresInS"] = PAIR_PIN_TTL_S;
  String out;
  serializeJson(doc, out);
  _sendJson(200, out);
}

void NodeApi::_handlePairConfirm() {
  uint32_t now = millis();
  if (now < _lockoutUntilMs) {
    _sendError(429, "pairingLocked", "Too many wrong PINs. Try again in a minute");
    return;
  }

  if (!_pinActive || (now - _pinGeneratedMs > (PAIR_PIN_TTL_S * 1000))) {
    _pinActive = false;
    Lcd.cancelPairing();
    _sendError(400, "pinExpired", "Pairing PIN has expired. Start again");
    return;
  }

  if (!_server.hasArg("plain")) {
    _sendError(400, "badRequest", "Missing request body");
    return;
  }

  JsonDocument bodyDoc;
  DeserializationError err = deserializeJson(bodyDoc, _server.arg("plain"));
  if (err || !bodyDoc["pin"].is<String>()) {
    _sendError(400, "badRequest", "Invalid JSON format");
    return;
  }

  String enteredPin = bodyDoc["pin"].as<String>();
  if (enteredPin != _activePin) {
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _lockoutUntilMs = now + (PAIR_LOCKOUT_S * 1000);
      _pinActive = false;
      Lcd.cancelPairing();
      _sendError(429, "pairingLocked", "Too many wrong PINs. Locked for 60s");
      return;
    }
    _sendError(401, "invalidPin", "Incorrect PIN");
    return;
  }

  // PIN matched! Generate 32-char hex token
  char tokenBuf[33];
  uint32_t r1 = esp_random();
  uint32_t r2 = esp_random();
  uint32_t r3 = esp_random();
  uint32_t r4 = esp_random();
  snprintf(tokenBuf, sizeof(tokenBuf), "%08lx%08lx%08lx%08lx",
           (unsigned long)r1, (unsigned long)r2, (unsigned long)r3, (unsigned long)r4);

  Store.setToken(tokenBuf);
  _pinActive = false;
  _failedAttempts = 0;
  Lcd.cancelPairing();

  Serial.printf("[PAIR] Success! Token generated for %s\n", Net.getDeviceId());

  JsonDocument res;
  res["token"] = tokenBuf;
  res["deviceId"] = Net.getDeviceId();
  res["name"] = Net.getFriendlyName();

  String out;
  serializeJson(res, out);
  _sendJson(200, out);
}

void NodeApi::_handleCalibrate() {
  if (!_checkAuth()) return;

  if (!_server.hasArg("plain")) {
    _sendError(400, "badRequest", "Missing body");
    return;
  }

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, _server.arg("plain"));
  if (err) {
    _sendError(400, "badRequest", "Malformed JSON");
    return;
  }

  int dry = Store.getDryRaw();
  int wet = Store.getWetRaw();

  if (doc["reset"].is<bool>() && doc["reset"].as<bool>()) {
    Store.resetCalibration();
    dry = Store.getDryRaw();
    wet = Store.getWetRaw();
  } else if (doc["point"].is<String>()) {
    String pt = doc["point"].as<String>();
    int curRaw = Soil.getLatest().raw;
    if (pt == "dry") {
      dry = curRaw;
    } else if (pt == "wet") {
      wet = curRaw;
    } else {
      _sendError(400, "badRequest", "Invalid point: must be dry or wet");
      return;
    }
    if (!Store.setCalibration(dry, wet)) {
      _sendError(400, "calibrationInvalid", "dryRaw minus wetRaw must be at least 500");
      return;
    }
  } else if (doc["dryRaw"].is<int>() && doc["wetRaw"].is<int>()) {
    dry = doc["dryRaw"].as<int>();
    wet = doc["wetRaw"].as<int>();
    if (!Store.setCalibration(dry, wet)) {
      _sendError(400, "calibrationInvalid", "dryRaw minus wetRaw must be at least 500");
      return;
    }
  }

  JsonDocument res;
  res["dryRaw"] = Store.getDryRaw();
  res["wetRaw"] = Store.getWetRaw();
  String out;
  serializeJson(res, out);
  _sendJson(200, out);
}

void NodeApi::_handleDisplay() {
  if (!_checkAuth()) return;

  if (!_server.hasArg("plain")) {
    _sendError(400, "badRequest", "Missing body");
    return;
  }

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, _server.arg("plain"));
  if (err || !doc["phi"].is<int>() || !doc["tier"].is<String>()) {
    _sendError(400, "badRequest", "Invalid display payload");
    return;
  }

  int phi = doc["phi"].as<int>();
  String tier = doc["tier"].as<String>();
  String locName = doc["locationName"] | "Community Garden";
  uint32_t ts = doc["ts"] | (uint32_t)(millis() / 1000);

  Store.pushPhi(phi, tier.c_str(), locName.c_str(), ts);
  Serial.printf("[API] Display updated: PHI=%d, Tier=%s, Loc=%s\n", phi, tier.c_str(), locName.c_str());

  JsonDocument res;
  res["ok"] = true;
  String out;
  serializeJson(res, out);
  _sendJson(200, out);
}

void NodeApi::_handleConfig() {
  if (!_checkAuth()) return;

  if (!_server.hasArg("plain")) {
    _sendError(400, "badRequest", "Missing body");
    return;
  }

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, _server.arg("plain"));
  if (err) {
    _sendError(400, "badRequest", "Malformed JSON");
    return;
  }

  if (doc["name"].is<String>()) {
    Store.setName(doc["name"].as<String>());
  }
  if (doc["locationId"].is<String>() || doc["locationName"].is<String>()) {
    String id = doc["locationId"] | Store.getLocationId();
    String name = doc["locationName"] | Store.getLocationName();
    Store.setLocation(id, name);
  }

  JsonDocument res;
  res["ok"] = true;
  String out;
  serializeJson(res, out);
  _sendJson(200, out);
}

void NodeApi::_handleIdentify() {
  if (!_checkAuth()) return;

  Serial.println("[API] Identify requested, flashing backlight");
  Lcd.identifyFlash();

  JsonDocument res;
  res["ok"] = true;
  String out;
  serializeJson(res, out);
  _sendJson(200, out);
}
