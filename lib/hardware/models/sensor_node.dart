/// Model representing a paired ESP32 sensor node stored in local SQLite.
class SensorNode {
  final String deviceId;
  final String name;
  final String host;
  final int port;
  final String mode; // 'sta' or 'ap'
  final String? token;
  final String fw;
  final String? linkedLocationId;
  final String? linkedLocationName;
  final int? dryRaw;
  final int? wetRaw;
  final DateTime pairedAt;
  final DateTime? lastSeenAt;
  final bool isActive;

  const SensorNode({
    required this.deviceId,
    required this.name,
    required this.host,
    this.port = 80,
    this.mode = 'sta',
    this.token,
    required this.fw,
    this.linkedLocationId,
    this.linkedLocationName,
    this.dryRaw,
    this.wetRaw,
    required this.pairedAt,
    this.lastSeenAt,
    this.isActive = false,
  });

  SensorNode copyWith({
    String? deviceId,
    String? name,
    String? host,
    int? port,
    String? mode,
    String? token,
    String? fw,
    String? linkedLocationId,
    String? linkedLocationName,
    int? dryRaw,
    int? wetRaw,
    DateTime? pairedAt,
    DateTime? lastSeenAt,
    bool? isActive,
  }) {
    return SensorNode(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      mode: mode ?? this.mode,
      token: token ?? this.token,
      fw: fw ?? this.fw,
      linkedLocationId: linkedLocationId ?? this.linkedLocationId,
      linkedLocationName: linkedLocationName ?? this.linkedLocationName,
      dryRaw: dryRaw ?? this.dryRaw,
      wetRaw: wetRaw ?? this.wetRaw,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'name': name,
      'host': host,
      'port': port,
      'mode': mode,
      'token': token,
      'fw': fw,
      'linked_location_id': linkedLocationId,
      'linked_location_name': linkedLocationName,
      'dry_raw': dryRaw,
      'wet_raw': wetRaw,
      'paired_at': pairedAt.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory SensorNode.fromMap(Map<String, dynamic> map) {
    return SensorNode(
      deviceId: map['device_id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      port: (map['port'] as num?)?.toInt() ?? 80,
      mode: (map['mode'] as String?) ?? 'sta',
      token: map['token'] as String?,
      fw: (map['fw'] as String?) ?? '1.0.0',
      linkedLocationId: map['linked_location_id'] as String?,
      linkedLocationName: map['linked_location_name'] as String?,
      dryRaw: (map['dry_raw'] as num?)?.toInt(),
      wetRaw: (map['wet_raw'] as num?)?.toInt(),
      pairedAt: DateTime.tryParse(map['paired_at'] as String? ?? '') ?? DateTime.now(),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'] as String)
          : null,
      isActive: (map['is_active'] as num?)?.toInt() == 1,
    );
  }

  @override
  String toString() =>
      'SensorNode($deviceId, $name, $host:$port, mode: $mode, active: $isActive)';
}
