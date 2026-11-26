import 'package:flutter/foundation.dart';
import '../data/local_db.dart';
import 'models/sensor_node.dart';

/// Repository for persisting paired hardware sensor nodes in local SQLite.
class SensorNodeRepository {
  final LocalDb _db;

  SensorNodeRepository({LocalDb? db}) : _db = db ?? LocalDb.instance;

  /// Retrieves all paired sensor nodes.
  Future<List<SensorNode>> getAllNodes() async {
    try {
      final rows = await _db.queryAllNodes();
      return rows.map(SensorNode.fromMap).toList();
    } catch (e) {
      debugPrint('[SensorNodeRepository] getAllNodes error: $e');
      return [];
    }
  }

  /// Retrieves the currently active node, if any.
  Future<SensorNode?> getActiveNode() async {
    final all = await getAllNodes();
    try {
      return all.firstWhere((n) => n.isActive);
    } catch (_) {
      return all.isNotEmpty ? all.first : null;
    }
  }

  /// Retrieves a node by its device ID.
  Future<SensorNode?> getNode(String deviceId) async {
    try {
      final row = await _db.queryNodeById(deviceId);
      return row != null ? SensorNode.fromMap(row) : null;
    } catch (e) {
      debugPrint('[SensorNodeRepository] getNode error: $e');
      return null;
    }
  }

  /// Retrieves a node linked to a specific location ID.
  Future<SensorNode?> getNodeForLocation(String locationId) async {
    final all = await getAllNodes();
    try {
      return all.firstWhere((n) => n.linkedLocationId == locationId);
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates a sensor node in SQLite.
  Future<void> saveNode(SensorNode node) async {
    try {
      await _db.upsertNode(node.toMap());
    } catch (e) {
      debugPrint('[SensorNodeRepository] saveNode error: $e');
    }
  }

  /// Sets a specific node as active and all others inactive.
  Future<void> setActive(String deviceId) async {
    try {
      await _db.setNodeActive(deviceId);
    } catch (e) {
      debugPrint('[SensorNodeRepository] setActive error: $e');
    }
  }

  /// Updates the last seen timestamp of a node.
  Future<void> updateLastSeen(String deviceId, DateTime seenAt) async {
    try {
      await _db.updateNodeLastSeen(deviceId, seenAt.toIso8601String());
    } catch (e) {
      debugPrint('[SensorNodeRepository] updateLastSeen error: $e');
    }
  }

  /// Deletes a sensor node.
  Future<void> deleteNode(String deviceId) async {
    try {
      await _db.deleteNodeById(deviceId);
    } catch (e) {
      debugPrint('[SensorNodeRepository] deleteNode error: $e');
    }
  }
}
