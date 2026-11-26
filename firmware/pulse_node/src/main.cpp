#include <Arduino.h>
#include "config.h"
#include "version.h"
#include "store.h"
#include "soil_sensor.h"
#include "button.h"
#include "lcd_ui.h"
#include "net.h"
#include "api.h"

static uint32_t lastSampleMs = 0;
static uint32_t lastLcdTickMs = 0;
static uint32_t lastBtnPollMs = 0;
static uint32_t lastSoilLogMs = 0;

void setup() {
  Serial.begin(115200);
  delay(100);

  Serial.println("\n==========================================");
  Serial.printf("[BOOT] P.U.L.S.E. Sensor Node v%s\n", FW_VERSION);
  Serial.println("==========================================");

  // Initialize NVS storage
  if (!Store.begin()) {
    Serial.println("[BOOT] ERROR: Failed to mount Preferences NVS");
  } else {
    Serial.println("[BOOT] NVS mounted successfully");
  }

  // Initialize LCD display first to show boot splash
  Lcd.begin();

  // Print LCD Self-Test output to serial for width/layout verification
  Lcd.runSelfTest();

  // Initialize Soil ADC sensor
  Soil.begin();

  // Initialize User Button
  Button.begin();

  // Initialize Networking & Captive portal
  Net.begin();

  // Initialize REST Web API
  Api.begin();

  Serial.println("[BOOT] Sensor Node initialized and running.");
}

void loop() {
  uint32_t now = millis();

  // 1. Cooperative WebServer handling (every pass)
  Api.loop();

  // 2. Cooperative Network state check (every pass)
  Net.loop();

  // 3. User Button polling (~20 ms)
  if (now - lastBtnPollMs >= BUTTON_POLL_MS) {
    lastBtnPollMs = now;
    ButtonEvent ev = Button.update();
    switch (ev) {
      case BTN_SHORT_PRESS:
        Serial.println("[BTN] Short press -> Next page");
        Lcd.nextRotationPage();
        break;
      case BTN_HOLD_2S:
        Serial.println("[BTN] Hold 2s -> Show Network page (15s)");
        Lcd.showNetworkOverride(15);
        break;
      case BTN_RESET_COUNTDOWN:
        Lcd.showResetCountdown(Button.getResetCountdownS());
        break;
      case BTN_RESET_CANCELLED:
        Serial.println("[BTN] Reset cancelled");
        Lcd.cancelResetCountdown();
        break;
      case BTN_RESET_TRIGGERED:
        Serial.println("[BTN] Factory reset triggered! Erasing settings and rebooting...");
        Store.factoryReset();
        WiFi.disconnect(true, true);
        delay(100);
        ESP.restart();
        break;
      case BTN_NONE:
      default:
        break;
    }
  }

  // 4. Soil Sampling (~2000 ms)
  if (now - lastSampleMs >= SAMPLE_INTERVAL_MS) {
    lastSampleMs = now;
    Soil.sample();

    // Check for sensor fault or extreme dry/wet alert triggers
    const auto& s = Soil.getLatest();
    if (!s.sensorOk) {
      Lcd.triggerAlert(ALERT_FAULT);
    } else if (s.status == SOIL_DRY) {
      Lcd.triggerAlert(ALERT_DRY);
    } else if (s.status == SOIL_WET) {
      Lcd.triggerAlert(ALERT_WET);
    }
  }

  // 5. Periodic Soil Serial Log (~10 s)
  if (now - lastSoilLogMs >= 10000) {
    lastSoilLogMs = now;
    const auto& s = Soil.getLatest();
    Serial.printf("[SOIL] raw=%d pct=%d status=%s stable=%d ok=%d\n",
                  s.raw, s.percent, s.statusCode, s.stable ? 1 : 0, s.sensorOk ? 1 : 0);
  }

  // 6. LCD Tick (~250 ms)
  if (now - lastLcdTickMs >= LCD_TICK_MS) {
    lastLcdTickMs = now;
    Lcd.tick();
  }
}
