#pragma once
#include <Arduino.h>
#include <Preferences.h>
#include "config.h"

struct PhiRecord {
  int phi;
  char tier[16];
  char locationName[32];
  uint32_t ts;
  int prevPhi;
};

class NodeStore {
public:
  bool begin();
  
  // Calibration
  int getDryRaw();
  int getWetRaw();
  bool setCalibration(int dryRaw, int wetRaw);
  void resetCalibration();

  // Auth & Token
  String getToken();
  bool setToken(const String& token);
  bool clearToken();
  bool isPaired();

  // Device configuration
  String getName();
  bool setName(const String& name);
  String getLocationId();
  String getLocationName();
  bool setLocation(const String& id, const String& name);

  // PHI History (up to 5 records)
  bool pushPhi(int phi, const char* tier, const char* locName, uint32_t ts);
  bool getLatestPhi(PhiRecord& out);
  int getPhiHistoryCount();

  // Reset
  void factoryReset();

private:
  Preferences _prefs;
  int _cachedDryRaw = DEFAULT_DRY_RAW;
  int _cachedWetRaw = DEFAULT_WET_RAW;
  String _cachedToken = "";
  bool _hasCachedPhi = false;
  PhiRecord _cachedPhi;
  int _cachedPhiCount = 0;
};

extern NodeStore Store;
