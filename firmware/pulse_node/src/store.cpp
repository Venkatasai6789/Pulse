#include "store.h"

NodeStore Store;

bool NodeStore::begin() {
  if (!_prefs.begin("pulse", false)) return false;
  _cachedDryRaw = _prefs.getInt("dryRaw", DEFAULT_DRY_RAW);
  _cachedWetRaw = _prefs.getInt("wetRaw", DEFAULT_WET_RAW);
  _cachedToken = _prefs.getString("token", "");
  _cachedPhiCount = _prefs.getInt("phi_cnt", 0);
  if (_cachedPhiCount > 0 && _prefs.getBytesLength("phi_0") == sizeof(PhiRecord)) {
    _prefs.getBytes("phi_0", &_cachedPhi, sizeof(PhiRecord));
    _hasCachedPhi = true;
  } else {
    _hasCachedPhi = false;
  }
  return true;
}

int NodeStore::getDryRaw() {
  return _cachedDryRaw;
}

int NodeStore::getWetRaw() {
  return _cachedWetRaw;
}

bool NodeStore::setCalibration(int dryRaw, int wetRaw) {
  if (dryRaw - wetRaw < 500) {
    return false;
  }
  _cachedDryRaw = dryRaw;
  _cachedWetRaw = wetRaw;
  _prefs.putInt("dryRaw", dryRaw);
  _prefs.putInt("wetRaw", wetRaw);
  return true;
}

void NodeStore::resetCalibration() {
  _cachedDryRaw = DEFAULT_DRY_RAW;
  _cachedWetRaw = DEFAULT_WET_RAW;
  _prefs.putInt("dryRaw", DEFAULT_DRY_RAW);
  _prefs.putInt("wetRaw", DEFAULT_WET_RAW);
}

String NodeStore::getToken() {
  return _cachedToken;
}

bool NodeStore::setToken(const String& token) {
  _cachedToken = token;
  return _prefs.putString("token", token) > 0;
}

bool NodeStore::clearToken() {
  _cachedToken = "";
  return _prefs.remove("token");
}

bool NodeStore::isPaired() {
  return _cachedToken.length() > 0;
}

String NodeStore::getName() {
  return _prefs.getString("name", "");
}

bool NodeStore::setName(const String& name) {
  return _prefs.putString("name", name) > 0;
}

String NodeStore::getLocationId() {
  return _prefs.getString("locId", "");
}

String NodeStore::getLocationName() {
  return _prefs.getString("locName", "");
}

bool NodeStore::setLocation(const String& id, const String& name) {
  _prefs.putString("locId", id);
  _prefs.putString("locName", name);
  return true;
}

bool NodeStore::pushPhi(int phi, const char* tier, const char* locName, uint32_t ts) {
  PhiRecord current;
  int prev = -1;
  if (getLatestPhi(current)) {
    prev = current.phi;
  }

  // Shift existing entries (up to 4 shifted)
  for (int i = 4; i >= 1; --i) {
    char key[16];
    snprintf(key, sizeof(key), "phi_%d", i - 1);
    size_t len = _prefs.getBytesLength(key);
    if (len == sizeof(PhiRecord)) {
      PhiRecord r;
      _prefs.getBytes(key, &r, sizeof(PhiRecord));
      snprintf(key, sizeof(key), "phi_%d", i);
      _prefs.putBytes(key, &r, sizeof(PhiRecord));
    }
  }

  PhiRecord entry;
  memset(&entry, 0, sizeof(entry));
  entry.phi = phi;
  entry.prevPhi = prev;
  entry.ts = ts;
  strncpy(entry.tier, tier, sizeof(entry.tier) - 1);
  strncpy(entry.locationName, locName, sizeof(entry.locationName) - 1);

  _prefs.putBytes("phi_0", &entry, sizeof(PhiRecord));
  _cachedPhi = entry;
  _hasCachedPhi = true;
  if (_cachedPhiCount < 5) {
    _cachedPhiCount++;
    _prefs.putInt("phi_cnt", _cachedPhiCount);
  }
  return true;
}

bool NodeStore::getLatestPhi(PhiRecord& out) {
  if (!_hasCachedPhi || _cachedPhiCount == 0) {
    return false;
  }
  out = _cachedPhi;
  return true;
}

int NodeStore::getPhiHistoryCount() {
  return _cachedPhiCount;
}

void NodeStore::factoryReset() {
  _cachedDryRaw = DEFAULT_DRY_RAW;
  _cachedWetRaw = DEFAULT_WET_RAW;
  _cachedToken = "";
  _hasCachedPhi = false;
  _cachedPhiCount = 0;
  _prefs.clear();
}
