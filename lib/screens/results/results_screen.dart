import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../ai/ai_service.dart';
import '../../core/phi.dart';
import '../../core/recommendations.dart';
import '../../core/score_format.dart';
import '../../core/soil_reading.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../data/api_service.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class ResultsScreen extends StatefulWidget {
  final String id;

  const ResultsScreen({super.key, required this.id});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  bool _isGeneratingAi = false;
  Assessment? _assessment;
  Location? _location;
  List<Assessment> _trendAssessments = [];

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  @override
  void didUpdateWidget(covariant ResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _loadAssessment();
    }
  }

  Future<void> _loadAssessment() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    try {
      final a = await api.getAssessment(widget.id);
      if (a == null) {
        if (mounted) {
          setState(() {
            _assessment = null;
            _location = null;
            _trendAssessments = [];
            _isLoading = false;
          });
        }
        return;
      }

      Location? loc;
      List<Assessment> history = [];
      if (a.locationId != null) {
        loc = await api.getLocation(a.locationId!);
        history = await api.getAssessments(
          locationId: a.locationId,
          submittedOnly: true,
        );
        history.sort((x, y) =>
            (x.submittedAt ?? x.createdAt).compareTo(y.submittedAt ?? y.createdAt));
      }

      if (mounted) {
        setState(() {
          _assessment = a;
          _location = loc;
          _trendAssessments = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _assessment = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateAiInsights(Assessment assessment) async {
    setState(() {
      _isGeneratingAi = true;
    });

    try {
      final insight = await AiService.instance.generateAssessmentInsights(assessment);
      if (!mounted) return;
      final api = context.read<ApiService>();
      final updated = await api.updateAssessmentAi(assessment.id, insight);
      if (mounted) {
        setState(() {
          _assessment = updated;
          _isGeneratingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
        final msg = e is AiException ? e.message : kAiFallbackMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  String _fmt(double s) =>
      s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(1);

  String _riskLevelStr(RiskLevel l) => switch (l) {
        RiskLevel.low => 'Low',
        RiskLevel.moderate => 'Moderate',
        RiskLevel.high => 'High',
      };

  static Widget _emptyTitles(double val, TitleMeta meta) => const SizedBox.shrink();

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
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          title: Text(
            'Assessment Results',
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
        body: SafeArea(
          child: _buildSkeleton(),
        ),
      );
    }

    if (_assessment == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          title: Text(
            'Assessment Results',
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Result not found',
                subtitle:
                    'The requested assessment could not be found or may have been deleted.',
                actionLabel: 'Back to Home',
                onAction: () => context.go('/'),
              ),
            ),
          ),
        ),
      );
    }

    final assessment = _assessment!;
    final inputs = assessment.isComplete
        ? assessment.toInputs()
        : AssessmentInputs(
            visits: assessment.visits ?? 0,
            durationMinutes: assessment.durationMinutes ?? 5,
            flowers: assessment.flowers ?? Level.medium,
            nesting: assessment.nesting ?? Level.medium,
            shelter: assessment.shelter ?? Level.medium,
            water: assessment.water ?? Water.present,
            temperatureC: assessment.temperatureC ?? 25.0,
            humidityPct: assessment.humidityPct ?? 50.0,
            co2Ppm: assessment.co2Ppm ?? 400.0,
            risk: assessment.riskIndicators,
            riskLevel: assessment.riskLevel ?? RiskLevel.low,
            soil: assessment.soil,
            soilMoisturePercent: assessment.soil?.percent,
          );
    final result = assessment.result ?? calculatePhi(inputs);
    final tier = tierInfo[result.tier]!;
    final obsDate =
        assessment.observedAt ?? assessment.submittedAt ?? assessment.createdAt;
    final formattedDateTime =
        DateFormat("d MMM y · h:mm a").format(obsDate);
    final weatherText = assessment.weather ?? 'Sunny';
    final locationName = _location?.name ?? 'Monitored Site';
    final steps = nextSteps(inputs, result);

    final List<String> allPhotos = [
      ...assessment.activityPhotoPaths.where((p) => p.isNotEmpty),
      ...assessment.riskPhotoPaths.where((p) => p.isNotEmpty),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Assessment Results',
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
              // Header: location name, date & time, weather
              _buildHeader(locationName, formattedDateTime, weatherText),
              const SizedBox(height: 16),

              // High Risk alert banner (if result.highRiskAlert)
              if (result.highRiskAlert) ...[
                _buildHighRiskBanner(),
                const SizedBox(height: 16),
              ],

              // Gauge Card: Gauge + Tier Badge + Tier label + category name + recommendation
              _buildGaugeCard(result, tier),
              const SizedBox(height: 16),

              // "Why this score?" card from explainScore()
              _buildWhyThisScoreCard(inputs, result),
              const SizedBox(height: 20),

              // Parameter breakdown: 4 full-width rows
              const SectionHeader(title: 'Parameter Breakdown'),
              const SizedBox(height: 10),
              _buildParameterBreakdown(inputs, result, weatherText),
              const SizedBox(height: 16),

              // "How PHI is calculated" expandable showing real numbers
              _buildHowCalculatedExpandable(result),
              const SizedBox(height: 20),

              // "What to do next?" from nextSteps()
              _buildNextStepsCard(steps),
              const SizedBox(height: 20),

              // "AI insights" card below "What to do next?"
              _buildAiInsightsCard(assessment),
              const SizedBox(height: 20),

              // Assessment Photos gallery
              _buildPhotoGallery(allPhotos),
              const SizedBox(height: 20),

              // PHI trend for this location
              _buildLocationTrendCard(result),
              const SizedBox(height: 20),

              // "Record an action taken"
              _buildActionsSection(assessment),
              const SizedBox(height: 24),

              // Buttons: "View location" / "New assessment"
              _buildActionButtons(assessment),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Widget
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
      String locationName, String formattedDateTime, String weather) {
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.forest,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: GoogleFonts.lora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedDateTime · $weather',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // High Risk Banner (Red banner with warning icon)
  // ---------------------------------------------------------------------------
  Widget _buildHighRiskBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF9A9A), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFC62828),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Risk Alert',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'High risk observation recorded. A high overall PHI does not rule out a serious local concern. Consider investigating and reporting it.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFC62828),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main Gauge Card
  // ---------------------------------------------------------------------------
  Widget _buildGaugeCard(PhiResult result, TierInfo tier) {
    return PulseCard(
      child: Column(
        children: [
          PhiGauge(
            phi: result.phi,
            size: 230,
            animate: true,
            label: 'PHI',
          ),
          const SizedBox(height: 16),
          TierBadge(
            tier: result.tier,
            showCategory: false,
          ),
          const SizedBox(height: 12),
          Text(
            '${tier.label} · ${tier.categoryName}',
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(tier.colorHex),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tier.recommendation,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          Builder(
            builder: (ctx) {
              final controller = ctx.watchSensorNode();
              if (controller != null &&
                  controller.hasActiveNode &&
                  controller.latest?.lastPhi?.phi == result.phi.toDouble()) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Shown on sensor display',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "Why this score?" Card
  // ---------------------------------------------------------------------------
  Widget _buildWhyThisScoreCard(AssessmentInputs inputs, PhiResult result) {
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: AppColors.forest,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Why this score?',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            explainScore(inputs, result),
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parameter Breakdown (Four full-width rows)
  // ---------------------------------------------------------------------------
  Widget _buildParameterBreakdown(
      AssessmentInputs inputs, PhiResult result, String weather) {
    return Column(
      children: [
        _buildParameterRow(
          icon: Icons.pest_control_outlined,
          name: 'Pollinator Activity',
          weight: 'Weight 30%',
          score: result.activity,
          statusLabel: scoreBand(result.activity),
          detail: '${inputs.visits} visits in ${inputs.durationMinutes} min · $weather',
        ),
        const SizedBox(height: 12),
        _buildParameterRow(
          icon: Icons.local_florist_outlined,
          name: 'Habitat Quality',
          weight: 'Weight 30%',
          score: result.habitat,
          statusLabel: scoreBand(result.habitat),
          detail:
              'Flowers ${levelName(inputs.flowers)} · Nesting ${levelName(inputs.nesting)} · Shelter ${levelName(inputs.shelter)} · Water ${inputs.water == Water.present ? 'Present' : 'Absent'}',
        ),
        const SizedBox(height: 12),
        _buildParameterRow(
          icon: Icons.thermostat_outlined,
          name: 'Environmental Conditions',
          weight: 'Weight 20%',
          score: result.environmental,
          statusLabel: scoreBand(result.environmental),
          detail: inputs.soilMoisturePercent != null
              ? '${_fmt(inputs.temperatureC)} °C · ${_fmt(inputs.humidityPct)} % humidity · ${_fmt(inputs.co2Ppm)} ppm CO₂ · ${_fmt(inputs.soilMoisturePercent!)} % soil${inputs.soil?.source == SoilSource.manual ? " (manual)" : ""}'
              : '${_fmt(inputs.temperatureC)} °C · ${_fmt(inputs.humidityPct)} % humidity · ${_fmt(inputs.co2Ppm)} ppm CO₂',
        ),
        const SizedBox(height: 12),
        _buildParameterRow(
          icon: Icons.shield_outlined,
          name: 'Potential Risk',
          weight: 'Weight 20%',
          score: result.risk.toDouble(),
          statusLabel: switch (result.riskLevel) {
            RiskLevel.low => 'Low risk',
            RiskLevel.moderate => 'Moderate risk',
            RiskLevel.high => 'High risk',
          },
          detail:
              'Risk level ${_riskLevelStr(inputs.riskLevel)} · ${inputs.risk.count} ${inputs.risk.count == 1 ? 'indicator' : 'indicators'}',
        ),
      ],
    );
  }

  Widget _buildParameterRow({
    required IconData icon,
    required String name,
    required String weight,
    required double score,
    required String statusLabel,
    required String detail,
  }) {
    final progress = (score / 100.0).clamp(0.0, 1.0);
    final scoreText = _fmt(score);
    final tier = tierFor(score.round());
    final tierColor = Color(tierInfo[tier]!.colorHex);
    final chipBg = tierColor.withValues(alpha: 0.15);
    final chipText = tierColor;

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.forest, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      weight,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        scoreText,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        ' / 100',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: chipText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.sage,
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "How PHI is calculated" Expandable
  // ---------------------------------------------------------------------------
  Widget _buildHowCalculatedExpandable(PhiResult result) {
    final formula =
        '(${_fmt(result.activity)} × 0.30) + (${_fmt(result.habitat)} × 0.30) + (${_fmt(result.environmental)} × 0.20) + (${_fmt(result.risk.toDouble())} × 0.20) = ${_fmt(result.raw)} → ${result.phi}';

    return PulseCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calculate_outlined,
                color: AppColors.forest,
                size: 20,
              ),
            ),
            title: Text(
              'How PHI is calculated',
              style: GoogleFonts.lora(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            subtitle: Text(
              'Weighted formula with your assessment inputs',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
            ),
            children: [
              if (result.soil != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Text(
                    'Environmental = (${result.temperaturePoints} + ${result.humidityPoints} + ${result.co2Points} + ${result.soilScore?.round() ?? 100}) / 4 = ${_fmt(result.environmental)}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECE0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sageBorder),
                ),
                child: Text(
                  formula,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '• Pollinator Activity: weight 30% (${_fmt(result.activity)} pts)\n'
                '• Habitat Quality: weight 30% (${_fmt(result.habitat)} pts)\n'
                '• Environmental Conditions: weight 20% (${_fmt(result.environmental)} pts)\n'
                '• Potential Risks: weight 20% (${_fmt(result.risk.toDouble())} pts)\n\n'
                'The raw weighted sum (${_fmt(result.raw)}) is rounded half-up to calculate the final PHI of ${result.phi} / 100.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "What to do next?" Card
  // ---------------------------------------------------------------------------
  Widget _buildNextStepsCard(List<String> steps) {
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: AppColors.forest,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'What to do next?',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Photo Gallery
  // ---------------------------------------------------------------------------
  Widget _buildPhotoGallery(List<String> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Assessment Photos'),
        const SizedBox(height: 8),
        if (photos.isEmpty)
          PulseCard(
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.muted,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No photos attached to this assessment',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final path = photos[idx];
                Widget imgWidget;
                if (path.startsWith('assets/')) {
                  imgWidget = Image.asset(path, fit: BoxFit.cover);
                } else {
                  final file = File(path);
                  if (file.existsSync()) {
                    imgWidget = Image.file(file, fit: BoxFit.cover);
                  } else {
                    imgWidget = Container(
                      color: AppColors.sageBorder.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(Icons.image_outlined,
                            color: AppColors.muted, size: 32),
                      ),
                    );
                  }
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 150,
                    height: 120,
                    child: imgWidget,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PHI Trend for this Location
  // ---------------------------------------------------------------------------
  Widget _buildLocationTrendCard(PhiResult currentResult) {
    final history = _trendAssessments;

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: AppColors.forest,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Location PHI Trend',
                style: GoogleFonts.lora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            history.length >= 2
                ? 'Historical PHI records for this site'
                : 'Initial assessment recorded for this site',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (history.length >= 2) ...[
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          final a = history[idx];
                          final d = a.submittedAt ?? a.createdAt;
                          final dStr = DateFormat('d MMM').format(d);
                          final tStr = DateFormat('h:mm a').format(d);
                          return LineTooltipItem(
                            '$dStr · $tStr\n${spot.y.round()} PHI',
                            GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.sageBorder.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 16,
                        getTitlesWidget: _emptyTitles,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 25,
                        getTitlesWidget: (val, meta) {
                          if (val == 0 || val == 50 || val == 100) {
                            return Text(
                              '${val.toInt()}',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: AppColors.muted),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < history.length) {
                            if (history.length > 6) {
                              final step = (history.length - 1) / 4.0;
                              final isTarget = [0, 1, 2, 3, 4]
                                  .map((i) => (i * step).round())
                                  .contains(idx);
                              if (!isTarget) return const SizedBox.shrink();
                            }

                            final a = history[idx];
                            final curDate = DateFormat('d MMM').format(
                                a.submittedAt ?? a.createdAt);

                            if (idx > 0) {
                              final prev = history[idx - 1];
                              final prevDate = DateFormat('d MMM').format(
                                  prev.submittedAt ?? prev.createdAt);
                              if (curDate == prevDate) {
                                return const SizedBox.shrink();
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                curDate,
                                style: GoogleFonts.inter(
                                    fontSize: 9.5, color: AppColors.muted),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < history.length; i++)
                          FlSpot(
                            i.toDouble(),
                            (history[i].result?.phi ?? 0).toDouble(),
                          ),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppColors.forest,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.cream,
                          strokeWidth: 2,
                          strokeColor: AppColors.forest,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.forest.withValues(alpha: 0.25),
                            AppColors.forest.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.forest, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'First recorded assessment for this location (${currentResult.phi} PHI). Complete future observations here to build a health trend.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI Insights Card (Advisory, separate, score invariant)
  // ---------------------------------------------------------------------------
  Widget _buildAiInsightsCard(Assessment assessment) {
    final ai = assessment.ai;

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.forest,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Ecological insights',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Advisory',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestDark,
                  ),
                ),
              ),
              const Spacer(),
              if (ai != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: AppColors.forest),
                  tooltip: 'Regenerate insights',
                  onPressed: _isGeneratingAi ? null : () => _generateAiInsights(assessment),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AI suggestions provide educational insights only. They can never set or modify the calculated PHI score.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          const Divider(height: 20),
          if (ai == null) ...[
            if (_isGeneratingAi) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.forest),
                      SizedBox(height: 12),
                      Text('Generating insights...'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.icon(
                    onPressed: () => _generateAiInsights(assessment),
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                    label: const Text('Generate insights'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forestDark,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[
            // Summary
            if (ai.summary.isNotEmpty) ...[
              Text(
                ai.summary,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Photo findings
            if (ai.photoFindings.isNotEmpty) ...[
              Text(
                'Photo findings',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              for (final finding in ai.photoFindings) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: AppColors.forest,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          finding,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],

            // Soil advice if present
            if (ai.soilAdvice.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.water_drop_outlined, size: 16, color: AppColors.forest),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.ink,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: 'Soil: ',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                            TextSpan(text: ai.soilAdvice),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Up to 2 "AI tip" bullets
            if (ai.tips.isNotEmpty) ...[
              Text(
                'AI tips',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              for (final tip in ai.tips) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.forest),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.ink,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],

            if (_isGeneratingAi) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
                      ),
                      SizedBox(width: 8),
                      Text('Regenerating insights...'),
                    ],
                  ),
                ),
              ),
            ],

            const Divider(height: 16),
            // Footer: "AI-generated · may be inaccurate · model: {model}"
            Text(
              'AI-generated · may be inaccurate · model: ${ai.model}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions Taken Section & Bottom Sheet
  // ---------------------------------------------------------------------------
  Widget _buildActionsSection(Assessment assessment) {
    final actions = assessment.actionsTaken;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressableScale(
          onTap: () => _showRecordActionSheet(context, assessment.id),
          child: OutlinedButton.icon(
            onPressed: () => _showRecordActionSheet(context, assessment.id),
            icon: const Icon(Icons.add_task_rounded, color: AppColors.forest),
            label: const Text('Record an action taken'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.forest, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actions Taken',
                  style: GoogleFonts.lora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('d MMM y').format(actions[i].date),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          actions[i].note,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showRecordActionSheet(BuildContext context, String assessmentId) {
    DateTime selectedDate = DateTime.now();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Record an Action Taken',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log interventions or habitat improvements made at this site.',
                    style:
                        GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.sageBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: AppColors.forest),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('d MMM y').format(selectedDate),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down_rounded,
                              color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Describe action (e.g. Added water dish, planted native perennials)...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.sageBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.sageBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      if (note.isEmpty) return;

                      final api = context.read<ApiService>();
                      final navigator = Navigator.of(bottomSheetContext);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final updated = await api.addActionTaken(
                          assessmentId,
                          ActionTaken(selectedDate, note),
                        );
                        if (mounted) {
                          setState(() => _assessment = updated);
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Action recorded successfully!'),
                              backgroundColor: AppColors.forest,
                            ),
                          );
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save Action'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Action Buttons: "View location" / "New assessment"
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons(Assessment assessment) {
    return Row(
      children: [
        Expanded(
          child: PressableScale(
            onTap: () {
              if (assessment.locationId != null) {
                context.push('/location/${assessment.locationId}');
              } else {
                context.go('/locations');
              }
            },
            child: OutlinedButton.icon(
              onPressed: () {
                if (assessment.locationId != null) {
                  context.push('/location/${assessment.locationId}');
                } else {
                  context.go('/locations');
                }
              },
              icon: const Icon(Icons.place_outlined),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('View location'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressableScale(
            onTap: () {
              if (assessment.locationId != null) {
                context.go('/monitor?locationId=${assessment.locationId}');
              } else {
                context.go('/monitor');
              }
            },
            child: FilledButton.icon(
              onPressed: () {
                if (assessment.locationId != null) {
                  context.go('/monitor?locationId=${assessment.locationId}');
                } else {
                  context.go('/monitor');
                }
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('New assessment'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Skeleton Loader
  // ---------------------------------------------------------------------------
  Widget _buildSkeleton() {
    Widget skeletonBox({double width = double.infinity, double height = 16, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.sageBorder.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletonBox(width: 180, height: 22),
                const SizedBox(height: 8),
                skeletonBox(width: 140, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PulseCard(
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 180,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.sageBorder.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(90)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                skeletonBox(width: 120, height: 24, radius: 12),
                const SizedBox(height: 12),
                skeletonBox(width: 200, height: 16),
                const SizedBox(height: 6),
                skeletonBox(width: 160, height: 14),
              ],
            ),
          ),
          const SizedBox(height: 20),
          skeletonBox(width: 150, height: 20),
          const SizedBox(height: 12),
          for (int i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            PulseCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      skeletonBox(width: 32, height: 32, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            skeletonBox(width: 120, height: 14),
                            const SizedBox(height: 4),
                            skeletonBox(width: 70, height: 12),
                          ],
                        ),
                      ),
                      skeletonBox(width: 50, height: 20, radius: 6),
                    ],
                  ),
                  const SizedBox(height: 12),
                  skeletonBox(height: 6, radius: 3),
                ],
              ),
            ),
          ],
        ],
      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
            begin: const Offset(0.5, 0).dx,
            end: const Offset(1.0, 0).dx,
            duration: const Duration(milliseconds: 900),
          ),
    );
  }
}
