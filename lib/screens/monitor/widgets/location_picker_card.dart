import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/phi.dart';
import '../../../hardware/models/node_connection.dart';
import '../../../hardware/sensor_node_controller.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';

class LocationPickerCard extends StatelessWidget {
  final List<Location> locations;
  final Map<String, int?> latestPhis;
  final String? selectedLocationId;
  final ValueChanged<String> onLocationSelected;
  final VoidCallback onLocationCreated;
  final bool hasError;

  const LocationPickerCard({
    super.key,
    required this.locations,
    required this.latestPhis,
    required this.selectedLocationId,
    required this.onLocationSelected,
    required this.onLocationCreated,
    this.hasError = false,
  });

  Location? get selectedLocation =>
      locations.where((l) => l.id == selectedLocationId).firstOrNull;

  Widget _buildThumbnail(Location loc) {
    if (loc.photoPaths.isNotEmpty) {
      final p = loc.photoPaths.first;
      if (p.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(p, width: 44, height: 44, fit: BoxFit.cover),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(p), width: 44, height: 44, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackIcon()),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.park_outlined, color: AppColors.forest, size: 22),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sageBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.place_rounded, color: AppColors.forest),
                      const SizedBox(width: 8),
                      Text(
                        'Select Location',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.sageBorder),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: locations.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.sageBorder),
                    itemBuilder: (context, index) {
                      final loc = locations[index];
                      final isSelected = loc.id == selectedLocationId;
                      final phi = latestPhis[loc.id];

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        leading: _buildThumbnail(loc),
                        title: Text(
                          loc.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: Text(
                          loc.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (phi != null)
                              ScoreChip.forTier(tierFor(phi))
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'No PHI',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.forest)
                            else
                              const Icon(Icons.radio_button_unchecked_rounded,
                                  color: AppColors.sageBorder),
                          ],
                        ),
                        onTap: () {
                          onLocationSelected(loc.id);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.sageBorder),
                // Add new location row
                InkWell(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final newLocId = await context.push<String?>('/location/new');
                    onLocationCreated();
                    if (newLocId != null) {
                      onLocationSelected(newLocId);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: AppColors.forest, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '+ Add new location',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = selectedLocation;
    final phi = loc != null ? latestPhis[loc.id] : null;

    final sensorController = context.watchSensorNode();
    final node = sensorController?.node;
    final isLinkedOrActive = loc != null &&
        node != null &&
        (node.linkedLocationId == null || node.linkedLocationId == loc.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: hasError ? AppColors.alert : AppColors.sageBorder,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (loc != null) ...[
                  _buildThumbnail(loc),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 14, color: AppColors.forest),
                            const SizedBox(width: 4),
                            Text(
                              'Location *',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                loc.address,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (phi != null) ...[
                              const SizedBox(width: 6),
                              ScoreChip.forTier(
                                tierFor(phi),
                                compact: true,
                                score: phi,
                              ),
                            ],
                          ],
                        ),
                        if (isLinkedOrActive && sensorController != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              SensorStatusDot(state: sensorController.state),
                              if (sensorController.state == NodeConnection.online &&
                                  sensorController.latest != null)
                                Text(
                                  ' · ${sensorController.latest!.soil.percent.toInt()} %',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.leaf,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: AppColors.forest, size: 28),
                ] else ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasError
                          ? AppColors.alertSoft
                          : AppColors.sage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.place_rounded,
                      color: hasError ? AppColors.alert : AppColors.forest,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location *',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasError ? AppColors.alert : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select a location',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: hasError ? AppColors.alert : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: AppColors.forest, size: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
