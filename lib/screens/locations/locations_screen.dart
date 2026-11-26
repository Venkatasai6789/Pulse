import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/api_service.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Location> _locations = [];
  Map<String, Assessment> _latestMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    try {
      final locs = await api.getLocations();
      final assessments = await api.getAssessments(submittedOnly: false);

      final Map<String, Assessment> latest = {};
      for (final a in assessments) {
        if (a.isSubmitted && a.locationId != null) {
          final aDate = a.submittedAt ?? a.createdAt;
          final existing = latest[a.locationId!];
          final existingDate = existing?.submittedAt ?? existing?.createdAt;
          if (existing == null || (existingDate != null && aDate.isAfter(existingDate))) {
            latest[a.locationId!] = a;
          }
        }
      }

      if (mounted) {
        setState(() {
          _locations = locs;
          _latestMap = latest;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatAssessedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(aDate).inDays;

    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return '$diffDays days ago';
    return DateFormat('d MMM').format(date);
  }

  Widget _buildThumbnail(Location loc) {
    if (loc.photoPaths.isNotEmpty) {
      final path = loc.photoPaths.first;
      if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackIcon(loc),
        );
      } else {
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackIcon(loc),
        );
      }
    }
    return _fallbackIcon(loc);
  }

  Widget _fallbackIcon(Location loc) {
    IconData icon = Icons.park_outlined;
    final typeLower = loc.type.toLowerCase();
    if (typeLower.contains('house') || typeLower.contains('garden')) {
      icon = Icons.home_outlined;
    } else if (typeLower.contains('park') || typeLower.contains('reserve')) {
      icon = Icons.nature_people_outlined;
    }
    return Center(child: Icon(icon, color: AppColors.forest, size: 28));
  }

  @override
  Widget build(BuildContext context) {
    final sensorController = context.watchSensorNode();
    final linkedLocationId = sensorController?.node?.linkedLocationId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Monitored Locations',
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: LeafLoader())
              : _locations.isEmpty
                  ? EmptyState(
                      icon: Icons.location_on_outlined,
                      title: 'No locations yet',
                      subtitle: 'Add your first monitored garden or habitat site.',
                      actionLabel: 'Add Location',
                      onAction: () async {
                        await context.push('/location/new');
                        _loadData();
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.forest,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: _locations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final loc = _locations[index];
                          final latestAssessment = _latestMap[loc.id];
                          final result = latestAssessment?.result;
                          final hasPhi = result != null;
                          final lastDate = latestAssessment?.submittedAt ?? latestAssessment?.createdAt;

                          return PulseCard(
                            onTap: () async {
                              await context.push('/location/${loc.id}');
                              _loadData();
                            },
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.sage,
                                    child: _buildThumbnail(loc),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              loc.name,
                                              style: GoogleFonts.lora(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (linkedLocationId == loc.id) ...[
                                            const SizedBox(width: 6),
                                            Semantics(
                                              label: 'Sensor linked',
                                              child: const Icon(
                                                Icons.sensors_rounded,
                                                size: 16,
                                                color: AppColors.forest,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        loc.address,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          hasPhi
                                              ? ScoreChip.forTier(
                                                  result.tier,
                                                  score: result.phi,
                                                  compact: true,
                                                )
                                              : const ScoreChip(
                                                  label: 'No PHI yet',
                                                  compact: true,
                                                ),
                                          if (lastDate != null)
                                            Text(
                                              _formatAssessedDate(lastDate),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.muted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.forestDark,
          foregroundColor: Colors.white,
          onPressed: () async {
            await context.push('/location/new');
            _loadData();
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Location'),
        ),
      ),
    );
  }
}
