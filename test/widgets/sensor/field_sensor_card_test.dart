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
import 'package:pulse/widgets/sensor/field_sensor_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalDb.instance.inMemoryStorage = <String, String>{};
    LocalDb.instance.clearInMemory();
  });

  tearDown(() {
    LocalDb.instance.clearInMemory();
    LocalDb.instance.inMemoryStorage = null;
  });

  Widget buildTestableWidget({
    required Widget child,
    SensorNodeController? controller,
  }) {
    Widget content = child;
    if (controller != null) {
      content = ChangeNotifierProvider<SensorNodeController>.value(
        value: controller,
        child: child,
      );
    }
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: content),
      ),
    );
  }

  group('FieldSensorCard Widget Tests', () {
    testWidgets('unpaired state displays setup card with dismiss button', (tester) async {
      final repo = SensorNodeRepository();
      final controller = SensorNodeController(
        repo: repo,
        client: SensorNodeClient(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          controller: controller,
          child: const FieldSensorCard(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Add a field sensor for live soil moisture'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap dismiss
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Card disappears
      expect(find.text('Add a field sensor for live soil moisture'), findsNothing);

      controller.dispose();
    });

    testWidgets('paired online state displays live telemetry, value, and assess action', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'seq': 5,
            'sampleAgeMs': 300,
            'uptimeS': 200,
            'soil': {
              'percent': 55.0,
              'raw': 2100,
              'status': 'OPTIMAL',
              'stable': true,
              'sensorOk': true,
            },
            'net': {'mode': 'STA', 'ssid': 'Garden_Wifi', 'rssi': -58, 'ip': '192.168.1.55'},
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
        buildTestableWidget(
          controller: controller,
          child: const FieldSensorCard(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Field sensor'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);
      expect(find.text('Optimal'), findsOneWidget);
      expect(find.text('Assess this site'), findsOneWidget);

      controller.dispose();
    });
  });
}
