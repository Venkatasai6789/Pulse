import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/phi.dart';
import '../../data/api_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Assessment> _assessments = [];
  Map<String, Location> _locationMap = {};
  int _averagePhi = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    try {
      final assessments = await api.getAssessments(submittedOnly: true);
      final locations = await api.getLocations();
      final locMap = {for (final l in locations) l.id: l};

      int totalPhi = 0;
      int count = 0;
      for (final a in assessments) {
        final p = a.result?.phi;
        if (p != null) {
          totalPhi += p;
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _assessments = assessments;
          _locationMap = locMap;
          _averagePhi = count > 0 ? (totalPhi / count).round() : 0;
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
          'Reports & Analytics',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: LeafLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PulseCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historical PHI Performance',
                            style: GoogleFonts.lora(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Compare Pollinator Health Index trends across assessments and track environmental restoration progress.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: PhiGauge(
                              phi: _averagePhi,
                              size: 190,
                              label: 'Average Score',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'Past Assessments'),
                    const SizedBox(height: 8),
                    if (_assessments.isEmpty)
                      const EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No Assessments Yet',
                        subtitle: 'Complete an observation to see results here.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _assessments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final a = _assessments[idx];
                          final loc = a.locationId != null ? _locationMap[a.locationId!] : null;
                          final locName = loc?.name ?? 'Assessed Site';
                          final phiVal = a.result?.phi ?? 0;
                          final tierVal = a.result?.tier ?? Tier.protect;
                          final dt = a.submittedAt ?? a.createdAt;
                          final formattedDate = DateFormat('d MMM y').format(dt);

                          return PulseCard(
                            onTap: () => context.push('/results/${a.id}'),
                            child: Row(
                              children: [
                                const Icon(Icons.assessment_outlined, color: AppColors.forest),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        locName,
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '$formattedDate • $phiVal PHI',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                ScoreChip.forTier(tierVal, compact: true),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
