import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/soil.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../theme/app_theme.dart';
import 'sensor_status_dot.dart';
import 'soil_moisture_bar.dart';
import 'soil_value_block.dart';

/// Modal bottom sheet showing live node telemetry and quick actions.
class SensorDetailSheet extends StatelessWidget {
  const SensorDetailSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SensorDetailSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watchSensorNode();
    final node = controller?.node;
    final latest = controller?.latest;
    final state = controller?.state ?? NodeConnection.notPaired;

    if (node == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Text('No sensor node paired.'),
      );
    }

    final soil = latest?.soil;
    final pct = soil?.percent ?? 0.0;
    final status = soil?.status ?? SoilStatus.optimal;

    // Time since last update
    String updateTimeStr = 'Just now';
    if (controller?.lastUpdated != null) {
      final diff = DateTime.now().difference(controller!.lastUpdated!).inSeconds;
      updateTimeStr = diff < 5 ? 'Just now' : '${diff}s ago';
    }

    final lastPhi = latest?.lastPhi;
    String displayPhiStr = 'None';
    if (lastPhi != null && lastPhi.phi > 0) {
      displayPhiStr = 'PHI ${lastPhi.phi.toInt()} · ${lastPhi.tier}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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

            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: GoogleFonts.lora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                SensorStatusDot(state: state),
              ],
            ),
            const SizedBox(height: 16),

            // Live Soil Section
            if (state == NodeConnection.online || state == NodeConnection.stale) ...[
              SoilValueBlock(percent: pct, status: status),
              const SizedBox(height: 12),
              SoilMoistureBar(percent: pct, status: status),
              const SizedBox(height: 16),
            ] else if (state == NodeConnection.fault) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.alertSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.alert.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Probe not detected. Check the A0 wire to GPIO 34.',
                  style: TextStyle(color: AppColors.alert, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(color: AppColors.sageBorder),
            const SizedBox(height: 10),

            // Key/value details
            _buildDetailRow('Raw ADC', '${soil?.raw ?? "—"}'),
            _buildDetailRow('Signal', '${latest?.net.rssi ?? -60} dBm'),
            _buildDetailRow(
              'Network',
              '${latest?.net.ssid ?? (node.mode == "ap" ? "Direct AP" : "Wi-Fi")} · ${node.host}',
            ),
            _buildDetailRow('Firmware', 'v${node.fw}'),
            _buildDetailRow(
              'Linked location',
              node.linkedLocationName ?? 'None',
            ),
            _buildDetailRow('Last update', updateTimeStr),
            _buildDetailRow('Shown on display', displayPhiStr),

            const SizedBox(height: 24),

            // Actions
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final locParam = node.linkedLocationId != null
                    ? '?locationId=${node.linkedLocationId}'
                    : '';
                context.push('/monitor$locParam');
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start assessment here'),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await controller?.identify() ?? false;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Display flashed'
                                : 'Failed to reach node'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('Identify node'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
