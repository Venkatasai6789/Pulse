#include "net.h"
#include "lcd_ui.h"
#include "store.h"
#include "version.h"
#include <time.h>
#include <sys/time.h>

NodeNet Net;

void NodeNet::_initDeviceId() {
  uint64_t mac = ESP.getEfuseMac();
  uint32_t lower = (uint32_t)(mac & 0xFFFFFFFF);
  snprintf(_deviceId, sizeof(_deviceId), "%08lx", (unsigned long)lower);

  uint16_t last4 = (uint16_t)(lower & 0xFFFF);
  snprintf(_apSsid, sizeof(_apSsid), "PULSE-Node-%04X", last4);
  snprintf(_mdnsHost, sizeof(_mdnsHost), "pulse-node-%04x", last4);
}

void NodeNet::_setupNtp() {
  configTime(NTP_OFFSET_S, 0, "pool.ntp.org", "time.google.com");
}

void NodeNet::_setupMdns() {
  if (MDNS.begin(_mdnsHost)) {
    MDNS.addService("pulse", "tcp", 80);
    MDNS.addServiceTxt(String("pulse"), String("tcp"), String("id"), String(_deviceId));
    MDNS.addServiceTxt(String("pulse"), String("tcp"), String("fw"), String(FW_VERSION));
    MDNS.addServiceTxt(String("pulse"), String("tcp"), String("name"), String(getFriendlyName()));
    Serial.printf("[WIFI] mDNS responder started: %s.local\n", _mdnsHost);
  } else {
    Serial.println("[WIFI] Failed to start mDNS");
  }
}

const char* NodeNet::getFriendlyName() {
  static char nameBuf[32];
  String s = Store.getName();
  if (s.length() > 0) {
    strncpy(nameBuf, s.c_str(), sizeof(nameBuf) - 1);
  } else {
    strncpy(nameBuf, _apSsid, sizeof(nameBuf) - 1);
  }
  return nameBuf;
}

String NodeNet::getIpAddress() const {
  if (WiFi.status() == WL_CONNECTED) {
    return WiFi.localIP().toString();
  }
  return "192.168.4.1";
}

bool NodeNet::isConnected() const {
  return WiFi.status() == WL_CONNECTED;
}

void NodeNet::setClockFromEpoch(uint32_t epochSec) {
  struct timeval tv;
  tv.tv_sec = epochSec;
  tv.tv_usec = 0;
  settimeofday(&tv, NULL);
  Serial.printf("[NET] Clock synced via header: epoch %u\n", epochSec);
}

void NodeNet::begin() {
  _initDeviceId();
  Serial.printf("[BOOT] DeviceId: %s, SoftAP: %s\n", _deviceId, _apSsid);

  // Set dual mode: AP + STA
  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(false);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(true);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  WiFi.softAP(_apSsid, AP_PASSWORD);
  IPAddress apIP(192, 168, 4, 1);
  IPAddress netMsk(255, 255, 255, 0);
  WiFi.softAPConfig(apIP, apIP, netMsk);

  // Configure non-blocking WiFiManager
  _wm.setConfigPortalBlocking(false);
  _wm.setConfigPortalTimeout(180);
  _wm.setConnectTimeout(15);
  _wm.setTitle("P.U.L.S.E. Sensor Node");

  Lcd.showConnecting("Saved Wi-Fi");

  bool res = _wm.autoConnect(_apSsid, AP_PASSWORD);
  if (!res) {
    Serial.println("[WIFI] Running captive portal non-blocking");
    Lcd.showPortal(_apSsid, AP_PASSWORD, "192.168.4.1");
  } else {
    Serial.printf("[WIFI] Connected to STA, IP: %s (ch %d)\n",
                  WiFi.localIP().toString().c_str(), WiFi.channel());
    if (_wm.getConfigPortalActive()) {
      _wm.stopConfigPortal();
    }
    // Sync SoftAP to same Wi-Fi channel to eliminate AP+STA channel-hopping latency
    WiFi.softAP(_apSsid, AP_PASSWORD, WiFi.channel());
    WiFi.setSleep(false);
    _wasConnected = true;
    _setupNtp();
    _setupMdns();
    Lcd.showNetworkOverride(10);
  }
}

void NodeNet::loop() {
  if (_wm.getConfigPortalActive()) {
    _wm.process();
  }

  uint32_t now = millis();
  if (now - _lastWifiCheckMs >= WIFI_CHECK_MS) {
    _lastWifiCheckMs = now;

    if (WiFi.status() == WL_CONNECTED) {
      if (!_wasConnected) {
        _wasConnected = true;
        _disconnectedStartMs = 0;
        Serial.printf("[WIFI] Connected! SSID: %s, IP: %s, RSSI: %d dBm, ch=%d\n",
                      WiFi.SSID().c_str(), WiFi.localIP().toString().c_str(),
                      (int)WiFi.RSSI(), WiFi.channel());
        if (_wm.getConfigPortalActive()) {
          _wm.stopConfigPortal();
        }
        WiFi.softAP(_apSsid, AP_PASSWORD, WiFi.channel());
        WiFi.setSleep(false);
        _setupNtp();
        _setupMdns();
        Lcd.showNetworkOverride(10);
      }
    } else {
      if (_wasConnected) {
        if (_disconnectedStartMs == 0) {
          _disconnectedStartMs = now;
        } else if (now - _disconnectedStartMs >= 30000) {
          // Alert after 30s disconnected
          Lcd.triggerAlert(ALERT_WIFI_LOST);
        }
      }

      // Fast auto-reconnect if Wi-Fi network credentials exist in NVS
      if (WiFi.SSID().length() > 0) {
        static uint32_t lastReconnectAttemptMs = 0;
        if (now - lastReconnectAttemptMs >= 5000) {
          lastReconnectAttemptMs = now;
          Serial.printf("[WIFI] Attempting reconnect to %s...\n", WiFi.SSID().c_str());
          WiFi.reconnect();
        }
      }
    }
  }
}
