#pragma once
#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include "config.h"

enum LcdPage {
  PAGE_BOOT,
  PAGE_CONNECTING,
  PAGE_PORTAL,
  PAGE_PAIRING,
  PAGE_SOIL,
  PAGE_LAST_PHI,
  PAGE_LOCATION,
  PAGE_NETWORK,
  PAGE_SYSTEM,
  PAGE_ALERT
};

enum LcdAlert {
  ALERT_NONE,
  ALERT_DRY,
  ALERT_WET,
  ALERT_FAULT,
  ALERT_WIFI_LOST,
  ALERT_CALIBRATION,
  ALERT_RESET
};

class LcdUI {
public:
  void begin();
  void tick(); // Called every 250 ms
  
  // Page / State controls
  void showBoot();
  void showConnecting(const char* ssid);
  void showPortal(const char* apSsid, const char* apPass, const char* ip);
  void showPairing(const char* pin, int ttlSeconds);
  void cancelPairing();
  void nextRotationPage();
  void showNetworkOverride(int durationS = 15);
  void showResetCountdown(int secondsLeft);
  void cancelResetCountdown();

  void triggerAlert(LcdAlert alert);
  void identifyFlash();

  // Self-test
  void runSelfTest();

  // Line formatting helper
  static void fmtLine(const char* left, const char* right, char* outLine, int cols = LCD_COLS);

private:
  LiquidCrystal_I2C* _lcd = nullptr;
  uint8_t _i2cAddr = LCD_I2C_ADDR_DEFAULT;

  char _buf[LCD_ROWS][LCD_COLS + 1];
  char _shadow[LCD_ROWS][LCD_COLS + 1];
  bool _initialized = false;

  LcdPage _currentPage = PAGE_BOOT;
  LcdPage _lastRotationPage = PAGE_SYSTEM;
  bool _rotationToggleSoil = false; // Alternates SOIL with other pages
  uint32_t _pageSwitchMs = 0;

  // Overrides & Alerts
  uint32_t _overrideUntilMs = 0;
  bool _inNetworkOverride = false;
  LcdAlert _activeAlert = ALERT_NONE;
  uint32_t _alertUntilMs = 0;

  // Pairing state
  char _pairPin[8];
  int _pairTtlS = 0;
  uint32_t _pairStartMs = 0;

  // Portal rotation
  int _portalSubStep = 0;
  uint32_t _portalRotateMs = 0;
  char _portalSsid[20];
  char _portalPass[20];
  char _portalIp[20];

  // Connecting spinner
  char _connectingSsid[20];
  int _spinnerIdx = 0;

  // Reset countdown
  int _resetCountdownS = 3;
  bool _inResetCountdown = false;

  void _detectI2C();
  void _loadCustomGlyphs();
  void _renderCurrentPage();
  void _flushBufferToLcd();
  void _buildBar(int percent, char* out10);
  void _formatAge(uint32_t ts, char* outAge, size_t maxLen);
  void _formatUptime(uint32_t uptimeS, char* outUp, size_t maxLen);
};

extern LcdUI Lcd;
