import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'sensor_node_client.dart';

/// Represents a sensor node found via discovery.
class DiscoveredNode {
  final String name;
  final String host;
  final int port;
  final String deviceId;
  final String fw;
  final String mode; // 'sta' or 'ap'

  const DiscoveredNode({
    required this.name,
    required this.host,
    required this.port,
    required this.deviceId,
    required this.fw,
    this.mode = 'sta',
  });

  @override
  String toString() =>
      'DiscoveredNode($name, host: $host, port: $port, id: $deviceId, fw: $fw, mode: $mode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredNode &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          host == other.host;

  @override
  int get hashCode => deviceId.hashCode ^ host.hashCode;
}

/// Discovery service providing mDNS LAN search, direct SoftAP probe, and manual IP probe.
class SensorDiscovery {
  static const MethodChannel _multicastChannel =
      MethodChannel('com.pulse.pulse/multicast_lock');

  final SensorNodeClient _client;

  SensorDiscovery({SensorNodeClient? client})
      : _client = client ?? SensorNodeClient();

  /// 1. Discovers nodes on the local Wi-Fi network using mDNS (_pulse._tcp).
  Future<List<DiscoveredNode>> discoverMdns({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final discovered = <String, DiscoveredNode>{};

    // Acquire Android MulticastLock during scan
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _multicastChannel.invokeMethod('acquire');
      } catch (e) {
        debugPrint('[SensorDiscovery] Acquire multicast lock error: $e');
      }
    }

    final mdns = MDnsClient();
    try {
      await mdns.start();

      const serviceType = '_pulse._tcp.local';
      final ptrStream = mdns
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
          )
          .timeout(timeout, onTimeout: (sink) => sink.close());

      await for (final ptr in ptrStream) {
        final srvStream = mdns.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        );

        await for (final srv in srvStream) {
          // Resolve A record for host IPv4
          String? ipv4;
          final ipStream = mdns.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          );
          await for (final ip in ipStream) {
            ipv4 = ip.address.address;
            break;
          }

          // Read TXT records for metadata
          var fw = '1.0.0';
          var deviceId = '';
          var nodeName = 'P.U.L.S.E. Node';

          final txtStream = mdns.lookup<TxtResourceRecord>(
            ResourceRecordQuery.text(ptr.domainName),
          );
          await for (final txt in txtStream) {
            final lines = txt.text.split('\n');
            for (final line in lines) {
              final parts = line.split('=');
              if (parts.length >= 2) {
                final k = parts[0].trim();
                final v = parts.sublist(1).join('=').trim();
                if (k == 'id') deviceId = v;
                if (k == 'fw') fw = v;
                if (k == 'name') nodeName = v;
              }
            }
          }

          final resolvedHost = ipv4 ?? srv.target;
          if (deviceId.isEmpty) {
            deviceId = srv.target.replaceAll('.local', '');
          }

          discovered[deviceId] = DiscoveredNode(
            name: nodeName,
            host: resolvedHost,
            port: srv.port,
            deviceId: deviceId,
            fw: fw,
            mode: 'sta',
          );
        }
      }
    } catch (e) {
      debugPrint('[SensorDiscovery] mDNS scan error: $e');
    } finally {
      mdns.stop();
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _multicastChannel.invokeMethod('release');
        } catch (e) {
          debugPrint('[SensorDiscovery] Release multicast lock error: $e');
        }
      }
    }

    // If mDNS found nothing (e.g. mobile hotspot where multicast DNS is filtered by Android OS),
    // automatically run a fast subnet and SoftAP probe
    if (discovered.isEmpty && !kIsWeb) {
      final subnetNodes = await probeSubnet();
      for (final n in subnetNodes) {
        discovered[n.deviceId] = n;
      }
    }

    return discovered.values.toList();
  }

  static bool _isPrivateIpv4(List<String> parts) {
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    if (a == 192 && b == 168) return true;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  /// Probes local subnets (including mobile hotspot 10.x / 192.168.43.x and SoftAP 192.168.4.1)
  Future<List<DiscoveredNode>> probeSubnet({
    Duration timeout = const Duration(milliseconds: 350),
  }) async {
    final nodes = <DiscoveredNode>[];
    final subnets = <String>{};
    final selfIps = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (_isPrivateIpv4(parts)) {
            subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            selfIps.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('[SensorDiscovery] Error listing network interfaces: $e');
    }

    // Fallback default hotspot/SoftAP subnets if no interface detected
    if (subnets.isEmpty) {
      subnets.addAll({'192.168.43', '192.168.4'});
    } else {
      subnets.add('192.168.4');
    }

    for (final subnet in subnets) {
      final targets = subnet == '192.168.4'
          ? <String>['192.168.4.1']
          : <String>[
              for (int i = 1; i <= 254; i++)
                if (!selfIps.contains('$subnet.$i')) '$subnet.$i',
            ];

      // Fast TCP port 80 check in waves of 64 to find open nodes within ~400ms
      final openHosts = <String>[];
      for (int i = 0; i < targets.length; i += 64) {
        final chunk = targets.sublist(
            i, i + 64 > targets.length ? targets.length : i + 64);
        final chunkResults = await Future.wait(
          chunk.map((ip) async {
            try {
              final socket = await Socket.connect(ip, 80, timeout: timeout);
              socket.destroy();
              return ip;
            } catch (_) {
              return null;
            }
          }),
        );
        openHosts.addAll(chunkResults.whereType<String>());
      }

      // Query /api/health only on responsive hosts
      final healthResults = await Future.wait(
        openHosts.map((ip) async {
          try {
            final health = await _client.health(ip, 80);
            if (health['ok'] != true && health['deviceId'] == null) return null;
            final deviceId =
                (health['deviceId'] ?? health['id']) as String? ?? ip;
            final fw = health['fw'] as String? ?? '1.0.0';
            return DiscoveredNode(
              name: 'PULSE Node ($deviceId)',
              host: ip,
              port: 80,
              deviceId: deviceId,
              fw: fw,
              mode: ip == '192.168.4.1' ? 'ap' : 'sta',
            );
          } catch (_) {
            return null;
          }
        }),
      );
      nodes.addAll(healthResults.whereType<DiscoveredNode>());
    }

    return nodes;
  }

  /// 2. Probes the node directly over its SoftAP (`192.168.4.1`).
  /// Forces Wi-Fi socket routing on Android to bypass mobile data.
  Future<DiscoveredNode?> probeSoftAp({
    String apHost = '192.168.4.1',
    int apPort = 80,
  }) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await WiFiForIoTPlugin.forceWifiUsage(true);
        } catch (e) {
          debugPrint('[SensorDiscovery] forceWifiUsage error: $e');
        }
      }

      final health = await _client.health(apHost, apPort);
      final deviceId =
          (health['deviceId'] ?? health['id']) as String? ?? 'AP-NODE';
      final fw = health['fw'] as String? ?? '1.0.0';

      return DiscoveredNode(
        name: 'PULSE Node ($deviceId)',
        host: apHost,
        port: apPort,
        deviceId: deviceId,
        fw: fw,
        mode: 'ap',
      );
    } catch (e) {
      debugPrint('[SensorDiscovery] SoftAP probe error: $e');
      return null;
    }
  }

  /// Cleans up any forced Wi-Fi usage when leaving SoftAP pairing.
  Future<void> releaseSoftAp() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await WiFiForIoTPlugin.forceWifiUsage(false);
      } catch (e) {
        debugPrint('[SensorDiscovery] release forceWifiUsage error: $e');
      }
    }
  }

  /// 3. Validates and probes a manually entered IP or hostname.
  Future<DiscoveredNode?> probeManualIp(String input, {int port = 80}) async {
    final host = input.trim();
    if (!isValidHost(host)) return null;

    try {
      final health = await _client.health(host, port);
      final deviceId =
          (health['deviceId'] ?? health['id']) as String? ?? host;
      final fw = health['fw'] as String? ?? '1.0.0';

      return DiscoveredNode(
        name: 'PULSE Node ($deviceId)',
        host: host,
        port: port,
        deviceId: deviceId,
        fw: fw,
        mode: 'sta',
      );
    } catch (e) {
      debugPrint('[SensorDiscovery] Manual IP probe error: $e');
      return null;
    }
  }

  /// Validates IPv4 address or hostname format.
  static bool isValidHost(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    // If string consists entirely of digits and dots, it's an IP address
    if (RegExp(r'^[\d.]+$').hasMatch(trimmed)) {
      final parts = trimmed.split('.');
      if (parts.length != 4) return false;
      return parts.every((p) {
        final n = int.tryParse(p);
        return n != null && n >= 0 && n <= 255;
      });
    }

    // Hostname check (.local or alphanumeric with dashes)
    final hostRegex = RegExp(
        r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');
    return hostRegex.hasMatch(trimmed);
  }
}
