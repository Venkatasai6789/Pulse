#include "dht_sensor.h"
#include <DHT.h>

DhtSensor Dht;
static DHT _dht(PIN_DHT, DHT11);

void DhtSensor::begin() {
  memset(&_current, 0, sizeof(_current));
  _current.sensorOk = false;
  _dht.begin();
}

void DhtSensor::sample() {
  float h = _dht.readHumidity();
  float t = _dht.readTemperature(); // Celsius

  bool valid = !isnan(h) && !isnan(t) &&
               (t >= -10.0f && t <= 60.0f) &&
               (h >= 5.0f && h <= 100.0f);

  if (!valid) {
    _badCount++;
    _goodCount = 0;
    if (_badCount >= 3) {
      _current.sensorOk = false;
    }
    return;
  }

  _goodCount++;
  _badCount = 0;
  float hi = _dht.computeHeatIndex(t, h, false);

  _current.temperatureC = roundf(t * 10.0f) / 10.0f;
  _current.humidityPct = roundf(h * 10.0f) / 10.0f;
  _current.heatIndexC = roundf(hi * 10.0f) / 10.0f;
  _current.sensorOk = true;
  _current.seq++;
  _current.sampleTimeMs = millis();
}
