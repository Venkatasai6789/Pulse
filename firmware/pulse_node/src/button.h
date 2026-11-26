#pragma once
#include <Arduino.h>
#include "config.h"

enum ButtonEvent {
  BTN_NONE,
  BTN_SHORT_PRESS,
  BTN_HOLD_2S,
  BTN_RESET_COUNTDOWN,
  BTN_RESET_CANCELLED,
  BTN_RESET_TRIGGERED
};

class UserButton {
public:
  void begin();
  ButtonEvent update(); // Call every ~20ms
  int getResetCountdownS() const { return _resetCountdownS; }

private:
  int _lastState = HIGH;
  uint32_t _pressStartMs = 0;
  bool _isPressed = false;
  bool _hold2sFired = false;
  bool _resetCountdownActive = false;
  int _resetCountdownS = 3;
};

extern UserButton Button;
