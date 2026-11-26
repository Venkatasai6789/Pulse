import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/soil.dart';
import '../../core/soil_reading.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/models/node_reading.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'soil_moisture_bar.dart';
import 'soil_value_block.dart';

/// Step 3 Soil Moisture panel supporting live ESP32 node capture and manual fallback.
class SoilSensorPanel extends StatefulWidget {
  final Assessment draft;
  final ValueChanged<Assessment> onDraftChanged;

  const SoilSensorPanel({
    super.key,
    required this.draft,
    required this.onDraftChanged,
  });

  @override
  State<SoilSensorPanel> createState() => _SoilSensorPanelState();
}

class _SoilSensorPanelState extends State<SoilSensorPanel> {
  late final TextEditingController _manualController;
  String? _manualError;
  DateTime? _shownAt;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();
    final currentSoil = widget.draft.soil;
    _manualController = TextEditingController(
      text: (currentSoil != null && currentSoil.source == SoilSource.manual)
          ? (currentSoil.percent % 1 == 0
              ? currentSoil.percent.toInt().toString()
              : currentSoil.percent.toString())
          : '',
    );

    // Acquire hardware polling while this panel is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.readSensorNode()?.acquire();
      }
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    // Release hardware polling
    try {
      context.readSensorNode()?.release();
    } catch (_) {}
    super.dispose();
  }

  void _onManualChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() => _manualError = null);
      widget.onDraftChanged(widget.draft.copyWith(soil: null));
      return;
    }

    final numVal = double.tryParse(val.trim());
    if (numVal == null || numVal < 0 || numVal > 100) {
      setState(() => _manualError = 'Must be between 0 and 100%');
      widget.onDraftChanged(widget.draft.copyWith(soil: null));
    } else {
      setState(() => _manualError = null);
      final reading = SoilReading(
        percent: numVal,
        status: soilStatusFor(numVal),
        source: SoilSource.manual,
        capturedAt: DateTime.now(),
      );
      widget.onDraftChanged(widget.draft.copyWith(soil: reading));
    }
  }

  Future<void> _captureFromSensor() async {
    final controller = context.readSensorNode();
    if (controller == null) return;
    final reading = await controller.capture();
    if (reading != null) {
      widget.onDraftChanged(widget.draft.copyWith(soil: reading));
      _manualController.clear();
      setState(() => _manualError = null);
    }
  }

  void _removeReading() {
    widget.onDraftChanged(widget.draft.copyWith(soil: null));
    _manualController.clear();
    setState(() => _manualError = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watchSensorNode();
    final state = controller?.state ?? NodeConnection.notPaired;
    final node = controller?.node;
    final latest = controller?.latest;
    final capturedSoil = widget.draft.soil;

    final isCaptured = capturedSoil != null;
    final isManual = capturedSoil?.source == SoilSource.manual;
    final isNodeAvailable = controller != null &&
        controller.hasActiveNode &&
        (state == NodeConnection.online || state == NodeConnection.stale);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isCaptured ? AppColors.forest : AppColors.sageBorder,
          width: isCaptured ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Title Row: Icon + Soil moisture (%) + Optional · 0 to 100 %
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: Color(0xFF0288D1),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Soil moisture (%)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Text(
                'Optional · 0 to 100 %',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Body based on capture & connection states
          if (isCaptured && !isManual) ...[
            // Captured State from ESP32 Node
            _buildCapturedState(capturedSoil, latest),
          ] else if (isNodeAvailable && latest != null) ...[
            // Node Online, not yet captured
            _buildOnlineNotCapturedState(controller, node, latest),
          ] else if (state == NodeConnection.fault) ...[
            // Fault state
            _buildFaultState(),
          ] else ...[
            // Not paired or Offline -> Manual fallback
            _buildManualFallback(state),
          ],
        ],
      ),
    );
  }

  Widget _buildCapturedState(SoilReading captured, NodeReading? liveLatest) {
    final timeStr = DateFormat('HH:mm').format(captured.capturedAt);
    final statusName = soilLabel(captured.status);
    final displayVal = captured.percent.toStringAsFixed(captured.percent % 1 == 0 ? 0 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.forest, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Captured $timeStr · $displayVal% · $statusName',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
              ),
              TextButton(
                onPressed: _captureFromSensor,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _removeReading,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.alert,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
        if (liveLatest != null) ...[
          const SizedBox(height: 8),
          Text(
            'Now ${liveLatest.soil.percent.toStringAsFixed(liveLatest.soil.percent % 1 == 0 ? 0 : 1)} %',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _buildOnlineNotCapturedState(
    SensorNodeController controller,
    dynamic node,
    NodeReading latest,
  ) {
    final pct = latest.soil.percent;
    final status = latest.soil.status;
    final isStable = latest.soil.stable;
    final raw = latest.soil.raw;

    // Enable capture if stable & ok, or after 3s settling grace window
    final elapsedSec = _shownAt != null
        ? DateTime.now().difference(_shownAt!).inSeconds
        : 0;
    final canCapture = (isStable || elapsedSec >= 3) && latest.isSensorOk && latest.isFresh;

    final ageSec = latest.sampleAgeMs ~/ 1000;
    final metaStr = '${node.name} · Raw $raw · updated ${ageSec < 1 ? "just now" : "${ageSec}s ago"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoilValueBlock(percent: pct, status: status),
        const SizedBox(height: 10),
        SoilMoistureBar(percent: pct, status: status),
        const SizedBox(height: 8),

        Text(
          metaStr,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
        ),

        if (!isStable) ...[
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.hourglass_empty_rounded, size: 14, color: AppColors.honey),
              SizedBox(width: 4),
              Text(
                'Reading is still settling. Wait a few seconds.',
                style: TextStyle(color: Color(0xFFE65100), fontSize: 12),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: canCapture ? _captureFromSensor : null,
          icon: const Icon(Icons.sensors_rounded, size: 18),
          label: const Text('Use sensor reading'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.forest),
            foregroundColor: AppColors.forest,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildFaultState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 12),
        _buildManualInput(),
      ],
    );
  }

  Widget _buildManualFallback(NodeConnection state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'No live sensor. Enter soil moisture manually or pair a node.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/sensor/pair'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Pair a node', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildManualInput(),
      ],
    );
  }

  Widget _buildManualInput() {
    final currentSoil = widget.draft.soil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _manualController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 45',
            suffixText: '%',
            suffixStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.forest),
            errorText: _manualError,
          ),
          onChanged: _onManualChanged,
        ),
        if (currentSoil != null && _manualError == null) ...[
          const SizedBox(height: 8),
          _buildStatusChip(soilScore(currentSoil.percent).toInt(), 'Suitable 40–60%'),
        ],
      ],
    );
  }

  Widget _buildStatusChip(int score, String rangeHint) {
    final (label, color, bg) = switch (score) {
      100 => ('Suitable', AppColors.forest, AppColors.sage),
      60 => ('Moderate', const Color(0xFFE65100), const Color(0xFFFFECC8)),
      _ => ('Stressful', AppColors.alert, AppColors.alertSoft),
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            rangeHint,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
