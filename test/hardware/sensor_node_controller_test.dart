import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse/data/local_db.dart';
import 'package:pulse/hardware/models/node_connection.dart';
import 'package:pulse/hardware/models/sensor_node.dart';
import 'package:pulse/hardware/sensor_node_client.dart';
import 'package:pulse/hardware/sensor_node_controller.dart';
import 'package:pulse/hardware/sensor_node_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalDb.instance.inMemoryStorage = <String, String>{};
    LocalDb.instance.clearInMemory();
  });

  tearDown(() {
    LocalDb.instance.clearInMemory();
    LocalDb.instance.inMemoryStorage = null;
  });

  group('SensorNodeController State Machine and Polling', () {
    test('transitions through searching, online, fault, offline', () async {
      int seqCounter = 1;
      bool returnFault = false;
      bool simulateOffline = false;

      final mockClient = MockClient((request) async {
        if (simulateOffline) {
          throw const NodeErrorUnreachable();
        }
        final json = {
          'seq': seqCounter++,
          'sampleAgeMs': 100,
          'uptimeS': 500,
          'soil': {
            'percent': 45.0,
            'raw': 2100,
            'status': 'OPTIMAL',
            'stable': true,
            'sensorOk': !returnFault,
          },
          'net': {
            'mode': 'STA',
            'ssid': 'Wifi',
            'rssi': -60,
            'ip': '192.168.1.100',
          },
        };
        return http.Response(jsonEncode(json), 200);
      });

      final repo = SensorNodeRepository();
      // Pre-save active node
      final initialNode = SensorNode(
        deviceId: 'TEST-DEV-1',
        name: 'Test Node',
        host: '192.168.1.100',
        port: 80,
        fw: '1.0.0',
        pairedAt: DateTime.now(),
        isActive: true,
      );
      await repo.saveNode(initialNode);

      final controller = SensorNodeController(
        repo: repo,
        client: SensorNodeClient(client: mockClient),
      );

      // Await init
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state, NodeConnection.searching);

      // Acquire subscriber to trigger poll
      controller.acquire();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state, NodeConnection.online);
      expect(controller.latest?.soil.percent, 45.0);

      // Verify capture() succeeds when fresh & healthy
      final reading = await controller.capture();
      expect(reading, isNotNull);
      expect(reading?.percent, 45.0);
      expect(reading?.deviceId, 'TEST-DEV-1');

      // Simulate fault: sensorOk = false
      returnFault = true;
      await controller.refresh();
      expect(controller.state, NodeConnection.fault);
      // capture() refuses when in fault state
      expect(await controller.capture(), isNull);

      // Reset fault back to healthy
      returnFault = false;
      await controller.refresh();
      expect(controller.state, NodeConnection.online);

      // Simulate 3 consecutive failures -> offline
      simulateOffline = true;
      await controller.refresh();
      await controller.refresh();
      await controller.refresh();
      expect(controller.state, NodeConnection.offline);
      expect(await controller.capture(), isNull);

      // Recovery back to online
      simulateOffline = false;
      await controller.refresh();
      expect(controller.state, NodeConnection.online);

      // Release subscriber
      controller.release();
      controller.dispose();
    });

    test('unpair transitions state to notPaired', () async {
      final repo = SensorNodeRepository();
      final node = SensorNode(
        deviceId: 'DEV-99',
        name: 'Node 99',
        host: '192.168.1.99',
        port: 80,
        fw: '1.0.0',
        pairedAt: DateTime.now(),
        isActive: true,
      );
      await repo.saveNode(node);

      final dummyMock = MockClient((r) async => http.Response('{}', 200));
      final controller = SensorNodeController(
        repo: repo,
        client: SensorNodeClient(client: dummyMock),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state, NodeConnection.searching);

      await controller.unpair();
      expect(controller.state, NodeConnection.notPaired);
      expect(controller.node, isNull);
      expect(await repo.getActiveNode(), isNull);

      controller.dispose();
    });
  });
}
