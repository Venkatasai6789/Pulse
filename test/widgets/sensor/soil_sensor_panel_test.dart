import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pulse/core/soil.dart';
import 'package:pulse/core/soil_reading.dart';
import 'package:pulse/data/local_db.dart';
import 'package:pulse/hardware/models/sensor_node.dart';
import 'package:pulse/hardware/sensor_node_client.dart';
import 'package:pulse/hardware/sensor_node_controller.dart';
import 'package:pulse/hardware/sensor_node_repository.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/widgets/sensor/soil_sensor_panel.dart';

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

  Widget buildTestableWidget({
    required Widget child,
    SensorNodeController? controller,
    double textScale = 1.0,
    Size size = const Size(800, 600),
  }) {
    Widget content = child;
    if (controller != null) {
      content = ChangeNotifierProvider<SensorNodeController>.value(
        value: controller,
        child: child,
      );
    }
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: content),
        ),
      ),
    );
  }

  group('SoilSensorPanel Widget Tests', () {
    testWidgets('manual input without node renders and accepts valid percentage', (tester) async {
      Assessment draft = Assessment(
        id: 'draft-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return SoilSensorPanel(
                draft: draft,
                onDraftChanged: (updated) {
                  setState(() => draft = updated);
                },
              );
            },
          ),
        ),
      );

      expect(find.text('Soil moisture (%)'), findsOneWidget);
      expect(find.text('No live sensor. Enter soil moisture manually or pair a node.'), findsOneWidget);

      // Enter manual percentage
      await tester.enterText(find.byType(TextField), '52');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(draft.soil, isNotNull);
      expect(draft.soil!.percent, 52.0);
      expect(draft.soil!.source, SoilSource.manual);
      expect(find.text('Suitable'), findsOneWidget);

      // Invalid percentage > 100
      await tester.enterText(find.byType(TextField), '120');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Must be between 0 and 100%'), findsOneWidget);
    });

    testWidgets('online node displays live telemetry and captures on button tap', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'seq': 1,
            'sampleAgeMs': 200,
            'uptimeS': 100,
            'soil': {
              'percent': 48.0,
              'raw': 2250,
              'status': 'OPTIMAL',
              'stable': true,
              'sensorOk': true,
            },
            'net': {
              'mode': 'STA',
              'ssid': 'Garden_Wifi',
              'rssi': -62,
              'ip': '192.168.1.55',
            },
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

      Assessment draft = Assessment(
        id: 'draft-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          controller: controller,
          child: StatefulBuilder(
            builder: (context, setState) {
              return SoilSensorPanel(
                draft: draft,
                onDraftChanged: (updated) {
                  setState(() => draft = updated);
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('48'), findsOneWidget);
      expect(find.text('Optimal'), findsOneWidget);
      expect(find.text('Use sensor reading'), findsOneWidget);

      // Tap capture button
      await tester.runAsync(() async {
        await tester.tap(find.text('Use sensor reading'));
        await Future.delayed(const Duration(milliseconds: 600));
      });
      await tester.pump();

      expect(draft.soil, isNotNull);
      expect(draft.soil!.percent, 48.0);
      expect(draft.soil!.source, SoilSource.esp32);
      expect(draft.soil!.status, SoilStatus.optimal);

      controller.dispose();
    });

    testWidgets('fault state displays probe fault panel', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'seq': 2,
            'sampleAgeMs': 100,
            'uptimeS': 120,
            'soil': {
              'percent': 0.0,
              'raw': 0,
              'status': 'DRY',
              'stable': true,
              'sensorOk': false,
            },
            'net': {'mode': 'STA', 'ssid': 'Wifi', 'rssi': -65, 'ip': '192.168.1.55'},
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

      Assessment draft = Assessment(
        id: 'draft-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          controller: controller,
          child: StatefulBuilder(
            builder: (context, setState) {
              return SoilSensorPanel(
                draft: draft,
                onDraftChanged: (updated) {
                  setState(() => draft = updated);
                },
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Probe not detected. Check the A0 wire to GPIO 34.'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('renders cleanly on 360dp width and 1.3x text scale without overflow', (tester) async {
      Assessment draft = Assessment(
        id: 'draft-1',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          size: const Size(360, 640),
          textScale: 1.3,
          child: SoilSensorPanel(
            draft: draft,
            onDraftChanged: (updated) => draft = updated,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
