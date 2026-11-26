#include "soil_sensor.h"
#include "store.h"
#include <algorithm>

SoilSensor Soil;

static const char* kStatusCodes[] = {"DRY", "LOW", "OPTIMAL", "MOIST", "WET"};
static const char* kLcdLabels[]   = {"DRY", "LOW", "IDEAL", "MOIST", "WET"};

void SoilSensor::begin() {
  analogReadResolution(12);
  analogSetPinAttenuation(PIN_SOIL, ADC_11db);

  memset(&_current, 0, sizeof(_current));
  _current.sensorOk = true;
  _current.status = SOIL_OPTIMAL;
  _current.statusCode = kStatusCodes[SOIL_OPTIMAL];
  _current.lcdLabel = kLcdLabels[SOIL_OPTIMAL];
}

bool SoilSensor::isCalibrated() const {
  int dry = Store.getDryRaw();
  int wet = Store.getWetRaw();
  return (dry - wet) >= 500;
}

SoilStatusCode SoilSensor::_applyHysteresis(int pct, SoilStatusCode cur) {
  // Boundary definitions:
  // DRY: < 25
  // LOW: 25 - 39
  // OPTIMAL: 40 - 60
  // MOIST: 61 - 75
  // WET: > 75
  // 2-point hysteresis when transitioning
  switch (cur) {
    case SOIL_DRY:
      if (pct >= 27) return SOIL_LOW;
      return SOIL_DRY;
    case SOIL_LOW:
      if (pct < 23) return SOIL_DRY;
      if (pct >= 42) return SOIL_OPTIMAL;
      return SOIL_LOW;
    case SOIL_OPTIMAL:
      if (pct < 38) return SOIL_LOW;
      if (pct > 62) return SOIL_MOIST;
      return SOIL_OPTIMAL;
    case SOIL_MOIST:
      if (pct <= 58) return SOIL_OPTIMAL;
      if (pct >= 77) return SOIL_WET;
      return SOIL_MOIST;
    case SOIL_WET:
      if (pct <= 73) return SOIL_MOIST;
      return SOIL_WET;
  }
  return SOIL_OPTIMAL;
}

void SoilSensor::sample() {
  // 1. Burst read 12 samples 200us apart (~2.4ms non-blocking vs 32ms delay(1))
  int samples[12];
  for (int i = 0; i < 12; ++i) {
    samples[i] = analogRead(PIN_SOIL);
    delayMicroseconds(200);
  }

  // 2. Sort and trimmed mean (drop 2 lowest and 2 highest)
  std::sort(samples, samples + 12);
  long sum = 0;
  for (int i = 2; i < 10; ++i) {
    sum += samples[i];
  }
  int rawInstant = sum / 8;

  // 3. Fault detection: rawInstant > 4090 or < 50
  if (rawInstant > 4090 || rawInstant < 50) {
    _badCount++;
    _goodCount = 0;
    if (_badCount >= 10) {
      _current.sensorOk = false;
    }
  } else {
    _goodCount++;
    _badCount = 0;
    if (_goodCount >= 2) {
      _current.sensorOk = true;
    }
  }

  // 4. Adaptive fast EMA smoothing (alpha = 0.85 on large step jumps, 0.55 steady)
  bool wasFirst = _firstSample;
  if (_firstSample) {
    _emaRaw = rawInstant;
    _firstSample = false;
  } else {
    float delta = fabsf((float)rawInstant - _emaRaw);
    float alpha = (delta > 150.0f) ? 0.85f : 0.55f;
    _emaRaw = alpha * rawInstant + (1.0f - alpha) * _emaRaw;
  }
  int rawSmoothed = (int)round(_emaRaw);

  // 5. Percent calculation
  int dryRaw = Store.getDryRaw();
  int wetRaw = Store.getWetRaw();
  int pct = 0;
  if (dryRaw > wetRaw) {
    float calc = (float)(dryRaw - rawSmoothed) * 100.0f / (float)(dryRaw - wetRaw);
    pct = (int)round(calc);
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
  } else {
    // Calibration error
    pct = 0;
  }

  // 6. Ring buffer & fast stability (~2s window)
  _ringBuffer[_ringIndex] = pct;
  _ringIndex = (_ringIndex + 1) % RING_SIZE;
  if (_ringCount < RING_SIZE) _ringCount++;

  int minVal = _ringBuffer[0];
  int maxVal = _ringBuffer[0];
  for (int i = 1; i < _ringCount; ++i) {
    if (_ringBuffer[i] < minVal) minVal = _ringBuffer[i];
    if (_ringBuffer[i] > maxVal) maxVal = _ringBuffer[i];
  }
  bool stable = (_ringCount >= 4) && ((maxVal - minVal) <= 4);

  // 7. Status code with hysteresis
  SoilStatusCode newStatus;
  if (wasFirst) {
    if (pct < 25) newStatus = SOIL_DRY;
    else if (pct < 40) newStatus = SOIL_LOW;
    else if (pct <= 60) newStatus = SOIL_OPTIMAL;
    else if (pct <= 75) newStatus = SOIL_MOIST;
    else newStatus = SOIL_WET;
  } else {
    newStatus = _applyHysteresis(pct, _current.status);
  }

  // Update current record
  _current.rawInstant = rawInstant;
  _current.raw = rawSmoothed;
  _current.percent = pct;
  _current.status = newStatus;
  _current.statusCode = kStatusCodes[newStatus];
  _current.lcdLabel = kLcdLabels[newStatus];
  _current.stable = stable;
  _current.min30s = minVal;
  _current.max30s = maxVal;
  _current.seq++;
  _current.sampleTimeMs = millis();
}
