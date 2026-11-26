#pragma once
#include <Arduino.h>
#include "config.h"

enum SoilStatusCode {
  SOIL_DRY,
  SOIL_LOW,
  SOIL_OPTIMAL,
  SOIL_MOIST,
  SOIL_WET
};

struct SoilReadingData {
  int rawInstant;
  int raw;            // EMA smoothed
  int percent;        // 0-100
  SoilStatusCode status;
  const char* statusCode; // "DRY", "LOW", "OPTIMAL", "MOIST", "WET"
  const char* lcdLabel;   // "DRY", "LOW", "IDEAL", "MOIST", "WET"
  bool sensorOk;
  bool stable;
  int min30s;
  int max30s;
  uint32_t seq;
  uint32_t sampleTimeMs;
};

class SoilSensor {
public:
  void begin();
  void sample();
  const SoilReadingData& getLatest() const { return _current; }
  bool isCalibrated() const;

private:
  SoilReadingData _current;
  bool _firstSample = true;
  float _emaRaw = 0.0f;
  
  // Ring buffer for ~3.2s stability (8 samples @ 400ms)
  static const int RING_SIZE = 8;
  int _ringBuffer[RING_SIZE];
  int _ringIndex = 0;
  int _ringCount = 0;

  // Fault detection counters
  int _badCount = 0;
  int _goodCount = 0;

  SoilStatusCode _applyHysteresis(int pct, SoilStatusCode currentStatus);
};

extern SoilSensor Soil;
