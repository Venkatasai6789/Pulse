import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/phi.dart';
import '../core/soil_reading.dart';
import 'models/node_connection.dart';
import 'models/node_reading.dart';
import 'models/sensor_node.dart';
import 'sensor_discovery.dart';
import 'sensor_node_client.dart';
import 'sensor_node_repository.dart';

/// Central state controller managing sensor node lifecycle, polling, and data capture.
class SensorNodeController extends ChangeNotifier {
  final SensorNodeRepository _repo;
  final SensorNodeClient _client;

  NodeConnection _state = NodeConnection.notPaired;
  NodeReading? _latest;
  SensorNode? _node;
  DateTime? _lastUpdated;

  int _lastSeq = -1;
  DateTime? _lastSeqAdvancedAt;
  int _consecutiveFailures = 0;
  int _refCount = 0;
  Timer? _pollTimer;
  bool _isDisposed = false;
  bool _isRediscovering = false;
  DateTime? _lastRediscoverAt;
  AppLifecycleListener? _lifecycleListener;

  SensorNodeController({
    SensorNodeRepository? repo,
    SensorNodeClient? client,
  })  : _repo = repo ?? SensorNodeRepository(),
        _client = client ?? SensorNodeClient() {
    _init();
  }

  NodeConnection get state => _state;
  NodeReading? get latest => _latest;
  SensorNode? get node => _node;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasActiveNode => _node != null;

  Future<void> _init() async {
    _node = await _repo.getActiveNode();
    if (_node != null) {
      _state = NodeConnection.searching;
      notifyListeners();
      _schedulePoll(const Duration(milliseconds: 200));
    } else {
      _state = NodeConnection.notPaired;
      notifyListeners();
    }

    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleStateChanged,
    );
  }

  void _onLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pollTimer == null && _node != null) {
        _schedulePoll(Duration.zero);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Increments active consumer count and starts polling if first subscriber.
  void acquire() {
    _refCount++;
    if (_node != null) {
      _consecutiveFailures = 0;
      _schedulePoll(Duration.zero);
    }
  }

  /// Decrements active consumer count and stops polling when 0 subscribers remain.
  void release() {
    if (_refCount > 0) _refCount--;
  }

  void _schedulePoll(Duration delay) {
    _pollTimer?.cancel();
    if (_isDisposed || _node == null) return;

    _pollTimer = Timer(delay, _poll);
  }

  Future<void> _poll() async {
    if (_isDisposed || _node == null) return;

    try {
      final reading = await _client.reading(
        _node!.host,
        _node!.port,
        token: _node!.token,
      );

      _consecutiveFailures = 0;
      _latest = reading;
      final now = DateTime.now();
      _lastUpdated = now;

      // Track sequence advancement
      if (reading.seq != _lastSeq) {
        _lastSeq = reading.seq;
        _lastSeqAdvancedAt = now;
      }

      // Determine state
      final prevState = _state;
      if (!reading.isSensorOk) {
        _updateState(NodeConnection.fault);
      } else if (_lastSeqAdvancedAt != null &&
          now.difference(_lastSeqAdvancedAt!).inSeconds > 15) {
        _updateState(NodeConnection.stale);
      } else {
        _updateState(NodeConnection.online);
      }

      // CRITICAL: always notify listeners when new telemetry arrives even if state stayed online
      if (_state == prevState) {
        notifyListeners();
      }

      unawaited(_repo.updateLastSeen(_node!.deviceId, now));

      // Low-latency 600ms live stream when active screen watching; 8s heartbeat in background
      final nextInterval =
          _refCount > 0 ? const Duration(milliseconds: 600) : const Duration(seconds: 8);
      _schedulePoll(nextInterval);
    } on NodeErrorUnauthorized {
      _updateState(NodeConnection.unauthorized);
      // Stop polling on 401 until re-paired
      _pollTimer?.cancel();
      _pollTimer = null;
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 2) {
        _tryRediscover();
      }
      if (_consecutiveFailures >= 3) {
        _updateState(NodeConnection.offline);
      }

      // Exponential backoff: 1.5s -> 4s -> 8s -> 15s
      Duration backoff;
      if (_consecutiveFailures <= 1) {
        backoff = const Duration(milliseconds: 1500);
      } else if (_consecutiveFailures == 2) {
        backoff = const Duration(seconds: 4);
      } else if (_consecutiveFailures == 3) {
        backoff = const Duration(seconds: 8);
      } else {
        backoff = const Duration(seconds: 15);
      }

      _schedulePoll(backoff);
    }
  }

  Future<void> _tryRediscover() async {
    if (_node == null || _isDisposed || _isRediscovering) return;
    final now = DateTime.now();
    if (_lastRediscoverAt != null &&
        now.difference(_lastRediscoverAt!).inSeconds < 15) {
      return;
    }
    _isRediscovering = true;
    _lastRediscoverAt = now;
    final tempClient = SensorNodeClient();
    try {
      final tempDiscovery = SensorDiscovery(client: tempClient);
      final nodes = await tempDiscovery.probeSubnet();
      final match = nodes.where((n) => n.deviceId == _node!.deviceId).firstOrNull;
      if (match != null && match.host != _node!.host) {
        debugPrint('[SensorNodeController] Node IP updated from ${_node!.host} to ${match.host}');
        final updated = _node!.copyWith(host: match.host);
        await _repo.saveNode(updated);
        _node = updated;
        _consecutiveFailures = 0;
        _schedulePoll(Duration.zero);
      }
    } catch (e) {
      debugPrint('[SensorNodeController] Rediscovery notice: $e');
    } finally {
      tempClient.close();
      _isRediscovering = false;
    }
  }

  void _updateState(NodeConnection newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Refreshes active node state by polling immediately.
  Future<void> refresh() async {
    _node ??= await _repo.getActiveNode();
    if (_node != null) {
      await _poll();
    }
  }

  /// Captures a fresh, valid [SoilReading] from the connected node.
  /// Returns null if node is offline, stale, or reporting a sensor fault.
  Future<SoilReading?> capture() async {
    if (_node == null || _latest == null) return null;
    if (_state != NodeConnection.online) return null;
    if (!_latest!.isSensorOk) return null;
    if (!_latest!.isFresh) return null;

    final now = DateTime.now();
    if (_lastSeqAdvancedAt != null &&
        now.difference(_lastSeqAdvancedAt!).inSeconds > 15) {
      return null;
    }

    // Phone GPS: best effort, 3s timeout, null on denial (no prompting)
    Position? pos;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
      if (enabled) {
        final perm = await Geolocator.checkPermission()
            .timeout(const Duration(milliseconds: 500), onTimeout: () => LocationPermission.denied);
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SensorNodeController] GPS capture notice: $e');
    }

    return _latest!.toSoilReading(
      deviceId: _node!.deviceId,
      firmware: _node!.fw,
      lat: pos?.latitude,
      lng: pos?.longitude,
    );
  }

  /// Pushes assessment results to the node's LCD screen.
  Future<void> pushPhi(PhiResult r, String locationName) async {
    if (_node == null) return;
    unawaited(
      _client.pushDisplay(
        _node!.host,
        _node!.port,
        token: _node!.token,
        phi: r.phi.toDouble(),
        tier: r.tier.name.toUpperCase(),
        locationName: locationName,
      ),
    );
  }

  /// Pairs with a discovered node using the 6-digit PIN on the LCD.
  Future<void> pair(DiscoveredNode discovered, String pin) async {
    final token = await _client.pairConfirm(discovered.host, discovered.port, pin);

    final newNode = SensorNode(
      deviceId: discovered.deviceId,
      name: discovered.name,
      host: discovered.host,
      port: discovered.port,
      mode: discovered.mode,
      token: token,
      fw: discovered.fw,
      pairedAt: DateTime.now(),
      isActive: true,
    );

    await _repo.saveNode(newNode);
    _node = newNode;
    _latest = null;
    _lastSeq = -1;
    _lastSeqAdvancedAt = null;
    _consecutiveFailures = 0;
    _updateState(NodeConnection.searching);

    _schedulePoll(Duration.zero);
    try {
      await _poll();
    } catch (_) {}
  }

  /// Unpairs the active node.
  Future<void> unpair() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_node != null) {
      await _repo.deleteNode(_node!.deviceId);
    }
    _node = null;
    _latest = null;
    _lastSeq = -1;
    _lastSeqAdvancedAt = null;
    _updateState(NodeConnection.notPaired);
  }

  /// Calibrates dry/wet points or resets calibration on the node.
  Future<bool> calibrate({
    String? point,
    int? dryRaw,
    int? wetRaw,
    bool? reset,
  }) async {
    if (_node == null) return false;
    final ok = await _client.calibrate(
      _node!.host,
      _node!.port,
      token: _node!.token,
      point: point,
      dryRaw: dryRaw,
      wetRaw: wetRaw,
      reset: reset,
    );

    if (ok) {
      final updated = _node!.copyWith(
        dryRaw: dryRaw ?? (reset == true ? 3200 : _node!.dryRaw),
        wetRaw: wetRaw ?? (reset == true ? 1500 : _node!.wetRaw),
      );
      await _repo.saveNode(updated);
      _node = updated;
      notifyListeners();
    }
    return ok;
  }

  /// Renames the active node.
  Future<bool> rename(String newName) async {
    if (_node == null) return false;
    final ok = await _client.config(
      _node!.host,
      _node!.port,
      token: _node!.token,
      name: newName,
    );
    if (ok) {
      final updated = _node!.copyWith(name: newName);
      await _repo.saveNode(updated);
      _node = updated;
      notifyListeners();
    }
    return ok;
  }

  /// Links the active node to a location.
  Future<bool> linkLocation(String locationId, String locationName) async {
    if (_node == null) return false;
    final ok = await _client.config(
      _node!.host,
      _node!.port,
      token: _node!.token,
      locationId: locationId,
      locationName: locationName,
    );
    if (ok) {
      final updated = _node!.copyWith(
        linkedLocationId: locationId,
        linkedLocationName: locationName,
      );
      await _repo.saveNode(updated);
      _node = updated;
      notifyListeners();
    }
    return ok;
  }

  /// Unlinks the active node from its linked location.
  Future<bool> unlinkLocation() async {
    if (_node == null) return false;
    final ok = await _client.config(
      _node!.host,
      _node!.port,
      token: _node!.token,
      locationId: '',
      locationName: '',
    );
    if (ok) {
      final updated = _node!.copyWith(
        linkedLocationId: null,
        linkedLocationName: null,
      );
      await _repo.saveNode(updated);
      _node = updated;
      notifyListeners();
    }
    return ok;
  }

  /// Triggers the identify alert banner on the node.
  Future<bool> identify() async {
    if (_node == null) return false;
    return _client.identify(_node!.host, _node!.port, token: _node!.token);
  }

  /// Returns the node linked to a specific location if available.
  Future<SensorNode?> nodeForLocation(String locationId) =>
      _repo.getNodeForLocation(locationId);

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    _lifecycleListener?.dispose();
    _client.close();
    super.dispose();
  }
}

/// Safe context extension providing nullable SensorNodeController
/// to support isolated test runs or widget tests without provider injection.
extension SafeSensorNodeContext on BuildContext {
  SensorNodeController? watchSensorNode() {
    try {
      return Provider.of<SensorNodeController>(this, listen: true);
    } catch (_) {
      return null;
    }
  }

  SensorNodeController? readSensorNode() {
    try {
      return Provider.of<SensorNodeController>(this, listen: false);
    } catch (_) {
      return null;
    }
  }
}
