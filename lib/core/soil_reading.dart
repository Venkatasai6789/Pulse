/// Soil reading payload captured from an ESP32 node or entered manually.
library;

import 'soil.dart';

enum SoilSource { esp32, manual }

class SoilReading {
  final double percent; // 0–100
  final int? raw; // 0–4095, null for manual
  final SoilStatus status;
  final SoilSource source; // esp32 | manual
  final String? deviceId;
  final String? firmware;
  final bool stable; // from firmware; manual = true
  final DateTime capturedAt;
  final double? capturedLat; // phone GPS at capture (nullable)
  final double? capturedLng;

  const SoilReading({
    required this.percent,
    this.raw,
    required this.status,
    required this.source,
    this.deviceId,
    this.firmware,
    this.stable = true,
    required this.capturedAt,
    this.capturedLat,
    this.capturedLng,
  });

  Map<String, dynamic> toJson() => {
        'percent': percent,
        if (raw != null) 'raw': raw,
        'status': soilStatusCode(status),
        'source': source.name,
        if (deviceId != null) 'deviceId': deviceId,
        if (firmware != null) 'firmware': firmware,
        'stable': stable,
        'capturedAt': capturedAt.toIso8601String(),
        if (capturedLat != null) 'capturedLat': capturedLat,
        if (capturedLng != null) 'capturedLng': capturedLng,
      };

  factory SoilReading.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return SoilReading(
        percent: 0.0,
        status: SoilStatus.optimal,
        source: SoilSource.manual,
        capturedAt: DateTime.now(),
      );
    }

    final p = (j['percent'] as num?)?.toDouble() ?? 0.0;
    final statusStr = j['status'] as String?;
    final status = soilStatusFromCode(statusStr) ?? soilStatusFor(p);

    SoilSource src = SoilSource.manual;
    final srcStr = j['source'] as String?;
    if (srcStr == 'esp32') {
      src = SoilSource.esp32;
    }

    DateTime capAt = DateTime.now();
    final capStr = j['capturedAt'];
    if (capStr is String) {
      capAt = DateTime.tryParse(capStr) ?? DateTime.now();
    }

    return SoilReading(
      percent: p,
      raw: (j['raw'] as num?)?.toInt(),
      status: status,
      source: src,
      deviceId: j['deviceId'] as String?,
      firmware: j['firmware'] as String?,
      stable: (j['stable'] as bool?) ?? true,
      capturedAt: capAt,
      capturedLat: (j['capturedLat'] as num?)?.toDouble(),
      capturedLng: (j['capturedLng'] as num?)?.toDouble(),
    );
  }

  SoilReading copyWith({
    double? percent,
    int? raw,
    SoilStatus? status,
    SoilSource? source,
    String? deviceId,
    String? firmware,
    bool? stable,
    DateTime? capturedAt,
    double? capturedLat,
    double? capturedLng,
  }) =>
      SoilReading(
        percent: percent ?? this.percent,
        raw: raw ?? this.raw,
        status: status ?? this.status,
        source: source ?? this.source,
        deviceId: deviceId ?? this.deviceId,
        firmware: firmware ?? this.firmware,
        stable: stable ?? this.stable,
        capturedAt: capturedAt ?? this.capturedAt,
        capturedLat: capturedLat ?? this.capturedLat,
        capturedLng: capturedLng ?? this.capturedLng,
      );
}
