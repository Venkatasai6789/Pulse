#pragma once
#include <Arduino.h>
#include <WebServer.h>

class NodeApi {
public:
  void begin();
  void loop(); // Call in loop()

private:
  WebServer _server{80};

  // Pair state
  char _activePin[7];
  uint32_t _pinGeneratedMs = 0;
  bool _pinActive = false;
  int _failedAttempts = 0;
  uint32_t _lockoutUntilMs = 0;

  bool _checkAuth();
  void _sendJson(int code, const String& json);
  void _sendError(int code, const char* err, const char* msg);

  // Handlers
  void _handleHealth();
  void _handleInfo();
  void _handleReading();
  void _handlePairStart();
  void _handlePairConfirm();
  void _handleCalibrate();
  void _handleDisplay();
  void _handleConfig();
  void _handleIdentify();
};

extern NodeApi Api;
extern uint32_t gLastAppSyncMs;
