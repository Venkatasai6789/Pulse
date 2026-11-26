import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/phi.dart';
import '../../data/api_service.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class LocationDetailScreen extends StatefulWidget {
  final String id;

  const LocationDetailScreen({super.key, required this.id});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  bool _isLoading = true;
  Location? _location;
  Assessment? _latestAssessment;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    final api = context.read<ApiService>();
    try {
      final loc = await api.getLocation(widget.id);
      final latest = await api.latestAssessment(widget.id);

      if (mounted) {
        setState(() {
          _location = loc;
          _latestAssessment = latest;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Location Details',
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
        body: const Center(child: LeafLoader()),
      );
    }

    final locName = _location?.name ?? 'Location Details';
    final locAddress = _location?.address ?? '';
    final phiVal = _latestAssessment?.result?.phi;
    final tierVal = _latestAssessment?.result?.tier ?? Tier.protect;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.pop(),
        ),
        title: Text(
          locName,
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PulseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locName,
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (locAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locAddress,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Monitored pollinator site with historical health records.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: PhiGauge(
                        phi: phiVal ?? 0,
                        size: 200,
                        label: 'Latest PHI',
                      ),
                    ),
                    if (phiVal != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TierBadge(
                          tier: tierVal,
                          showCategory: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSensorNodeCard(context),
              const SizedBox(height: 16),
              if (_latestAssessment != null) ...[
                PressableScale(
                  onTap: () => context.push('/results/${_latestAssessment!.id}'),
                  child: FilledButton.icon(
                    onPressed: () => context.push('/results/${_latestAssessment!.id}'),
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('View Latest Assessment Results'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PressableScale(
                onTap: () => context.go('/monitor?locationId=${widget.id}'),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/monitor?locationId=${widget.id}'),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Start Assessment For This Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorNodeCard(BuildContext context) {
    final controller = context.watchSensorNode();
    if (controller == null) return const SizedBox.shrink();
    final node = controller.node;
    final isLinked = node != null && node.linkedLocationId == widget.id;

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sensors_rounded, size: 18, color: AppColors.forest),
                  const SizedBox(width: 8),
                  Text(
                    'Sensor node',
                    style: GoogleFonts.lora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (isLinked)
                TextButton(
                  onPressed: () async {
                    await controller.unlinkLocation();
                  },
                  child: const Text('Unlink', style: TextStyle(color: AppColors.alert)),
                )
              else
                TextButton(
                  onPressed: () async {
                    if (node != null) {
                      await controller.linkLocation(widget.id, _location?.name ?? 'Site');
                    } else {
                      context.push('/sensor/pair');
                    }
                  },
                  child: Text(node != null ? 'Link sensor node' : 'Pair a node'),
                ),
            ],
          ),
          if (isLinked) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${node.name} · ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SensorStatusDot(state: controller.state),
                if (controller.state == NodeConnection.online &&
                    controller.latest != null) ...[
                  Text(
                    ' · ${controller.latest!.soil.percent.toInt()} %',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.leaf,
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'No sensor node linked to this location.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
