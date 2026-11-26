#pragma once
#include <Arduino.h>
#include "config.h"

struct DhtReadingData {
  float temperatureC;
  float humidityPct;
  float heatIndexC;
  bool sensorOk;
  uint32_t seq;
  uint32_t sampleTimeMs;
};

class DhtSensor {
public:
  void begin();
  void sample();
  const DhtReadingData& getLatest() const { return _current; }

private:
  DhtReadingData _current;
  int _badCount = 0;
  int _goodCount = 0;
};

extern DhtSensor Dht;
