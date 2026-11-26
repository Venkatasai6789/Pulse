import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api_service.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'sensor_status_dot.dart';

/// Card on Profile screen placed above the Gemini AI settings card.
class FieldSensorSettingsCard extends StatefulWidget {
  const FieldSensorSettingsCard({super.key});

  @override
  State<FieldSensorSettingsCard> createState() => _FieldSensorSettingsCardState();
}

class _FieldSensorSettingsCardState extends State<FieldSensorSettingsCard> {
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.readSensorNode()?.acquire();
      }
    });
  }

  @override
  void dispose() {
    try {
      context.readSensorNode()?.release();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _testConnection() async {
    final controller = context.readSensorNode();
    if (controller == null) return;
    setState(() => _isTesting = true);
    await controller.refresh();
    if (mounted) {
      setState(() => _isTesting = false);
      final isOnline = controller.state == NodeConnection.online;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline
              ? '✓ Sensor node is online and responding.'
              : 'Node is ${controller.state.name}. Check Wi-Fi connection.'),
          backgroundColor: isOnline ? AppColors.forest : AppColors.alert,
        ),
      );
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = context.readSensorNode();
    if (controller == null) return;
    final currentName = controller.node?.name ?? '';
    final textController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Sensor Node'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Garden Node'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await controller.rename(newName);
    }
  }

  Future<void> _showLinkLocationDialog() async {
    final controller = context.readSensorNode();
    if (controller == null) return;
    final api = context.read<ApiService>();
    final locations = await api.getLocations();

    if (!mounted) return;

    final selected = await showDialog<Location?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Link to a Location'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('None (Unlink)'),
          ),
          ...locations.map(
            (l) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l),
              child: Text(l.name),
            ),
          ),
        ],
      ),
    );

    if (selected != null) {
      await controller.linkLocation(selected.id, selected.name);
    } else {
      await controller.unlinkLocation();
    }
  }

  void _showCalibrationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CalibrationBottomSheet(),
    );
  }

  Future<void> _confirmUnpair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair Sensor Node?'),
        content: const Text(
          'This will remove the sensor node from this device. You will need to pair it again with the LCD PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final controller = context.readSensorNode();
      await controller?.unpair();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sensor node unpaired')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watchSensorNode();
    if (controller == null) return const SizedBox.shrink();
    final node = controller.node;
    final state = controller.state;
    final isPaired = node != null && state != NodeConnection.notPaired;

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.sageBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: icon tile + title Lora + subtitle + status pill
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sensors_rounded, color: AppColors.forest),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Field sensor',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPaired ? '${node.name} · fw ${node.fw}' : 'No node paired',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPaired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: state == NodeConnection.online
                          ? AppColors.sage
                          : AppColors.sageBorder.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SensorStatusDot(state: state),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (!isPaired) ...[
              const Text(
                'Pair an ESP32 hardware node with a soil moisture sensor and LCD display.',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/sensor/pair'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Pair a node'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ] else ...[
              // Telemetry rows
              _buildRow('Network', '${controller.latest?.net.ssid ?? (node.mode == "ap" ? "Direct AP" : "Wi-Fi")} · ${node.host}'),
              _buildRow('Signal', '${controller.latest?.net.rssi ?? -60} dBm'),
              _buildRow('Linked location', node.linkedLocationName ?? 'None'),
              _buildRow('Calibration', 'dry ${node.dryRaw ?? 3200} · wet ${node.wetRaw ?? 1500}'),

              const SizedBox(height: 16),
              const Divider(color: AppColors.sageBorder, height: 1),
              const SizedBox(height: 16),

              // Action Buttons in Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('Test connection'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showCalibrationSheet,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Calibrate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showRenameDialog,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Rename'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showLinkLocationDialog,
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: const Text('Link location'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await controller.identify();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Node display flashed'
                                : 'Failed to reach node'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Identify'),
                  ),
                  TextButton.icon(
                    onPressed: _confirmUnpair,
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.alert),
                    label: const Text('Unpair', style: TextStyle(color: AppColors.alert)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _CalibrationBottomSheet extends StatefulWidget {
  const _CalibrationBottomSheet();

  @override
  State<_CalibrationBottomSheet> createState() => _CalibrationBottomSheetState();
}

class _CalibrationBottomSheetState extends State<_CalibrationBottomSheet> {
  int? _dryRaw;
  int? _wetRaw;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SensorNodeController>();
    final liveRaw = controller.latest?.soil.raw ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.sageBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Sensor Calibration',
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Live raw ADC: $liveRaw',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.leaf),
            ),
            const SizedBox(height: 16),

            // Step 1: Dry in air
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sageBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 1: Hold probe in dry air',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _dryRaw != null ? 'Captured dry: $_dryRaw' : 'Not captured',
                          style: TextStyle(
                            fontSize: 12,
                            color: _dryRaw != null ? AppColors.forest : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => _dryRaw = liveRaw),
                    child: const Text('Capture dry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Step 2: Wet in water
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sageBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 2: Put probe in water to line',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _wetRaw != null ? 'Captured wet: $_wetRaw' : 'Not captured',
                          style: TextStyle(
                            fontSize: 12,
                            color: _wetRaw != null ? AppColors.forest : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => _wetRaw = liveRaw),
                    child: const Text('Capture wet'),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.alert, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await controller.calibrate(reset: true);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Reset to defaults'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : () async {
                      if (_dryRaw == null || _wetRaw == null) {
                        setState(() => _error = 'Please capture both dry and wet readings');
                        return;
                      }
                      if ((_dryRaw! - _wetRaw!).abs() < 500) {
                        setState(() => _error =
                            'Values too close. Check the probe is fully dry, then fully wet');
                        return;
                      }
                      setState(() {
                        _isSaving = true;
                        _error = null;
                      });
                      final ok = await controller.calibrate(
                        dryRaw: _dryRaw,
                        wetRaw: _wetRaw,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Calibration saved successfully'
                                : 'Failed to save calibration'),
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
