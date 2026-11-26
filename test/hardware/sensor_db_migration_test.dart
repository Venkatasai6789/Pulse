import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pulse/data/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite DB Migration v1 -> v2', () {
    test('preserves app_settings and Gemini key while adding sensor_nodes table', () async {
      final tempDir = Directory.systemTemp.createTempSync('pulse_mig_test_');
      final dbPath = p.join(tempDir.path, 'migration_test.db');

      try {
        // 1. Open database at v1 and insert Gemini API key
        var db = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        );

        await db.insert('app_settings', {
          'key': LocalDb.keyGeminiApiKey,
          'value': 'AIzaSyTestKey-Migration-Check',
          'updated_at': DateTime.now().toIso8601String(),
        });

        await db.close();

        // 2. Open database at v2 with upgrade hook
        db = await openDatabase(
          dbPath,
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await LocalDb.createSensorNodesTable(db);
            }
          },
        );

        // 3. Assert app_settings still contains the exact Gemini key
        final settingsRows = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: [LocalDb.keyGeminiApiKey],
        );
        expect(settingsRows.length, 1);
        expect(settingsRows.first['value'], 'AIzaSyTestKey-Migration-Check');

        // 4. Assert sensor_nodes table exists and accepts insertion
        await db.insert('sensor_nodes', {
          'device_id': 'MIG-NODE-01',
          'name': 'Migrated Garden Node',
          'host': '192.168.1.111',
          'port': 80,
          'mode': 'sta',
          'token': 'mig-token-xyz',
          'fw': '1.0.0',
          'linked_location_id': 'loc-garden',
          'linked_location_name': 'Community Garden',
          'dry_raw': 3200,
          'wet_raw': 1500,
          'paired_at': DateTime.now().toIso8601String(),
          'last_seen_at': null,
          'is_active': 1,
        });

        final nodeRows = await db.query(
          'sensor_nodes',
          where: 'device_id = ?',
          whereArgs: ['MIG-NODE-01'],
        );
        expect(nodeRows.length, 1);
        expect(nodeRows.first['name'], 'Migrated Garden Node');
        expect(nodeRows.first['linked_location_id'], 'loc-garden');

        await db.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
