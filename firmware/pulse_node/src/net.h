#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <ESPmDNS.h>
#include <WiFiManager.h>
#include "config.h"

class NodeNet {
public:
  void begin();
  void loop(); // Call in loop()

  const char* getDeviceId() const { return _deviceId; }
  const char* getApSsid() const { return _apSsid; }
  const char* getFriendlyName();
  String getIpAddress() const;
  bool isConnected() const;

  void setClockFromEpoch(uint32_t epochSec);

private:
  char _deviceId[9];
  char _apSsid[24];
  char _mdnsHost[32];
  uint32_t _lastWifiCheckMs = 0;
  uint32_t _disconnectedStartMs = 0;
  bool _wasConnected = false;
  WiFiManager _wm;

  void _initDeviceId();
  void _setupNtp();
  void _setupMdns();
};

extern NodeNet Net;
