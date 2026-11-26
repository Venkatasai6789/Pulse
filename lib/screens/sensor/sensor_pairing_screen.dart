import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api_service.dart';
import '../../hardware/sensor_discovery.dart';
import '../../hardware/sensor_node_client.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

enum PairingStep { discovery, pinEntry, success }

enum DiscoveryMethod { sameWifi, directAp }

class SensorPairingScreen extends StatefulWidget {
  const SensorPairingScreen({super.key});

  @override
  State<SensorPairingScreen> createState() => _SensorPairingScreenState();
}

class _SensorPairingScreenState extends State<SensorPairingScreen> {
  PairingStep _step = PairingStep.discovery;
  DiscoveryMethod _method = DiscoveryMethod.sameWifi;

  final SensorDiscovery _discovery = SensorDiscovery();
  final SensorNodeClient _client = SensorNodeClient();

  bool _isScanning = false;
  List<DiscoveredNode> _nodes = [];
  String? _scanError;

  DiscoveredNode? _selectedNode;
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _countdownTimer;
  int _secondsRemaining = 120;
  bool _isPairing = false;
  String? _pinError;

  List<Location> _locations = [];
  String? _selectedLocationId;
  bool _isLinkingLocation = false;

  @override
  void initState() {
    super.initState();
    _startWifiScan();
    _loadLocations();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _discovery.releaseSoftAp();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _client.close();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final api = context.read<ApiService>();
      final locs = await api.getLocations();
      if (mounted) {
        setState(() => _locations = locs);
      }
    } catch (e) {
      debugPrint('[Pairing] Error loading locations: $e');
    }
  }

  Future<void> _startWifiScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanError = null;
      _nodes = [];
    });

    try {
      final results = await _discovery.discoverMdns();
      if (mounted) {
        setState(() {
          _nodes = results;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanError = 'Scan failed: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _probeDirectAp() async {
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    final node = await _discovery.probeSoftAp();
    if (!mounted) return;

    setState(() => _isScanning = false);
    if (node != null) {
      _onSelectNode(node);
    } else {
      setState(() {
        _scanError =
            'Could not reach node at 192.168.4.1. Make sure you are connected to the PULSE-Node Wi-Fi network.';
      });
    }
  }

  Future<void> _showManualIpDialog() async {
    final ipController = TextEditingController(text: '192.168.');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter node IP or hostname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Look at the ESP32 LCD screen (or Mobile Hotspot > Connected devices) for the assigned IP address.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. 192.168.43.100 or 192.168.4.1',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ipController.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isScanning = true);
      final node = await _discovery.probeManualIp(result);
      if (!mounted) return;
      setState(() => _isScanning = false);

      if (node != null) {
        _onSelectNode(node);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Node not reachable at $result. Check the IP and make sure phone and node are on the same network.')),
        );
      }
    }
  }

  Future<void> _onSelectNode(DiscoveredNode node) async {
    if (_isPairing) return;
    setState(() {
      _selectedNode = node;
      _isPairing = true;
      _pinError = null;
    });

    try {
      Map<String, dynamic> startRes;
      try {
        startRes = await _client.pairStart(node.host, node.port);
      } catch (firstErr) {
        // Automatic single-flight recovery: re-probe subnet by deviceId in case IP changed
        final candidates = await _discovery.probeSubnet();
        final refreshed = candidates
            .where((c) => c.deviceId == node.deviceId || c.host == node.host)
            .firstOrNull;
        if (refreshed == null) rethrow;
        node = refreshed;
        if (mounted) setState(() => _selectedNode = refreshed);
        startRes = await _client.pairStart(refreshed.host, refreshed.port);
      }
      final ttl = (startRes['ttlS'] as num?)?.toInt() ??
          (startRes['expiresInS'] as num?)?.toInt() ??
          120;
      if (!mounted) return;

      setState(() {
        _secondsRemaining = ttl;
        _step = PairingStep.pinEntry;
        _isPairing = false;
      });

      _startPinCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPairing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate pairing at ${node.host}: $e')),
      );
    }
  }

  void _startPinCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted && _step == PairingStep.pinEntry) {
          setState(() {
            _pinError = 'PIN expired. Tap scan to try again.';
          });
        }
      }
    });
  }

  Future<void> _submitPin() async {
    final pin = _pinControllers.map((c) => c.text.trim()).join();
    if (pin.length < 6) {
      setState(() => _pinError = 'Please enter all 6 digits');
      return;
    }

    if (_selectedNode == null) return;

    setState(() {
      _isPairing = true;
      _pinError = null;
    });

    try {
      final controller = context.read<SensorNodeController>();
      await controller.pair(_selectedNode!, pin);

      _countdownTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isPairing = false;
        _step = PairingStep.success;
      });
    } on NodeError catch (e) {
      if (!mounted) return;
      setState(() {
        _isPairing = false;
        _pinError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPairing = false;
        _pinError = 'Pairing error: $e';
      });
    }
  }

  Future<void> _onDone() async {
    if (_selectedLocationId != null && _selectedNode != null) {
      final loc = _locations.firstWhere((l) => l.id == _selectedLocationId);
      final controller = context.read<SensorNodeController>();
      setState(() => _isLinkingLocation = true);
      await controller.linkLocation(loc.id, loc.name);
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pair a sensor node',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          PairingStep.discovery => _buildDiscoveryView(),
          PairingStep.pinEntry => _buildPinEntryView(),
          PairingStep.success => _buildSuccessView(),
        },
      ),
    );
  }

  Widget _buildDiscoveryView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Segmented Control
        SegmentedButton<DiscoveryMethod>(
          segments: const [
            ButtonSegment(
              value: DiscoveryMethod.sameWifi,
              label: Text('Same Wi-Fi'),
              icon: Icon(Icons.wifi),
            ),
            ButtonSegment(
              value: DiscoveryMethod.directAp,
              label: Text('Direct to node'),
              icon: Icon(Icons.settings_input_antenna),
            ),
          ],
          selected: {_method},
          onSelectionChanged: (selected) {
            setState(() {
              _method = selected.first;
              _scanError = null;
            });
            if (_method == DiscoveryMethod.sameWifi) {
              _discovery.releaseSoftAp();
              _startWifiScan();
            }
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.forest;
              }
              return Colors.white;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return AppColors.ink;
            }),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _showManualIpDialog,
            child: const Text(
              'Enter IP address',
              style: TextStyle(
                color: AppColors.leaf,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_method == DiscoveryMethod.sameWifi) ...[
          if (_isScanning) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.leaf,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Looking for nodes on this network…',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ] else if (_nodes.isNotEmpty) ...[
            Text(
              'Found nodes (${_nodes.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ..._nodes.map(
              (n) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.sageBorder),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.sage,
                    child: Icon(Icons.sensors, color: AppColors.forest),
                  ),
                  title: Text(
                    n.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${n.host} · ${n.deviceId} · fw ${n.fw}'),
                  trailing: (_isPairing && _selectedNode?.host == n.host)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isPairing ? null : () => _onSelectNode(n),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sageBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off, size: 40, color: AppColors.muted),
                  const SizedBox(height: 12),
                  const Text(
                    'No nodes found',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Check the node shows 'Online' on its display, or use Direct to node.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _showManualIpDialog,
                    icon: const Icon(Icons.pin_outlined),
                    label: const Text('Enter Node IP (from LCD)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _startWifiScan,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan again'),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          // Direct to node view
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connect directly to node',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildNumberedStep(
                  1,
                  'Open Wi-Fi Settings on your phone.',
                ),
                const SizedBox(height: 8),
                _buildNumberedStep(
                  2,
                  'Connect to network PULSE-Node-XXXX with password pulse1234.',
                ),
                const SizedBox(height: 8),
                _buildNumberedStep(
                  3,
                  'Return here and tap Check connection below.',
                ),
                const SizedBox(height: 20),
                if (_scanError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _scanError!,
                      style: const TextStyle(color: AppColors.alert, fontSize: 13),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _isScanning ? null : _probeDirectAp,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Check connection'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNumberedStep(int stepNum, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.sage,
          child: Text(
            '$stepNum',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.forest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  Widget _buildPinEntryView() {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      children: [
        Text(
          'Pairing ${_selectedNode?.name ?? "Node"}',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the 6-digit PIN shown on the node’s display:',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 24),

        // 6 PIN boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              height: 56,
              child: TextField(
                controller: _pinControllers[index],
                focusNode: _pinFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.sageBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.leaf, width: 2),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 5) {
                    _pinFocusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _pinFocusNodes[index - 1].requestFocus();
                  }
                  if (index == 5 && val.isNotEmpty) {
                    _submitPin();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        Center(
          child: Text(
            'Expires in $minutes:$seconds',
            style: TextStyle(
              color: _secondsRemaining < 30 ? AppColors.alert : AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_pinError != null) ...[
          const SizedBox(height: 12),
          Text(
            _pinError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.alert, fontSize: 13),
          ),
        ],
        const SizedBox(height: 28),

        FilledButton(
          onPressed: _isPairing ? null : _submitPin,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forestDark,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: _isPairing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Pair', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() => _step = PairingStep.discovery);
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 50,
              color: AppColors.leaf,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Node paired!',
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedNode?.name ?? 'P.U.L.S.E. Node',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),

        // Optional Location Link
        const Text(
          'Link to a location (optional)',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.forest),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedLocationId,
          decoration: InputDecoration(
            hintText: 'Select a location',
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.sageBorder),
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('None (General node)'),
            ),
            ..._locations.map(
              (loc) => DropdownMenuItem(
                value: loc.id,
                child: Text(loc.name),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() => _selectedLocationId = val);
          },
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: _isLinkingLocation ? null : _onDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forestDark,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: _isLinkingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Done', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
