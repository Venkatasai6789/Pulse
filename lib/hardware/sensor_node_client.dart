import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/node_reading.dart';

/// Sealed error hierarchy for sensor node communication.
sealed class NodeError implements Exception {
  final String message;
  const NodeError(this.message);

  @override
  String toString() => message;
}

class NodeErrorUnreachable extends NodeError {
  const NodeErrorUnreachable([super.message = 'Node not reachable on this network']);
}

class NodeErrorUnauthorized extends NodeError {
  const NodeErrorUnauthorized([super.message = 'Pairing expired. Pair the node again']);
}

class NodeErrorPairingLocked extends NodeError {
  const NodeErrorPairingLocked([super.message = 'Too many wrong PINs. Try again in a minute']);
}

class NodeErrorBadResponse extends NodeError {
  const NodeErrorBadResponse(
      [super.message = 'Unexpected reply from the node. Check the firmware version']);
}

class NodeErrorCalibrationInvalid extends NodeError {
  const NodeErrorCalibrationInvalid([super.message = 'Invalid calibration readings']);
}

class NodeErrorGeneric extends NodeError {
  const NodeErrorGeneric(super.message);
}

/// HTTP client wrapper for communication with an ESP32 P.U.L.S.E. node over LAN or SoftAP.
class SensorNodeClient {
  final http.Client _client;

  SensorNodeClient({http.Client? client}) : _client = client ?? http.Client();

  static const Duration readTimeout = Duration(milliseconds: 2500);
  static const Duration writeTimeout = Duration(milliseconds: 4000);

  Uri _uri(String host, int port, String path, [Map<String, String>? query]) {
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: path,
      queryParameters: query,
    );
  }

  Map<String, String> _headers(String? token) {
    final epochS = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-PULSE-Time': epochS,
    };
    if (token != null && token.isNotEmpty) {
      headers['X-PULSE-Token'] = token;
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<T> _wrapCall<T>(
    Future<http.Response> Function() requestFn, {
    required T Function(http.Response response) onSuccess,
  }) async {
    try {
      final response = await requestFn();
      if (response.statusCode == 200 || response.statusCode == 201) {
        return onSuccess(response);
      } else if (response.statusCode == 401) {
        throw const NodeErrorUnauthorized();
      } else if (response.statusCode == 429) {
        throw const NodeErrorPairingLocked();
      } else if (response.statusCode == 400) {
        throw const NodeErrorCalibrationInvalid();
      } else {
        throw NodeErrorBadResponse(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('[NODE] SocketException: $e');
      throw const NodeErrorUnreachable();
    } on TimeoutException catch (e) {
      debugPrint('[NODE] TimeoutException: $e');
      throw const NodeErrorUnreachable();
    } on FormatException catch (e) {
      debugPrint('[NODE] FormatException: $e');
      throw const NodeErrorBadResponse();
    } on NodeError {
      rethrow;
    } catch (e) {
      debugPrint('[NODE] Unknown error: $e');
      throw NodeErrorGeneric(e.toString());
    }
  }

  /// Probes node health status (`/api/health`).
  Future<Map<String, dynamic>> health(String host, int port) async {
    return _wrapCall(
      () => _client
          .get(_uri(host, port, '/api/health'), headers: _headers(null))
          .timeout(readTimeout),
      onSuccess: (res) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) throw const NodeErrorBadResponse();
        return decoded;
      },
    );
  }

  /// Retrieves full node device and system information (`/api/info`).
  Future<Map<String, dynamic>> info(String host, int port, {String? token}) async {
    return _wrapCall(
      () => _client
          .get(_uri(host, port, '/api/info'), headers: _headers(token))
          .timeout(readTimeout),
      onSuccess: (res) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) throw const NodeErrorBadResponse();
        return decoded;
      },
    );
  }

  /// Fetches latest sensor readings (`/api/reading`).
  Future<NodeReading> reading(String host, int port, {String? token}) async {
    return _wrapCall(
      () => _client
          .get(_uri(host, port, '/api/reading'), headers: _headers(token))
          .timeout(readTimeout),
      onSuccess: (res) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) throw const NodeErrorBadResponse();
        return NodeReading.fromJson(decoded);
      },
    );
  }

  /// Initiates pairing session (`POST /api/pair/start`). Returns TTL and prompt info.
  Future<Map<String, dynamic>> pairStart(String host, int port) async {
    return _wrapCall(
      () => _client
          .post(_uri(host, port, '/api/pair/start'), headers: _headers(null))
          .timeout(writeTimeout),
      onSuccess: (res) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) throw const NodeErrorBadResponse();
        return decoded;
      },
    );
  }

  /// Confirms pairing with the 6-digit PIN shown on the LCD (`POST /api/pair/confirm`).
  /// Returns the 32-character authentication token.
  Future<String> pairConfirm(String host, int port, String pin) async {
    return _wrapCall(
      () => _client
          .post(
            _uri(host, port, '/api/pair/confirm'),
            headers: _headers(null),
            body: jsonEncode({'pin': pin.trim()}),
          )
          .timeout(writeTimeout),
      onSuccess: (res) {
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic> || decoded['token'] == null) {
          throw const NodeErrorBadResponse();
        }
        return decoded['token'] as String;
      },
    );
  }

  /// Performs calibration on node (`POST /api/calibrate`).
  Future<bool> calibrate(
    String host,
    int port, {
    String? token,
    String? point, // 'dry' | 'wet'
    int? dryRaw,
    int? wetRaw,
    bool? reset,
  }) async {
    final payload = <String, dynamic>{};
    if (point != null) payload['point'] = point;
    if (dryRaw != null) payload['dryRaw'] = dryRaw;
    if (wetRaw != null) payload['wetRaw'] = wetRaw;
    if (reset != null) payload['reset'] = reset;

    return _wrapCall(
      () => _client
          .post(
            _uri(host, port, '/api/calibrate'),
            headers: _headers(token),
            body: jsonEncode(payload),
          )
          .timeout(writeTimeout),
      onSuccess: (res) => true,
    );
  }

  /// Pushes assessment PHI results to the node LCD display (`POST /api/display`).
  /// Never throws to callers; returns bool and logs failures with `[NODE]`.
  Future<bool> pushDisplay(
    String host,
    int port, {
    String? token,
    required double phi,
    required String tier,
    required String locationName,
    int? ts,
  }) async {
    try {
      final payload = {
        'phi': phi,
        'tier': tier,
        'locationName': locationName,
        'ts': ts ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      };

      final response = await _client
          .post(
            _uri(host, port, '/api/display'),
            headers: _headers(token),
            body: jsonEncode(payload),
          )
          .timeout(writeTimeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
            '[NODE] pushDisplay failed with HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[NODE] pushDisplay failed with error: $e');
      return false;
    }
  }

  /// Updates node configuration such as friendly name or linked location (`POST /api/config`).
  Future<bool> config(
    String host,
    int port, {
    String? token,
    String? name,
    String? locationId,
    String? locationName,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (locationId != null) payload['locationId'] = locationId;
    if (locationName != null) payload['locationName'] = locationName;

    return _wrapCall(
      () => _client
          .post(
            _uri(host, port, '/api/config'),
            headers: _headers(token),
            body: jsonEncode(payload),
          )
          .timeout(writeTimeout),
      onSuccess: (res) => true,
    );
  }

  /// Triggers physical identification alert banner on LCD (`POST /api/identify`).
  Future<bool> identify(String host, int port, {String? token}) async {
    return _wrapCall(
      () => _client
          .post(_uri(host, port, '/api/identify'), headers: _headers(token))
          .timeout(writeTimeout),
      onSuccess: (res) => true,
    );
  }

  void close() {
    _client.close();
  }
}
