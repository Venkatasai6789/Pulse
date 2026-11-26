#include "button.h"

UserButton Button;

void UserButton::begin() {
  pinMode(PIN_BTN, INPUT_PULLUP);
  _lastState = digitalRead(PIN_BTN);
}

ButtonEvent UserButton::update() {
  int reading = digitalRead(PIN_BTN);
  uint32_t now = millis();
  ButtonEvent event = BTN_NONE;

  if (reading == LOW && _lastState == HIGH) {
    // Just pressed
    _pressStartMs = now;
    _isPressed = true;
    _hold2sFired = false;
    _resetCountdownActive = false;
    _resetCountdownS = 3;
  } else if (reading == LOW && _isPressed) {
    // Still held
    uint32_t heldMs = now - _pressStartMs;
    if (heldMs >= 5000) {
      _resetCountdownActive = true;
      uint32_t countMs = heldMs - 5000;
      int secLeft = 3 - (countMs / 1000);
      if (secLeft <= 0) {
        event = BTN_RESET_TRIGGERED;
        _isPressed = false;
        _resetCountdownActive = false;
      } else {
        _resetCountdownS = secLeft;
        event = BTN_RESET_COUNTDOWN;
      }
    } else if (heldMs >= 2000 && !_hold2sFired) {
      _hold2sFired = true;
      event = BTN_HOLD_2S;
    }
  } else if (reading == HIGH && _lastState == LOW) {
    // Just released
    if (_resetCountdownActive) {
      event = BTN_RESET_CANCELLED;
      _resetCountdownActive = false;
    } else if (_isPressed) {
      uint32_t heldMs = now - _pressStartMs;
      if (heldMs < 1500) {
        event = BTN_SHORT_PRESS;
      }
    }
    _isPressed = false;
  }

  _lastState = reading;
  return event;
}
