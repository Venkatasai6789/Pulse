import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';
import 'score_chip.dart';

/// Card showing one of the four parameters (Pollinator Activity, Habitat Quality,
/// Environmental Conditions, Potential Risks).
class ParameterCard extends StatelessWidget {
  final Widget? icon;
  final IconData? iconData;
  final Color? iconColor;
  final String title;
  final double? score; // null displays "— / 100"
  final String? weight; // e.g. "30%"
  final String? label; // e.g. "Good", "Ideal"
  final String? details; // e.g. "18 visits in 5 mins"
  final String? footnote;
  final VoidCallback? onTap;
  final bool compact;

  const ParameterCard({
    super.key,
    this.icon,
    this.iconData,
    this.iconColor,
    required this.title,
    this.score,
    this.weight,
    this.label,
    this.details,
    this.footnote,
    this.onTap,
    this.compact = false,
  });

  Color _progressColor(double score) {
    if (score >= 80) return AppColors.leaf;
    if (score >= 60) return AppColors.leafLight;
    if (score >= 40) return AppColors.honey;
    return AppColors.alert;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.forest;

    Widget cardContent = Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Icon + Title + Weight
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null)
                icon!
              else if (iconData != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 18, color: effectiveIconColor),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (weight != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Weight: $weight',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score + Qualitative Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (score != null) ...[
                Text(
                  score! % 1 == 0 ? score!.toInt().toString() : score!.toStringAsFixed(1),
                  style: GoogleFonts.lora(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  ' / 100',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ] else ...[
                Text(
                  '— / 100',
                  style: GoogleFonts.lora(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
              const Spacer(),
              if (label != null) ScoreChip.forQuality(label!, compact: true),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score == null ? 0.0 : (score! / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.sageBorder.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                score == null ? Colors.transparent : _progressColor(score!),
              ),
            ),
          ),

          // Detail text
          if (details != null && !compact) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
          ],

          // Footnote
          if (footnote != null && !compact) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return PressableScale(onTap: onTap, child: cardContent);
    }
    return cardContent;
  }
}
