import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pulse/data/local_db.dart';
import 'package:pulse/hardware/models/sensor_node.dart';
import 'package:pulse/hardware/sensor_node_client.dart';
import 'package:pulse/hardware/sensor_node_controller.dart';
import 'package:pulse/hardware/sensor_node_repository.dart';
import 'package:pulse/widgets/sensor/sensor_status_button.dart';

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

  group('SensorStatusButton Widget Tests', () {
    testWidgets('is hidden (renders SizedBox.shrink) when not paired', (tester) async {
      final repo = SensorNodeRepository();
      final controller = SensorNodeController(
        repo: repo,
        client: SensorNodeClient(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SensorNodeController>.value(
              value: controller,
              child: const SensorStatusButton(),
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.sensors_rounded), findsNothing);

      controller.dispose();
    });

    testWidgets('renders sensor icon with status indicator when paired', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'seq': 1,
            'sampleAgeMs': 100,
            'uptimeS': 100,
            'soil': {
              'percent': 46.0,
              'raw': 2150,
              'status': 'OPTIMAL',
              'stable': true,
              'sensorOk': true,
            },
            'net': {'mode': 'STA', 'ssid': 'Wifi', 'rssi': -60, 'ip': '192.168.1.55'},
            'sys': {'heap': 150000, 'cpuFreqMHz': 240, 'vccMv': 3300},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = SensorNodeRepository();
      await repo.saveNode(
        SensorNode(
          deviceId: 'ESP32_A1B2',
          host: '192.168.1.55',
          port: 80,
          name: 'PULSE-Node-A1B2',
          fw: '1.0.0',
          token: 'token123',
          dryRaw: 4000,
          wetRaw: 1600,
          pairedAt: DateTime.now(),
          isActive: true,
        ),
      );

      final controller = SensorNodeController(
        repo: repo,
        client: SensorNodeClient(client: mockClient),
      );

      await tester.pump(const Duration(milliseconds: 50));
      controller.acquire();
      await tester.pump(const Duration(milliseconds: 50));
      await controller.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SensorNodeController>.value(
              value: controller,
              child: const SensorStatusButton(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sensors_rounded), findsOneWidget);

      controller.dispose();
    });
  });
}
