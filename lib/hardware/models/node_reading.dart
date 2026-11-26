import '../../core/soil.dart';
import '../../core/soil_reading.dart';

/// Parsed data model from the node's `GET /api/reading` endpoint.
class NodeReading {
  final int seq;
  final int sampleAgeMs;
  final int uptimeS;
  final NodeSoilData soil;
  final NodeNetData net;
  final NodeLastPhiData? lastPhi;
  final DateTime receivedAt;

  NodeReading({
    required this.seq,
    required this.sampleAgeMs,
    required this.uptimeS,
    required this.soil,
    required this.net,
    this.lastPhi,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Reading is fresh if sample age on node is under 10 seconds.
  bool get isFresh => sampleAgeMs < 10000;

  /// Sensor is healthy and producing valid analog reads.
  bool get isSensorOk => soil.sensorOk;

  /// Converts this reading into a core [SoilReading] model for assessment input.
  SoilReading toSoilReading({
    required String deviceId,
    required String firmware,
    double? lat,
    double? lng,
  }) {
    return SoilReading(
      percent: soil.percent,
      raw: soil.raw,
      status: soil.status,
      source: SoilSource.esp32,
      deviceId: deviceId,
      firmware: firmware,
      stable: soil.stable,
      capturedAt: receivedAt,
      capturedLat: lat,
      capturedLng: lng,
    );
  }

  factory NodeReading.fromJson(Map<String, dynamic> json) {
    return NodeReading(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      sampleAgeMs: (json['sampleAgeMs'] as num?)?.toInt() ?? 0,
      uptimeS: (json['uptimeS'] as num?)?.toInt() ?? 0,
      soil: NodeSoilData.fromJson(
        json['soil'] is Map<String, dynamic> ? json['soil'] as Map<String, dynamic> : {},
      ),
      net: NodeNetData.fromJson(
        json['net'] is Map<String, dynamic> ? json['net'] as Map<String, dynamic> : {},
      ),
      lastPhi: json['lastPhi'] is Map<String, dynamic>
          ? NodeLastPhiData.fromJson(json['lastPhi'] as Map<String, dynamic>)
          : null,
      receivedAt: DateTime.now(),
    );
  }
}

class NodeSoilData {
  final double percent;
  final int raw;
  final SoilStatus status;
  final bool stable;
  final bool sensorOk;

  const NodeSoilData({
    required this.percent,
    required this.raw,
    required this.status,
    required this.stable,
    required this.sensorOk,
  });

  factory NodeSoilData.fromJson(Map<String, dynamic> json) {
    final rawVal = (json['raw'] as num?)?.toInt() ?? 0;
    final pctVal = (json['percent'] as num?)?.toDouble() ?? 0.0;
    final statusStr = (json['status'] as String?)?.toUpperCase() ?? '';

    SoilStatus parsedStatus;
    switch (statusStr) {
      case 'DRY':
        parsedStatus = SoilStatus.dry;
        break;
      case 'LOW':
        parsedStatus = SoilStatus.low;
        break;
      case 'OPTIMAL':
        parsedStatus = SoilStatus.optimal;
        break;
      case 'MOIST':
        parsedStatus = SoilStatus.moist;
        break;
      case 'WET':
        parsedStatus = SoilStatus.wet;
        break;
      default:
        parsedStatus = soilStatusFor(pctVal);
    }

    return NodeSoilData(
      percent: pctVal,
      raw: rawVal,
      status: parsedStatus,
      stable: json['stable'] as bool? ?? false,
      sensorOk: json['sensorOk'] as bool? ?? true,
    );
  }
}

class NodeNetData {
  final String mode;
  final String? ssid;
  final int? rssi;
  final String? ip;

  const NodeNetData({
    required this.mode,
    this.ssid,
    this.rssi,
    this.ip,
  });

  factory NodeNetData.fromJson(Map<String, dynamic> json) {
    return NodeNetData(
      mode: (json['mode'] as String?) ?? 'STA',
      ssid: json['ssid'] as String?,
      rssi: (json['rssi'] as num?)?.toInt(),
      ip: json['ip'] as String?,
    );
  }
}

class NodeLastPhiData {
  final double phi;
  final String tier;
  final String? locationName;
  final int? ts;

  const NodeLastPhiData({
    required this.phi,
    required this.tier,
    this.locationName,
    this.ts,
  });

  factory NodeLastPhiData.fromJson(Map<String, dynamic> json) {
    return NodeLastPhiData(
      phi: (json['phi'] as num?)?.toDouble() ?? 0.0,
      tier: (json['tier'] as String?) ?? 'UNKNOWN',
      locationName: json['locationName'] as String?,
      ts: (json['ts'] as num?)?.toInt(),
    );
  }
}
