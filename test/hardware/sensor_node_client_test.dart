import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse/core/soil.dart';
import 'package:pulse/hardware/sensor_node_client.dart';

void main() {
  group('SensorNodeClient', () {
    test('reading parse succeeds with valid payload', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/reading');
        expect(request.headers['X-PULSE-Token'], 'test-token-123');
        expect(request.headers['X-PULSE-Time'], isNotEmpty);

        final json = {
          'seq': 42,
          'sampleAgeMs': 120,
          'uptimeS': 3600,
          'soil': {
            'percent': 48.5,
            'raw': 2150,
            'status': 'OPTIMAL',
            'stable': true,
            'sensorOk': true,
          },
          'net': {
            'mode': 'STA',
            'ssid': 'HomeWifi',
            'rssi': -60,
            'ip': '192.168.1.50',
          },
          'lastPhi': {
            'phi': 72.0,
            'tier': 'ENHANCE',
            'locationName': 'Balcony',
            'ts': 1732550000,
          },
        };
        return http.Response(jsonEncode(json), 200, headers: {'content-type': 'application/json'});
      });

      final client = SensorNodeClient(client: mock);
      final reading = await client.reading('192.168.1.50', 80, token: 'test-token-123');

      expect(reading.seq, 42);
      expect(reading.sampleAgeMs, 120);
      expect(reading.soil.percent, 48.5);
      expect(reading.soil.status, SoilStatus.optimal);
      expect(reading.soil.stable, isTrue);
      expect(reading.isFresh, isTrue);
      expect(reading.isSensorOk, isTrue);
      expect(reading.net.mode, 'STA');
      expect(reading.lastPhi?.phi, 72.0);
    });

    test('401 response maps to NodeErrorUnauthorized', () async {
      final mock = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final client = SensorNodeClient(client: mock);
      expect(
        () => client.reading('192.168.1.50', 80, token: 'bad-token'),
        throwsA(isA<NodeErrorUnauthorized>()),
      );
    });

    test('429 response maps to NodeErrorPairingLocked', () async {
      final mock = MockClient((request) async {
        return http.Response('Locked', 429);
      });

      final client = SensorNodeClient(client: mock);
      expect(
        () => client.pairConfirm('192.168.1.50', 80, '123456'),
        throwsA(isA<NodeErrorPairingLocked>()),
      );
    });

    test('malformed JSON maps to NodeErrorBadResponse', () async {
      final mock = MockClient((request) async {
        return http.Response('not valid json {[[', 200);
      });

      final client = SensorNodeClient(client: mock);
      expect(
        () => client.reading('192.168.1.50', 80),
        throwsA(isA<NodeErrorBadResponse>()),
      );
    });

    test('pushDisplay failure returns false and does NOT throw', () async {
      final mock = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = SensorNodeClient(client: mock);
      final result = await client.pushDisplay(
        '192.168.1.50',
        80,
        phi: 80.0,
        tier: 'PROTECT',
        locationName: 'Garden',
      );

      expect(result, isFalse);
    });

    test('pushDisplay success returns true and sends payload', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/display');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phi'], 85.0);
        expect(body['tier'], 'PROTECT');
        expect(body['locationName'], 'Front Yard');
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final client = SensorNodeClient(client: mock);
      final result = await client.pushDisplay(
        '192.168.1.50',
        80,
        phi: 85.0,
        tier: 'PROTECT',
        locationName: 'Front Yard',
      );

      expect(result, isTrue);
    });

    test('pairStart and pairConfirm return valid responses', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/api/pair/start') {
          return http.Response(jsonEncode({'status': 'pairing', 'ttlS': 120}), 200);
        } else if (request.url.path == '/api/pair/confirm') {
          final body = jsonDecode(request.body);
          expect(body['pin'], '654321');
          return http.Response(
            jsonEncode({'status': 'paired', 'token': 'abc123token456'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = SensorNodeClient(client: mock);
      final startRes = await client.pairStart('192.168.1.50', 80);
      expect(startRes['ttlS'], 120);

      final token = await client.pairConfirm('192.168.1.50', 80, '654321');
      expect(token, 'abc123token456');
    });
  });
}
