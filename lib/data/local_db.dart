import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite database helper to persist mobile application settings (e.g. Gemini API Key)
/// and paired hardware sensor nodes.
class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  static const String _dbName = 'pulse_local.db';
  static const int _dbVersion = 2;
  static const String _tableName = 'app_settings';
  static const String sensorNodesTable = 'sensor_nodes';

  static const String keyGeminiApiKey = 'gemini_api_key';

  Database? _database;

  /// Optional in-memory cache / test override to avoid native SQLite bindings during tests.
  @visibleForTesting
  Map<String, String>? inMemoryStorage;

  final Map<String, Map<String, dynamic>> _inMemoryNodes = {};

  bool get isInMemory => inMemoryStorage != null;

  @visibleForTesting
  void clearInMemory() {
    inMemoryStorage?.clear();
    _inMemoryNodes.clear();
  }

  /// Returns the open SQLite database instance, creating and initializing it if necessary.
  Future<Database?> get database async {
    if (inMemoryStorage != null) {
      return null;
    }
    if (_database != null) {
      return _database!;
    }
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      debugPrint('[LocalDb] Failed to initialize SQLite database: $e. Falling back to in-memory store.');
      inMemoryStorage ??= <String, String>{};
      return null;
    }
  }

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await createSensorNodesTable(db);
  }

  static Future<void> createSensorNodesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $sensorNodesTable (
        device_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        mode TEXT NOT NULL,
        token TEXT,
        fw TEXT NOT NULL,
        linked_location_id TEXT,
        linked_location_name TEXT,
        dry_raw INTEGER,
        wet_raw INTEGER,
        paired_at TEXT NOT NULL,
        last_seen_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<Database> _initDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, _dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await createSensorNodesTable(db);
        }
      },
    );
  }

  /// Saves a setting value in SQLite by [key].
  Future<void> setSetting(String key, String value) async {
    if (inMemoryStorage != null) {
      inMemoryStorage![key] = value;
      return;
    }

    try {
      final db = await database;
      if (db == null) {
        inMemoryStorage ??= <String, String>{};
        inMemoryStorage![key] = value;
        return;
      }

      final now = DateTime.now().toIso8601String();
      await db.insert(
        _tableName,
        {
          'key': key,
          'value': value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDb] Error in setSetting: $e');
      inMemoryStorage ??= <String, String>{};
      inMemoryStorage![key] = value;
    }
  }

  /// Retrieves a setting value from SQLite by [key].
  Future<String?> getSetting(String key) async {
    if (inMemoryStorage != null) {
      return inMemoryStorage![key];
    }

    try {
      final db = await database;
      if (db == null) {
        return inMemoryStorage?[key];
      }

      final rows = await db.query(
        _tableName,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return rows.first['value'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[LocalDb] Error in getSetting: $e');
      return inMemoryStorage?[key];
    }
  }

  /// Removes a setting from SQLite by [key].
  Future<void> deleteSetting(String key) async {
    if (inMemoryStorage != null) {
      inMemoryStorage!.remove(key);
      return;
    }

    try {
      final db = await database;
      if (db == null) {
        inMemoryStorage?.remove(key);
        return;
      }

      await db.delete(
        _tableName,
        where: 'key = ?',
        whereArgs: [key],
      );
    } catch (e) {
      debugPrint('[LocalDb] Error in deleteSetting: $e');
      inMemoryStorage?.remove(key);
    }
  }

  /// Stores the Gemini API key in local SQLite.
  Future<void> saveGeminiApiKey(String apiKey) async {
    await setSetting(keyGeminiApiKey, apiKey.trim());
  }

  /// Retrieves the Gemini API key from local SQLite, falling back to compile-time GEMINI_API_KEY.
  Future<String?> getGeminiApiKey() async {
    final key = await getSetting(keyGeminiApiKey);
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    const compileKey = String.fromEnvironment('GEMINI_API_KEY');
    if (compileKey.trim().isNotEmpty) {
      return compileKey.trim();
    }
    return null;
  }

  /// Deletes the Gemini API key from local SQLite.
  Future<void> deleteGeminiApiKey() async {
    await deleteSetting(keyGeminiApiKey);
  }

  /// Checks if a Gemini API key is stored.
  Future<bool> hasGeminiApiKey() async {
    final key = await getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Sensor Nodes Helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> queryAllNodes() async {
    if (isInMemory) {
      return _inMemoryNodes.values.toList();
    }
    final db = await database;
    if (db == null) return [];
    return db.query(sensorNodesTable, orderBy: 'paired_at DESC');
  }

  Future<Map<String, dynamic>?> queryNodeById(String deviceId) async {
    if (isInMemory) {
      return _inMemoryNodes[deviceId];
    }
    final db = await database;
    if (db == null) return null;
    final rows = await db.query(
      sensorNodesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> upsertNode(Map<String, dynamic> nodeMap) async {
    final deviceId = nodeMap['device_id'] as String;
    final isActive = (nodeMap['is_active'] as num?)?.toInt() == 1;

    if (isInMemory) {
      if (isActive) {
        for (final k in _inMemoryNodes.keys) {
          _inMemoryNodes[k]!['is_active'] = 0;
        }
      }
      _inMemoryNodes[deviceId] = Map<String, dynamic>.from(nodeMap);
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.transaction((txn) async {
      if (isActive) {
        await txn.update(sensorNodesTable, {'is_active': 0});
      }
      await txn.insert(
        sensorNodesTable,
        nodeMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> setNodeActive(String deviceId) async {
    if (isInMemory) {
      for (final k in _inMemoryNodes.keys) {
        _inMemoryNodes[k]!['is_active'] = (k == deviceId) ? 1 : 0;
      }
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.transaction((txn) async {
      await txn.update(sensorNodesTable, {'is_active': 0});
      await txn.update(
        sensorNodesTable,
        {'is_active': 1},
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    });
  }

  Future<void> updateNodeLastSeen(String deviceId, String seenAt) async {
    if (isInMemory) {
      final map = _inMemoryNodes[deviceId];
      if (map != null) {
        map['last_seen_at'] = seenAt;
      }
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.update(
      sensorNodesTable,
      {'last_seen_at': seenAt},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> deleteNodeById(String deviceId) async {
    if (isInMemory) {
      _inMemoryNodes.remove(deviceId);
      return;
    }

    final db = await database;
    if (db == null) return;

    await db.delete(
      sensorNodesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }
}
