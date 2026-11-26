import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/soil.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../theme/app_theme.dart';
import 'sensor_status_dot.dart';
import 'soil_moisture_bar.dart';
import 'soil_value_block.dart';

/// The live field sensor summary card placed on the Home screen.
class FieldSensorCard extends StatefulWidget {
  const FieldSensorCard({super.key});

  @override
  State<FieldSensorCard> createState() => _FieldSensorCardState();
}

class _FieldSensorCardState extends State<FieldSensorCard> {
  static const String _kDismissedKey = 'field_sensor_card_dismissed';
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dismissed = prefs.getBool(_kDismissedKey) ?? false;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDismissedKey, true);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  Color _tierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'PROTECT':
        return const Color(0xFF2E7D32);
      case 'ENHANCE':
        return const Color(0xFF7CB342);
      case 'IMPROVE':
        return const Color(0xFFF9A825);
      case 'RESTORE':
        return const Color(0xFFEF6C00);
      case 'INVESTIGATE':
      default:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watchSensorNode();
    if (controller == null) return const SizedBox.shrink();
    final node = controller.node;
    final state = controller.state;

    // 1. Unpaired state
    if (!controller.hasActiveNode || state == NodeConnection.notPaired) {
      if (_dismissed) return const SizedBox.shrink();

      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.sageBorder),
        ),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.sage,
                child: Icon(Icons.sensors_rounded, size: 20, color: AppColors.forest),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a field sensor for live soil moisture',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/sensor/pair'),
                child: const Text('Set up', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                onPressed: _dismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Paired state
    final latest = controller.latest;
    final soil = latest?.soil;
    final pct = soil?.percent ?? 0.0;
    final status = soil?.status ?? SoilStatus.optimal;

    // Subtitle text: Node name · Location name
    final subtitle = [
      node!.name,
      if (node.linkedLocationName != null && node.linkedLocationName!.isNotEmpty)
        node.linkedLocationName!
    ].join(' · ');

    // Last update string
    String ageStr = '';
    if (controller.lastUpdated != null) {
      final diff = DateTime.now().difference(controller.lastUpdated!).inSeconds;
      ageStr = diff < 10 ? ' · ${diff}s' : ' · ${diff ~/ 60}m';
    }

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.sageBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors_rounded, size: 18, color: AppColors.forest),
                    const SizedBox(width: 6),
                    Text(
                      'Field sensor',
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SensorStatusDot(state: state),
                    if (state == NodeConnection.online && ageStr.isNotEmpty)
                      Text(
                        ageStr,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.leaf),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),

            // Value / Status Display
            if (state == NodeConnection.fault) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.alertSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Probe not detected. Check the A0 wire to GPIO 34.',
                  style: TextStyle(color: AppColors.alert, fontSize: 13),
                ),
              ),
            ] else if (state == NodeConnection.offline || state == NodeConnection.stale) ...[
              Opacity(
                opacity: 0.5,
                child: Column(
                  children: [
                    SoilValueBlock(percent: pct, status: status),
                    const SizedBox(height: 8),
                    SoilMoistureBar(percent: pct, status: status),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last reading ${ageStr.replaceAll(' · ', '')} ago',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  TextButton(
                    onPressed: controller.refresh,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ] else ...[
              SoilValueBlock(percent: pct, status: status),
              const SizedBox(height: 12),
              SoilMoistureBar(percent: pct, status: status),
            ],

            const SizedBox(height: 14),
            const Divider(color: AppColors.sageBorder, height: 1),
            const SizedBox(height: 10),

            // Bottom Footer Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: latest?.lastPhi != null && latest!.lastPhi!.phi > 0
                      ? RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
                            children: [
                              const TextSpan(text: 'On display: '),
                              TextSpan(
                                text: 'PHI ${latest.lastPhi!.phi.toInt()} · ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: latest.lastPhi!.tier,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tierColor(latest.lastPhi!.tier),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          'No recent assessment on display',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                        ),
                ),
                TextButton(
                  onPressed: () {
                    final locParam = node.linkedLocationId != null
                        ? '?locationId=${node.linkedLocationId}'
                        : '';
                    context.push('/monitor$locParam');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    padding: const EdgeInsets.only(left: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Assess this site',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
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
