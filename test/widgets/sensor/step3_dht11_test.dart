import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pulse/data/local_db.dart';
import 'package:pulse/hardware/models/sensor_node.dart';
import 'package:pulse/hardware/sensor_node_client.dart';
import 'package:pulse/hardware/sensor_node_controller.dart';
import 'package:pulse/hardware/sensor_node_repository.dart';
import 'package:pulse/models/models.dart';
import 'package:pulse/screens/monitor/widgets/shake_wrapper.dart';
import 'package:pulse/screens/monitor/widgets/step3_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LocalDb.instance.inMemoryStorage = <String, String>{};
    LocalDb.instance.clearInMemory();
  });

  tearDown(() {
    LocalDb.instance.clearInMemory();
    LocalDb.instance.inMemoryStorage = null;
  });

  Widget buildHarness({
    required Widget child,
    SensorNodeController? controller,
    double textScale = 1.0,
    Size size = const Size(420, 900),
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<SensorNodeController> makeController(
    WidgetTester tester, {
    required bool dhtOk,
    double tempC = 26.5,
    double humidityPct = 64.0,
  }) async {
    int seq = 1;
    final mock = MockClient((request) async {
      final json = {
        'seq': seq++,
        'sampleAgeMs': 150,
        'uptimeS': 120,
        'soil': {
          'percent': 52.0,
          'raw': 2000,
          'status': 'OPTIMAL',
          'stable': true,
          'sensorOk': true,
        },
        'dht': {
          'sensorOk': dhtOk,
          'ageMs': dhtOk ? 300 : 999999,
          'temperatureC': dhtOk ? tempC : null,
          'humidityPct': dhtOk ? humidityPct : null,
          'heatIndexC': dhtOk ? tempC + 0.5 : null,
        },
        'net': {
          'mode': 'STA',
          'ssid': 'FieldWifi',
          'rssi': -55,
          'ip': '192.168.1.50',
        },
      };
      return http.Response(jsonEncode(json), 200);
    });

    final repo = SensorNodeRepository();
    await repo.saveNode(
      SensorNode(
        deviceId: 'DEV-DHT-65F4',
        name: 'Field Node',
        host: '192.168.1.50',
        port: 80,
        fw: '1.1.0',
        pairedAt: DateTime.now(),
        isActive: true,
      ),
    );

    final ctrl = SensorNodeController(
      repo: repo,
      client: SensorNodeClient(client: mock),
    );
    await tester.pump(const Duration(milliseconds: 50));
    ctrl.acquire();
    await tester.pump(const Duration(milliseconds: 50));
    await ctrl.refresh();
    return ctrl;
  }

  group('Step3Environment DHT11 integration', () {
    testWidgets('auto-reflects live DHT11 temp and humidity and supports manual override',
        (tester) async {
      final ctrl = await makeController(tester, dhtOk: true, tempC: 26.5, humidityPct: 64.0);

      Assessment draft = Assessment(
        id: 'draft-dht-1',
        locationId: 'loc-1',
        co2Ppm: 500,
        createdAt: DateTime.now(),
      );

      final tempKey = GlobalKey<ShakeWrapperState>();
      final humKey = GlobalKey<ShakeWrapperState>();
      final co2Key = GlobalKey<ShakeWrapperState>();

      await tester.pumpWidget(
        buildHarness(
          controller: ctrl,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Step3Environment(
                draft: draft,
                onDraftChanged: (updated) {
                  setState(() => draft = updated);
                },
                tempKey: tempKey,
                humidityKey: humKey,
                co2Key: co2Key,
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(draft.temperatureC, 26.5);
      expect(draft.humidityPct, 64.0);
      expect(draft.climateSource, 'esp32_dht11');
      expect(draft.climateDeviceId, 'DEV-DHT-65F4');
      expect(find.text('Live DHT11 · 65F4'), findsNWidgets(2));
      expect(find.text('Environmental Score'), findsOneWidget);

      // Manual edit pauses auto-sync and switches provenance to manual
      final tempField = find.widgetWithText(TextField, '26.5');
      expect(tempField, findsOneWidget);
      await tester.enterText(tempField, '29.0');
      await tester.pump();

      expect(draft.temperatureC, 29.0);
      expect(draft.climateSource, 'manual');
      expect(find.textContaining('Use live DHT11'), findsNWidgets(2));

      // Re-sync restores live DHT11 value
      await tester.tap(find.text('Use live DHT11 (26.5 °C)'));
      await tester.pump();

      expect(draft.temperatureC, 26.5);
      expect(draft.humidityPct, 64.0);
      expect(draft.climateSource, 'esp32_dht11');
      ctrl.dispose();
    });

    testWidgets('shows soft fault banner when DHT11 disconnected and zero overflow at 360dp 1.3x',
        (tester) async {
      final ctrl = await makeController(tester, dhtOk: false);

      Assessment draft = Assessment(
        id: 'draft-dht-2',
        locationId: 'loc-1',
        createdAt: DateTime.now(),
      );

      final tempKey = GlobalKey<ShakeWrapperState>();
      final humKey = GlobalKey<ShakeWrapperState>();
      final co2Key = GlobalKey<ShakeWrapperState>();

      await tester.pumpWidget(
        buildHarness(
          controller: ctrl,
          size: const Size(360, 800),
          textScale: 1.3,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Step3Environment(
                draft: draft,
                onDraftChanged: (updated) {
                  setState(() => draft = updated);
                },
                tempKey: tempKey,
                humidityKey: humKey,
                co2Key: co2Key,
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('DHT11 sensor not detected on GPIO 32 — enter temperature & humidity manually.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      ctrl.dispose();
    });
  });
}
