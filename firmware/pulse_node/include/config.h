#pragma once
#include <Arduino.h>

// -----------------------------------------------------------------------------
// Pin Definitions
// -----------------------------------------------------------------------------
#define PIN_SOIL 34       // ADC1_CH6, input only, Wi-Fi safe
#define PIN_DHT  32       // Non-strapping bidirectional GPIO, safe for DHT11 1-wire
#define DHT_TYPE 11       // DHT11 sensor model
#define PIN_SDA  21       // I2C Data
#define PIN_SCL  22       // I2C Clock
#define PIN_BTN  0        // BOOT button

// -----------------------------------------------------------------------------
// LCD Display Configuration
// -----------------------------------------------------------------------------
#define LCD_COLS 16
#define LCD_ROWS 2
#define LCD_I2C_ADDR_DEFAULT 0x27

// -----------------------------------------------------------------------------
// Timing Constants (milliseconds / seconds)
// -----------------------------------------------------------------------------
#define SAMPLE_INTERVAL_MS   400
#define DHT_INTERVAL_MS      2000
#define PAGE_MS              4000
#define LCD_TICK_MS          250
#define WIFI_CHECK_MS        5000
#define BUTTON_POLL_MS       20

#define PAIR_PIN_TTL_S       120
#define PAIR_LOCKOUT_S       60
#define STALE_APP_SYNC_S     120
#define BACKLIGHT_TIMEOUT_MIN 0    // 0 = always on
#define NTP_OFFSET_S         19800 // IST (UTC + 5:30)

// -----------------------------------------------------------------------------
// Soil Calibration Defaults
// -----------------------------------------------------------------------------
#define DEFAULT_DRY_RAW 4095
#define DEFAULT_WET_RAW 1500

// -----------------------------------------------------------------------------
// SoftAP Settings
// -----------------------------------------------------------------------------
#define AP_PASSWORD "pulse1234"
