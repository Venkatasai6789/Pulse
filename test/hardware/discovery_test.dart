import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse/hardware/sensor_discovery.dart';
import 'package:pulse/hardware/sensor_node_client.dart';

void main() {
  group('SensorDiscovery host validation', () {
    test('validates correct IPv4 addresses', () {
      expect(SensorDiscovery.isValidHost('192.168.1.1'), isTrue);
      expect(SensorDiscovery.isValidHost('10.0.0.1'), isTrue);
      expect(SensorDiscovery.isValidHost('172.16.0.1'), isTrue);
      expect(SensorDiscovery.isValidHost('192.168.4.1'), isTrue);
      expect(SensorDiscovery.isValidHost('127.0.0.1'), isTrue);
    });

    test('validates correct hostnames', () {
      expect(SensorDiscovery.isValidHost('pulse-node.local'), isTrue);
      expect(SensorDiscovery.isValidHost('esp32-node.lan'), isTrue);
      expect(SensorDiscovery.isValidHost('node-device'), isTrue);
    });

    test('rejects invalid IPs and hostnames', () {
      expect(SensorDiscovery.isValidHost(''), isFalse);
      expect(SensorDiscovery.isValidHost('   '), isFalse);
      expect(SensorDiscovery.isValidHost('256.1.1.1'), isFalse);
      expect(SensorDiscovery.isValidHost('192.168.1.999'), isFalse);
      expect(SensorDiscovery.isValidHost('1.2.3.4.5'), isFalse);
      expect(SensorDiscovery.isValidHost('invalid@host!'), isFalse);
    });
  });

  group('SensorDiscovery probing', () {
    test('probeSoftAp contacts 192.168.4.1 health endpoint', () async {
      final mock = MockClient((request) async {
        if (request.url.host == '192.168.4.1' && request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'id': 'E831CD1A',
              'fw': '1.0.0',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final discovery = SensorDiscovery(
        client: SensorNodeClient(client: mock),
      );

      final node = await discovery.probeSoftAp();
      expect(node, isNotNull);
      expect(node?.deviceId, 'E831CD1A');
      expect(node?.host, '192.168.4.1');
      expect(node?.mode, 'ap');
      expect(node?.fw, '1.0.0');
    });

    test('probeManualIp validates and probes entered address', () async {
      final mock = MockClient((request) async {
        if (request.url.host == '192.168.1.120' && request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'id': 'NODE-120',
              'fw': '1.0.0',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final discovery = SensorDiscovery(
        client: SensorNodeClient(client: mock),
      );

      final validNode = await discovery.probeManualIp('192.168.1.120');
      expect(validNode, isNotNull);
      expect(validNode?.deviceId, 'NODE-120');

      final invalidNode = await discovery.probeManualIp('999.999.999.999');
      expect(invalidNode, isNull);
    });
  });
}
