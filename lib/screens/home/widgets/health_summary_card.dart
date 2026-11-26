import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/phi.dart';
import '../../../core/recommendations.dart';
import '../../../theme/app_theme.dart';
import 'ring_gauge.dart';

class HealthSummaryCard extends StatelessWidget {
  final int averagePhi;
  final int healthyLocationsCount;
  final int totalLocationsCount;
  final int? deltaPhi; // latest vs previous PHI change, or null if only 1 / none
  final bool hasData;

  const HealthSummaryCard({
    super.key,
    required this.averagePhi,
    required this.healthyLocationsCount,
    required this.totalLocationsCount,
    this.deltaPhi,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final tier = hasData ? tierFor(averagePhi) : Tier.investigate;
    final info = tierInfo[tier]!;
    final tierColor = Color(info.colorHex);

    String insightText;
    if (!hasData) {
      insightText = 'Start your first assessment to see your score';
    } else if (totalLocationsCount > 0) {
      insightText = '$healthyLocationsCount of $totalLocationsCount locations are in good health';
    } else {
      insightText = 'Overall habitat conditions are favorable';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sageBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main horizontal row: Left RingGauge, Right Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Compact Ring Gauge
              RingGauge(
                phi: hasData ? averagePhi : 0,
                size: 104,
              ),
              const SizedBox(width: 16),

              // 2. Right column: Tier badge, insight, trend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier badge pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasData ? tierColor : AppColors.muted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasData ? info.label.toUpperCase() : 'NO DATA YET',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hasData ? Colors.white : AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Insight line
                    Text(
                      insightText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Trend line (F05: single delta arrow icon, no duplicate text glyph)
                    if (hasData && deltaPhi != null)
                      Row(
                        children: [
                          Icon(
                            deltaPhi! > 0
                                ? Icons.arrow_upward_rounded
                                : (deltaPhi! < 0
                                    ? Icons.arrow_downward_rounded
                                    : Icons.remove_rounded),
                            color: deltaPhi! > 0
                                ? AppColors.leaf
                                : (deltaPhi! < 0 ? AppColors.alert : AppColors.muted),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            deltaPhi! == 0
                                ? 'No change since last assessment'
                                : '${deltaPhi!.abs()} since last assessment',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: deltaPhi! > 0
                                  ? AppColors.leaf
                                  : (deltaPhi! < 0 ? AppColors.alert : AppColors.muted),
                            ),
                          ),
                        ],
                      )
                    else if (hasData)
                      Text(
                        'Baseline established · —',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tier legend: 5 coloured dots with labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem(const Color(0xFF1E4D2B), 'Protect'),
                _buildLegendItem(const Color(0xFF7CB342), 'Enhance'),
                _buildLegendItem(const Color(0xFFF57C00), 'Improve'),
                _buildLegendItem(const Color(0xFFE65100), 'Restore'),
                _buildLegendItem(const Color(0xFFD32F2F), 'Investigate'),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.sageBorder),
          const SizedBox(height: 10),

          // Footer row (F23: wrapped caption, separate right-aligned View reports)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Average across your latest assessments',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => context.push('/reports'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View reports →',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
