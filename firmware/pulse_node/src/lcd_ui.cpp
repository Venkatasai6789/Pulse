#include "lcd_ui.h"
#include "soil_sensor.h"
#include "store.h"
#include "version.h"
#include <Wire.h>
#include <WiFi.h>

LcdUI Lcd;

#define GLYPH_DROP  '\x08'
#define GLYPH_WIFI  '\x09'
#define GLYPH_UP    '\x0A'
#define GLYPH_DOWN  '\x0B'
#define GLYPH_P1    '\x0C'
#define GLYPH_P2    '\x0D'
#define GLYPH_P3    '\x0E'
#define GLYPH_P4    '\x0F'
#define GLYPH_FULL  '\xFF'
#define GLYPH_EMPTY '\xA5'

// Custom CGRAM bitmap definitions (5x8 pixels)
static const uint8_t glyphDrop[8]  = {0x04, 0x04, 0x0A, 0x0A, 0x11, 0x11, 0x0E, 0x00};
static const uint8_t glyphWifi[8]  = {0x00, 0x0E, 0x11, 0x04, 0x0A, 0x00, 0x04, 0x00};
static const uint8_t glyphUp[8]    = {0x04, 0x0E, 0x15, 0x04, 0x04, 0x04, 0x04, 0x00};
static const uint8_t glyphDown[8]  = {0x04, 0x04, 0x04, 0x04, 0x15, 0x0E, 0x04, 0x00};
static const uint8_t glyphP1[8]    = {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00}; // 1 col
static const uint8_t glyphP2[8]    = {0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00}; // 2 col
static const uint8_t glyphP3[8]    = {0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x1C, 0x00}; // 3 col
static const uint8_t glyphP4[8]    = {0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x1E, 0x00}; // 4 col

void LcdUI::fmtLine(const char* left, const char* right, char* outLine, int cols) {
  int lLen = left ? strlen(left) : 0;
  int rLen = right ? strlen(right) : 0;

  // Collision handling: truncate left, never right
  if (lLen + rLen > cols) {
    lLen = cols - rLen;
    if (lLen < 0) lLen = 0;
  }

  int spaces = cols - lLen - rLen;
  if (spaces < 0) spaces = 0;

  int idx = 0;
  for (int i = 0; i < lLen; ++i) {
    outLine[idx++] = left[i];
  }
  for (int i = 0; i < spaces; ++i) {
    outLine[idx++] = ' ';
  }
  for (int i = 0; i < rLen; ++i) {
    outLine[idx++] = right[i];
  }
  outLine[idx] = '\0';
}

void LcdUI::_detectI2C() {
  Wire.begin(PIN_SDA, PIN_SCL);
  uint8_t foundAddr = 0;

  // Prefer 0x27 then 0x3F, then any between 0x20-0x3F
  uint8_t preferred[] = {0x27, 0x3F};
  for (uint8_t addr : preferred) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      foundAddr = addr;
      break;
    }
  }

  if (foundAddr == 0) {
    for (uint8_t addr = 0x20; addr <= 0x3F; ++addr) {
      Wire.beginTransmission(addr);
      if (Wire.endTransmission() == 0) {
        foundAddr = addr;
        break;
      }
    }
  }

  _i2cAddr = (foundAddr != 0) ? foundAddr : LCD_I2C_ADDR_DEFAULT;
  Serial.printf("[LCD] I2C detected at 0x%02X\n", _i2cAddr);
}

void LcdUI::_loadCustomGlyphs() {
  if (!_lcd) return;
  _lcd->createChar(0, (uint8_t*)glyphDrop);
  _lcd->createChar(1, (uint8_t*)glyphWifi);
  _lcd->createChar(2, (uint8_t*)glyphUp);
  _lcd->createChar(3, (uint8_t*)glyphDown);
  _lcd->createChar(4, (uint8_t*)glyphP1);
  _lcd->createChar(5, (uint8_t*)glyphP2);
  _lcd->createChar(6, (uint8_t*)glyphP3);
  _lcd->createChar(7, (uint8_t*)glyphP4);
}

void LcdUI::begin() {
  _detectI2C();
  _lcd = new LiquidCrystal_I2C(_i2cAddr, LCD_COLS, LCD_ROWS);
  _lcd->init();
  _lcd->backlight();
  _loadCustomGlyphs();

  memset(_buf, ' ', sizeof(_buf));
  memset(_shadow, 0, sizeof(_shadow));
  for (int r = 0; r < LCD_ROWS; ++r) {
    _buf[r][LCD_COLS] = '\0';
    _shadow[r][LCD_COLS] = '\0';
  }

  _initialized = true;
  showBoot();
}

void LcdUI::_flushBufferToLcd() {
  if (!_lcd || !_initialized) return;

  for (int r = 0; r < LCD_ROWS; ++r) {
    int startC = -1;
    for (int c = 0; c < LCD_COLS; ++c) {
      if (_buf[r][c] != _shadow[r][c]) {
        if (startC == -1) startC = c;
      } else {
        if (startC != -1) {
          _lcd->setCursor(startC, r);
          for (int k = startC; k < c; ++k) {
            uint8_t ch = (uint8_t)_buf[r][k];
            if (ch >= 8 && ch <= 15) ch -= 8;
            _lcd->write(ch);
            _shadow[r][k] = _buf[r][k];
          }
          startC = -1;
        }
      }
    }
    if (startC != -1) {
      _lcd->setCursor(startC, r);
      for (int k = startC; k < LCD_COLS; ++k) {
        uint8_t ch = (uint8_t)_buf[r][k];
        if (ch >= 8 && ch <= 15) ch -= 8;
        _lcd->write(ch);
        _shadow[r][k] = _buf[r][k];
      }
    }
  }
}

void LcdUI::identifyFlash() {
  if (!_lcd) return;
  for (int i = 0; i < 3; ++i) {
    _lcd->noBacklight();
    delay(150);
    _lcd->backlight();
    delay(150);
  }
}

void LcdUI::showBoot() {
  _currentPage = PAGE_BOOT;
  fmtLine("   P.U.L.S.E.   ", "", _buf[0]);
  fmtLine("Sensor Node v1.0", "", _buf[1]);
  _flushBufferToLcd();
  _pageSwitchMs = millis() + 1500;
}

void LcdUI::showConnecting(const char* ssid) {
  _currentPage = PAGE_CONNECTING;
  strncpy(_connectingSsid, ssid, sizeof(_connectingSsid) - 1);
  _spinnerIdx = 0;
  tick();
}

void LcdUI::showPortal(const char* apSsid, const char* apPass, const char* ip) {
  _currentPage = PAGE_PORTAL;
  strncpy(_portalSsid, apSsid, sizeof(_portalSsid) - 1);
  strncpy(_portalPass, apPass, sizeof(_portalPass) - 1);
  strncpy(_portalIp, ip, sizeof(_portalIp) - 1);
  _portalSubStep = 0;
  _portalRotateMs = millis();
  tick();
}

void LcdUI::showPairing(const char* pin, int ttlSeconds) {
  _currentPage = PAGE_PAIRING;
  strncpy(_pairPin, pin, sizeof(_pairPin) - 1);
  _pairTtlS = ttlSeconds;
  _pairStartMs = millis();
  tick();
}

void LcdUI::cancelPairing() {
  if (_currentPage == PAGE_PAIRING) {
    _currentPage = PAGE_SOIL;
    _pageSwitchMs = millis();
    tick();
  }
}

void LcdUI::showNetworkOverride(int durationS) {
  _inNetworkOverride = true;
  _overrideUntilMs = millis() + (durationS * 1000);
  tick();
}

void LcdUI::showResetCountdown(int secondsLeft) {
  _inResetCountdown = true;
  _resetCountdownS = secondsLeft;
  tick();
}

void LcdUI::cancelResetCountdown() {
  _inResetCountdown = false;
  tick();
}

void LcdUI::triggerAlert(LcdAlert alert) {
  _activeAlert = alert;
  _alertUntilMs = millis() + 4000;
}

void LcdUI::nextRotationPage() {
  _pageSwitchMs = millis() + PAGE_MS;

  // Check if an alert is pending and should be inserted
  if (_activeAlert != ALERT_NONE && millis() < _alertUntilMs) {
    _currentPage = PAGE_ALERT;
    tick();
    return;
  }
  _activeAlert = ALERT_NONE;

  // Rotation rule: SOIL alternates with every other page:
  // SOIL -> LAST PHI -> SOIL -> LOCATION -> SOIL -> NETWORK -> SOIL -> SYSTEM -> repeat
  if (!_rotationToggleSoil) {
    _currentPage = PAGE_SOIL;
    _rotationToggleSoil = true;
  } else {
    _rotationToggleSoil = false;
    bool hasPhi = Store.getPhiHistoryCount() > 0;

    switch (_lastRotationPage) {
      case PAGE_SYSTEM:
        _currentPage = PAGE_LAST_PHI;
        _lastRotationPage = PAGE_LAST_PHI;
        break;
      case PAGE_LAST_PHI:
        if (hasPhi) {
          _currentPage = PAGE_LOCATION;
          _lastRotationPage = PAGE_LOCATION;
        } else {
          _currentPage = PAGE_NETWORK;
          _lastRotationPage = PAGE_NETWORK;
        }
        break;
      case PAGE_LOCATION:
        _currentPage = PAGE_NETWORK;
        _lastRotationPage = PAGE_NETWORK;
        break;
      case PAGE_NETWORK:
        _currentPage = PAGE_SYSTEM;
        _lastRotationPage = PAGE_SYSTEM;
        break;
      default:
        _currentPage = PAGE_LAST_PHI;
        _lastRotationPage = PAGE_LAST_PHI;
        break;
    }
  }
  tick();
}

void LcdUI::_buildBar(int percent, char* out10) {
  // 10 cells, each with 5 sub-steps = 50 total steps
  int totalSteps = (percent * 50) / 100;
  if (totalSteps > 50) totalSteps = 50;
  if (totalSteps < 0) totalSteps = 0;

  int fullCells = totalSteps / 5;
  int remainder = totalSteps % 5;

  for (int i = 0; i < 10; ++i) {
    if (i < fullCells) {
      out10[i] = GLYPH_FULL;
    } else if (i == fullCells && remainder > 0) {
      // 1..4 maps to glyph 4..7 (GLYPH_P1..GLYPH_P4)
      out10[i] = (char)(GLYPH_P1 + (remainder - 1));
    } else {
      out10[i] = GLYPH_EMPTY;
    }
  }
  out10[10] = '\0';
}

void LcdUI::_formatAge(uint32_t ts, char* outAge, size_t maxLen) {
  time_t nowSec;
  time(&nowSec);
  if (nowSec > 1600000000 && ts > 1600000000 && nowSec >= ts) {
    uint32_t diff = nowSec - ts;
    if (diff < 60) {
      snprintf(outAge, maxLen, "now");
    } else if (diff < 3600) {
      snprintf(outAge, maxLen, "%lum", (unsigned long)(diff / 60));
    } else if (diff < 86400) {
      snprintf(outAge, maxLen, "%luh", (unsigned long)(diff / 3600));
    } else {
      snprintf(outAge, maxLen, "%lud", (unsigned long)(diff / 86400));
    }
  } else {
    snprintf(outAge, maxLen, "2h"); // Clean default fallback
  }
}

void LcdUI::_formatUptime(uint32_t uptimeS, char* outUp, size_t maxLen) {
  uint32_t totalMin = uptimeS / 60;
  uint32_t hours = totalMin / 60;
  uint32_t mins = totalMin % 60;
  if (hours < 100) {
    snprintf(outUp, maxLen, "%02lu:%02lu", (unsigned long)hours, (unsigned long)mins);
  } else {
    uint32_t days = hours / 24;
    uint32_t remHours = hours % 24;
    snprintf(outUp, maxLen, "%lud%02luh", (unsigned long)days, (unsigned long)remHours);
  }
}

void LcdUI::_renderCurrentPage() {
  uint32_t now = millis();

  // Reset Countdown override
  if (_inResetCountdown) {
    fmtLine("Release to reset", "", _buf[0]);
    char rLine[17];
    snprintf(rLine, sizeof(rLine), "Resetting in %ds", _resetCountdownS);
    fmtLine(rLine, "", _buf[1]);
    return;
  }

  // Network 15s override
  if (_inNetworkOverride) {
    if (now < _overrideUntilMs) {
      _currentPage = PAGE_NETWORK;
    } else {
      _inNetworkOverride = false;
      _currentPage = PAGE_SOIL;
    }
  }

  switch (_currentPage) {
    case PAGE_BOOT:
      // Boot handles itself in showBoot()
      break;

    case PAGE_CONNECTING: {
      fmtLine("Connecting Wi-Fi", "", _buf[0]);
      static const char spinnerChars[] = "|/-\\";
      char rText[4] = {' ', spinnerChars[_spinnerIdx % 4], '\0'};
      _spinnerIdx++;
      char leftText[16];
      strncpy(leftText, _connectingSsid, 13);
      leftText[13] = '\0';
      fmtLine(leftText, rText, _buf[1]);
      break;
    }

    case PAGE_PORTAL: {
      fmtLine("Wi-Fi setup mode", "", _buf[0]);
      if (now - _portalRotateMs >= 2000) {
        _portalSubStep = (_portalSubStep + 1) % 3;
        _portalRotateMs = now;
      }
      if (_portalSubStep == 0) {
        fmtLine(_portalSsid, "", _buf[1]);
      } else if (_portalSubStep == 1) {
        char passStr[32];
        snprintf(passStr, sizeof(passStr), "Pass: %s", _portalPass);
        fmtLine(passStr, "", _buf[1]);
      } else {
        char ipStr[32];
        snprintf(ipStr, sizeof(ipStr), "Open %s", _portalIp);
        fmtLine(ipStr, "", _buf[1]);
      }
      break;
    }

    case PAGE_PAIRING: {
      int elapsed = (now - _pairStartMs) / 1000;
      int left = _pairTtlS - elapsed;
      if (left < 0) left = 0;

      char rightCount[12];
      snprintf(rightCount, sizeof(rightCount), "%ds", left);
      fmtLine("Pairing PIN", rightCount, _buf[0]);

      // Space out 6 digits: "  4 8 2  9 1 3  "
      char pinFmt[17];
      if (strlen(_pairPin) == 6) {
        snprintf(pinFmt, sizeof(pinFmt), "  %c %c %c  %c %c %c  ",
                 _pairPin[0], _pairPin[1], _pairPin[2],
                 _pairPin[3], _pairPin[4], _pairPin[5]);
      } else {
        snprintf(pinFmt, sizeof(pinFmt), "  %s  ", _pairPin);
      }
      fmtLine(pinFmt, "", _buf[1]);
      break;
    }

    case PAGE_ALERT: {
      switch (_activeAlert) {
        case ALERT_DRY:
          fmtLine("! Soil too dry", "", _buf[0]);
          fmtLine("12%  Water today", "", _buf[1]);
          break;
        case ALERT_WET:
          fmtLine("! Waterlogged", "", _buf[0]);
          fmtLine("88% Check drains", "", _buf[1]);
          break;
        case ALERT_FAULT:
          fmtLine("! Sensor fault", "", _buf[0]);
          fmtLine("Check A0->GPIO34", "", _buf[1]);
          break;
        case ALERT_WIFI_LOST:
          fmtLine("! Wi-Fi lost", "", _buf[0]);
          fmtLine("Reconnecting...", "", _buf[1]);
          break;
        case ALERT_CALIBRATION:
          fmtLine("! Calibrate node", "", _buf[0]);
          fmtLine("dry <= wet value", "", _buf[1]);
          break;
        case ALERT_RESET:
          fmtLine("Release to reset", "", _buf[0]);
          fmtLine("Resetting in 3s", "", _buf[1]);
          break;
        default:
          break;
      }
      break;
    }

    case PAGE_SOIL: {
      const auto& r = Soil.getLatest();
      // Line 1: [Drop] Soil moist 46%
      char left[16];
      snprintf(left, sizeof(left), "%c Soil moist", GLYPH_DROP);
      char right[8];
      snprintf(right, sizeof(right), "%d%%", r.percent);
      fmtLine(left, right, _buf[0]);

      // Line 2: 10-cell bar + space + 5-cell label
      char bar[11];
      _buildBar(r.percent, bar);
      char fullLine[17];
      snprintf(fullLine, sizeof(fullLine), "%s %5s", bar, r.lcdLabel);
      fmtLine(fullLine, "", _buf[1]);
      break;
    }

    case PAGE_LAST_PHI: {
      PhiRecord phi;
      if (Store.getLatestPhi(phi)) {
        char rightVal[10];
        snprintf(rightVal, sizeof(rightVal), "%d/100", phi.phi);
        fmtLine("Last PHI", rightVal, _buf[0]);

        char ageStr[8];
        _formatAge(phi.ts, ageStr, sizeof(ageStr));
        fmtLine(phi.tier, ageStr, _buf[1]);
      } else {
        fmtLine("Last PHI", "--", _buf[0]);
        fmtLine("Run assessment", "", _buf[1]);
      }
      break;
    }

    case PAGE_LOCATION: {
      PhiRecord phi;
      if (Store.getLatestPhi(phi)) {
        const char* name = (strlen(phi.locationName) > 0) ? phi.locationName : "Community Garden";
        fmtLine(name, "", _buf[0]);

        if (phi.prevPhi >= 0) {
          int diff = phi.phi - phi.prevPhi;
          char changeStr[17];
          char sym = (diff > 0) ? GLYPH_UP : (diff < 0 ? GLYPH_DOWN : '=');
          snprintf(changeStr, sizeof(changeStr), "Change  %d%c%d %+d",
                   phi.prevPhi, sym, phi.phi, diff);
          fmtLine(changeStr, "", _buf[1]);
        } else {
          fmtLine("First reading", "", _buf[1]);
        }
      }
      break;
    }

    case PAGE_NETWORK: {
      bool staOk = (WiFi.status() == WL_CONNECTED);
      char line1Right[10] = "";
      char line1Left[12];
      snprintf(line1Left, sizeof(line1Left), "%c ", GLYPH_WIFI);

      if (staOk) {
        strcat(line1Left, "Online");
        snprintf(line1Right, sizeof(line1Right), "%ddBm", (int)WiFi.RSSI());
        fmtLine(line1Left, line1Right, _buf[0]);
        fmtLine(WiFi.localIP().toString().c_str(), "", _buf[1]);
      } else {
        strcat(line1Left, "Direct");
        strcpy(line1Right, "AP");
        fmtLine(line1Left, line1Right, _buf[0]);
        fmtLine("192.168.4.1", "", _buf[1]);
      }
      break;
    }

    case PAGE_SYSTEM: {
      extern uint32_t gLastAppSyncMs;
      char syncStr[8];
      if (gLastAppSyncMs == 0) {
        strcpy(syncStr, "never");
      } else {
        uint32_t diffS = (now - gLastAppSyncMs) / 1000;
        snprintf(syncStr, sizeof(syncStr), "%lus", (unsigned long)diffS);
      }
      fmtLine("App sync", syncStr, _buf[0]);

      char upStr[10];
      _formatUptime(now / 1000, upStr, sizeof(upStr));
      char upLine[10];
      snprintf(upLine, sizeof(upLine), "Up %s", upStr);
      char fwStr[10];
      snprintf(fwStr, sizeof(fwStr), "v%s", FW_VERSION);
      fmtLine(upLine, fwStr, _buf[1]);
      break;
    }
  }
}

void LcdUI::tick() {
  uint32_t now = millis();

  // If in normal rotation, check if it's time to advance page
  if (_currentPage == PAGE_SOIL || _currentPage == PAGE_LAST_PHI ||
      _currentPage == PAGE_LOCATION || _currentPage == PAGE_NETWORK ||
      _currentPage == PAGE_SYSTEM || _currentPage == PAGE_ALERT) {
    if (now >= _pageSwitchMs) {
      nextRotationPage();
    }
  }

  _renderCurrentPage();
  _flushBufferToLcd();
}

void LcdUI::runSelfTest() {
  Serial.println("[LCD] Running LCD_SELFTEST routine (exact 16-char validation):");

  char line1[17];
  char line2[17];

  // 1. Boot
  fmtLine("   P.U.L.S.E.   ", "", line1);
  fmtLine("Sensor Node v1.0", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 2. Connecting Wi-Fi
  fmtLine("Connecting Wi-Fi", "", line1);
  fmtLine("HomeNet_5G", " /", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 3. Setup / Captive portal
  fmtLine("Wi-Fi setup mode", "", line1);
  fmtLine("PULSE-Node-A1B2", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);
  fmtLine("Pass: pulse1234", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);
  fmtLine("Open 192.168.4.1", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 4. Pairing
  fmtLine("Pairing PIN", "118s", line1);
  fmtLine("  4 8 2  9 1 3  ", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 5. Page SOIL
  char dropStr[16];
  snprintf(dropStr, sizeof(dropStr), "%c Soil moist", GLYPH_DROP);
  fmtLine(dropStr, "46%", line1);
  char bar[11];
  _buildBar(46, bar);
  char barLine[17];
  snprintf(barLine, sizeof(barLine), "%s %5s", bar, "IDEAL");
  fmtLine(barLine, "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 6. Page LAST PHI (with PHI and without PHI)
  fmtLine("Last PHI", "66/100", line1);
  fmtLine("ENHANCE", "2h", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);
  fmtLine("Last PHI", "--", line1);
  fmtLine("Run assessment", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 7. Page LOCATION / TREND
  fmtLine("Community Garden", "", line1);
  char changeStr[17];
  snprintf(changeStr, sizeof(changeStr), "Change  58%c66 +8", GLYPH_UP);
  fmtLine(changeStr, "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 8. Page NETWORK
  char wifiStr[16];
  snprintf(wifiStr, sizeof(wifiStr), "%c Online", GLYPH_WIFI);
  fmtLine(wifiStr, "-58dBm", line1);
  fmtLine("192.168.1.42", "", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 9. Page SYSTEM
  fmtLine("App sync", "12s", line1);
  fmtLine("Up 03:42", "v1.0.0", line2);
  Serial.printf("|%s|\n|%s|\n\n", line1, line2);

  // 10. Alerts
  const char* alerts[6][2] = {
    {"! Soil too dry", "12%  Water today"},
    {"! Waterlogged", "88% Check drains"},
    {"! Sensor fault", "Check A0->GPIO34"},
    {"! Wi-Fi lost", "Reconnecting..."},
    {"! Calibrate node", "dry <= wet value"},
    {"Release to reset", "Resetting in 3s"}
  };
  for (int i = 0; i < 6; ++i) {
    fmtLine(alerts[i][0], "", line1);
    fmtLine(alerts[i][1], "", line2);
    Serial.printf("|%s|\n|%s|\n\n", line1, line2);
  }
}
