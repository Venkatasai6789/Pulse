/// Connection state machine values for a hardware sensor node.
enum NodeConnection {
  /// No sensor node has been paired with this app yet.
  notPaired,

  /// Actively probing/connecting to the paired node.
  searching,

  /// Node is connected and delivering fresh readings.
  online,

  /// Connected, but sequence number has not advanced within 15 seconds.
  stale,

  /// Unreachable after multiple consecutive poll failures.
  offline,

  /// Node reachable, but hardware sensor reports a fault (sensorOk == false).
  fault,

  /// Node returned HTTP 401 Unauthorized (token invalid / expired).
  unauthorized,
}
