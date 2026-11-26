import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_state.dart';
import '../../core/phi.dart';
import '../../core/recommendations.dart';
import '../../data/api_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../widgets/widgets.dart';
import 'widgets/activity_timeline.dart';
import 'widgets/assessment_cta.dart';
import 'widgets/community_highlight.dart';
import 'widgets/health_summary_card.dart';
import 'widgets/home_header.dart';
import 'widgets/location_card.dart';
import 'widgets/parameters_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/stat_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Location> _locations = [];
  Map<String, Assessment> _latestAssessments = {};
  List<Assessment> _allAssessments = [];
  Location? _draftLocation;

  // Computed overview metrics
  int _averagePhi = 0;
  int _healthyLocationsCount = 0;
  int? _deltaPhi;
  int _communityMemberCount = 1;
  List<ParameterData> _parameters = [];
  List<ActivityItem> _activities = [];
  Post? _upcomingEvent;
  Post? _latestPost;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    try {
      context.readSensorNode()?.refresh();
    } catch (_) {}

    try {
      final locations = await api.getLocations();
      final assessments = await api.getAssessments(submittedOnly: false);
      final posts = await api.getPosts();

      // Find latest assessment for each location
      final Map<String, Assessment> latestMap = {};
      final submittedAssessments = <Assessment>[];
      Assessment? draft;

      for (final a in assessments) {
        if (a.isSubmitted) {
          submittedAssessments.add(a);
          final locId = a.locationId;
          if (locId != null) {
            final aDate = a.submittedAt ?? a.createdAt;
            final existing = latestMap[locId];
            final existingDate = existing?.submittedAt ?? existing?.createdAt;
            if (existing == null || (existingDate != null && aDate.isAfter(existingDate))) {
              latestMap[locId] = a;
            }
          }
        } else {
          draft ??= a;
        }
      }

      Location? draftLoc;
      if (draft != null && draft.locationId != null) {
        draftLoc = locations.where((l) => l.id == draft!.locationId).firstOrNull;
      }

      // Compute Average PHI across locations with assessments
      int totalPhi = 0;
      int assessedCount = 0;
      int healthyCount = 0;

      for (final entry in latestMap.values) {
        final phiVal = entry.result?.phi;
        if (phiVal != null) {
          totalPhi += phiVal;
          assessedCount++;
          if (phiVal >= 60) {
            healthyCount++;
          }
        }
      }

      final avgPhi = assessedCount > 0 ? (totalPhi / assessedCount).round() : 0;

      // Compute Delta: latest vs previous submitted assessment
      int? delta;
      if (submittedAssessments.length >= 2) {
        submittedAssessments.sort((a, b) {
          final dateA = a.submittedAt ?? a.createdAt;
          final dateB = b.submittedAt ?? b.createdAt;
          return dateB.compareTo(dateA);
        });
        final latestPhi = submittedAssessments[0].result?.phi;
        final prevPhi = submittedAssessments[1].result?.phi;
        if (latestPhi != null && prevPhi != null) {
          delta = latestPhi - prevPhi;
        }
      }

      // Compute Community members = distinct authors + baseline
      final Set<String> authors = posts.map((p) => p.authorName).toSet();
      final memberCount = max(authors.length + 1, 14);

      // Compute Parameter averages across latest assessments
      double actSum = 0, habSum = 0, envSum = 0;
      int riskSum = 0;
      int paramCount = 0;

      for (final a in latestMap.values) {
        final res = a.result;
        if (res != null) {
          actSum += res.activity;
          habSum += res.habitat;
          envSum += res.environmental;
          riskSum += res.risk;
          paramCount++;
        }
      }

      final int? avgAct = paramCount > 0 ? (actSum / paramCount).round() : null;
      final int? avgHab = paramCount > 0 ? (habSum / paramCount).round() : null;
      final int? avgEnv = paramCount > 0 ? (envSum / paramCount).round() : null;
      final int? avgRisk = paramCount > 0 ? (riskSum / paramCount).round() : null;

      final hasSoil = assessments.any((a) => a.soil != null || a.result?.soil != null);

      final parameters = [
        ParameterData(
          title: 'Pollinator Activity',
          weight: '30%',
          score: avgAct,
          label: _labelForScore(avgAct, 'Good', 'Moderate', 'Low'),
          labelColor: _colorForScore(avgAct),
          icon: Icons.pest_control_outlined,
          iconColor: const Color(0xFFE65100),
        ),
        ParameterData(
          title: 'Habitat Quality',
          weight: '30%',
          score: avgHab,
          label: _labelForScore(avgHab, 'Good', 'Moderate', 'Poor'),
          labelColor: _colorForScore(avgHab),
          icon: Icons.local_florist_outlined,
          iconColor: const Color(0xFFF57C00),
        ),
        ParameterData(
          title: 'Environmental',
          weight: '20%',
          score: avgEnv,
          label: _labelForScore(avgEnv, 'Ideal', 'Moderate', 'Stressful'),
          labelColor: _colorForScore(avgEnv),
          icon: Icons.thermostat_outlined,
          iconColor: const Color(0xFF0288D1),
          caption: hasSoil ? 'Includes soil moisture' : null,
        ),
        ParameterData(
          title: 'Potential Risks',
          weight: '20%',
          score: avgRisk,
          label: _labelForScore(avgRisk, 'Low Risk', 'Moderate', 'High Risk'),
          labelColor: _colorForScore(avgRisk),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFD32F2F),
        ),
      ];

      // Assemble recent activities
      final activities = <ActivityItem>[];
      for (final a in submittedAssessments.take(3)) {
        final loc = locations.where((l) => l.id == a.locationId).firstOrNull;
        final phiVal = a.result?.phi ?? 0;
        final tier = tierFor(phiVal);
        final aDate = a.submittedAt ?? a.createdAt;
        activities.add(
          ActivityItem(
            title: 'Assessment submitted · ${loc?.name ?? "Monitored Site"}',
            detail: 'PHI $phiVal · ${tierInfo[tier]!.label}',
            date: aDate,
            dotColor: Color(tierInfo[tier]!.colorHex),
          ),
        );
      }

      // Add recent location if space in activities
      if (activities.length < 3 && locations.isNotEmpty) {
        final newestLoc = locations.first;
        activities.add(
          ActivityItem(
            title: 'Location registered · ${newestLoc.name}',
            detail: newestLoc.type,
            date: newestLoc.createdAt,
            dotColor: AppColors.forest,
          ),
        );
      }
      activities.sort((a, b) => b.date.compareTo(a.date));

      // Community highlight: upcoming event or latest post
      final now = DateTime.now();
      Post? event;
      for (final p in posts) {
        if (p.category == PostCategory.event && p.eventDate != null && p.eventDate!.isAfter(now)) {
          event = p;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _locations = locations;
          _latestAssessments = latestMap;
          _allAssessments = assessments;
          _draftLocation = draftLoc;
          _averagePhi = avgPhi;
          _healthyLocationsCount = healthyCount;
          _deltaPhi = delta;
          _communityMemberCount = memberCount;
          _parameters = parameters;
          _activities = activities;
          _upcomingEvent = event;
          _latestPost = posts.isNotEmpty ? posts.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _labelForScore(int? score, String high, String mid, String low) {
    if (score == null) return 'No data';
    if (score >= 80) return high;
    if (score >= 60) return mid;
    return low;
  }

  Color _colorForScore(int? score) {
    if (score == null) return AppColors.muted;
    if (score >= 80) return const Color(0xFF1E4D2B);
    if (score >= 60) return const Color(0xFF7CB342);
    return const Color(0xFFF57C00);
  }

  Widget _buildStaggeredSection(Widget child, int index) {
    return child
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: 50 * index),
        )
        .slideY(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutQuad,
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: 50 * index),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.currentUser;
    final hasData = _allAssessments.any((a) => a.isSubmitted);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.forest,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Header (SliverAppBar, pinned, collapses on scroll)
            HomeHeader(user: user),

            // Main body slivers
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading) ...[
                    _buildLoadingShimmer(),
                  ] else ...[
                    // 2. Pollinator Health Summary Card
                    _buildStaggeredSection(
                      HealthSummaryCard(
                        averagePhi: _averagePhi,
                        healthyLocationsCount: _healthyLocationsCount,
                        totalLocationsCount: _locations.length,
                        deltaPhi: _deltaPhi,
                        hasData: hasData,
                      ),
                      0,
                    ),

                    const SizedBox(height: 16),
                    _buildStaggeredSection(
                      const FieldSensorCard(),
                      1,
                    ),

                    const SizedBox(height: 24),

                    // 3. Key stats 2x2 grid (height ≈ 96)
                    _buildStaggeredSection(
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.location_on_outlined,
                              value: '${_locations.length}',
                              label: 'Total Locations',
                              caption: _locations.isNotEmpty ? '+1 this month' : '—',
                              onTap: () => context.go('/locations'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.assignment_outlined,
                              value: '${_allAssessments.where((a) => a.isSubmitted).length}',
                              label: 'Total Assessments',
                              caption: hasData ? 'Active surveys' : '—',
                              onTap: () => context.push('/reports'),
                            ),
                          ),
                        ],
                      ),
                      1,
                    ),
                    const SizedBox(height: 12),
                    _buildStaggeredSection(
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.speed_outlined,
                              value: hasData ? '$_averagePhi' : '—',
                              label: 'Average PHI',
                              caption: hasData ? tierInfo[tierFor(_averagePhi)]!.label : 'No data yet',
                              onTap: () => context.push('/reports'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.people_outline_rounded,
                              value: '$_communityMemberCount',
                              label: 'Community Members',
                              caption: 'Active stewards',
                              onTap: () => context.go('/community'),
                            ),
                          ),
                        ],
                      ),
                      2,
                    ),

                    const SizedBox(height: 24),

                    // 4. Start a New Assessment CTA Card
                    _buildStaggeredSection(
                      AssessmentCtaCard(
                        draftLocationName: _draftLocation?.name,
                        draftLocationId: _draftLocation?.id,
                      ),
                      3,
                    ),

                    const SizedBox(height: 24),

                    // 5. Your Locations with "View all →"
                    _buildStaggeredSection(
                      SectionHeader(
                        title: 'Your Locations',
                        actionText: 'View all →',
                        onActionTap: () => context.go('/locations'),
                        padding: const EdgeInsets.only(bottom: 12),
                      ),
                      4,
                    ),
                    Builder(
                      builder: (context) {
                        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                        final cardHeight = (212.0 * textScale).clamp(210.0, 240.0);
                        final screenWidth = MediaQuery.of(context).size.width;
                        final cardWidth = screenWidth > 600 ? 260.0 : 230.0;

                        return _buildStaggeredSection(
                          SizedBox(
                            height: cardHeight,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: _locations.length + 1,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                if (index < _locations.length) {
                                  final loc = _locations[index];
                                  final latest = _latestAssessments[loc.id];
                                  return HomeLocationCard(
                                    location: loc,
                                    latestAssessment: latest,
                                    width: cardWidth,
                                  );
                                } else {
                                  return AddLocationCard(
                                    width: _locations.isEmpty ? cardWidth : 170,
                                  );
                                }
                              },
                            ),
                          ),
                          5,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 6. The Four Parameters (one card containing 4 compact rows)
                    _buildStaggeredSection(
                      const SectionHeader(
                        title: 'The Four Parameters',
                        subtitle: 'Averaged across latest assessments',
                        padding: EdgeInsets.only(bottom: 12),
                      ),
                      6,
                    ),
                    _buildStaggeredSection(
                      ParametersCard(
                        parameters: _parameters,
                        hasData: hasData,
                      ),
                      7,
                    ),

                    const SizedBox(height: 24),

                    // 7. Quick Actions
                    _buildStaggeredSection(
                      const SectionHeader(
                        title: 'Quick Actions',
                        padding: EdgeInsets.only(bottom: 12),
                      ),
                      8,
                    ),
                    _buildStaggeredSection(
                      const QuickActionsRow(),
                      9,
                    ),

                    const SizedBox(height: 24),

                    // 8. Recent Activity with "View all →"
                    _buildStaggeredSection(
                      SectionHeader(
                        title: 'Recent Activity',
                        actionText: 'View all →',
                        onActionTap: () => context.push('/reports'),
                        padding: const EdgeInsets.only(bottom: 12),
                      ),
                      10,
                    ),
                    _buildStaggeredSection(
                      ActivityTimeline(items: _activities),
                      11,
                    ),

                    const SizedBox(height: 24),

                    // 9. From the community
                    _buildStaggeredSection(
                      SectionHeader(
                        title: 'From the community',
                        actionText: 'Open community →',
                        onActionTap: () => context.go('/community'),
                        padding: const EdgeInsets.only(bottom: 12),
                      ),
                      12,
                    ),
                    _buildStaggeredSection(
                      CommunityHighlightCard(
                        eventPost: _upcomingEvent,
                        latestPost: _latestPost,
                      ),
                      13,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: index == 0 ? 160 : 100,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.sageBorder),
          ),
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(
              duration: const Duration(milliseconds: 1200),
              color: AppColors.sage.withValues(alpha: 0.5),
            );
      }),
    );
  }
}
