import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/phi.dart';
import '../core/recommendations.dart';
import '../theme/app_theme.dart';

/// Small pill chip for scores and status labels (e.g. "Good", "Ideal", "91 / 100", "No data yet").
class ScoreChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final Tier? tier;
  final bool compact;

  const ScoreChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.tier,
    this.compact = false,
  });

  factory ScoreChip.forTier(Tier tier, {bool compact = false, int? score}) {
    final info = tierInfo[tier];
    final color = Color(info?.colorHex ?? 0xFF2E7D32);
    final tierName = info?.label ?? tier.name.toUpperCase();
    final label = score != null ? '$score · $tierName' : tierName;
    return ScoreChip(
      label: label,
      backgroundColor: color.withValues(alpha: 0.15),
      textColor: color,
      compact: compact,
    );
  }

  factory ScoreChip.forQuality(String label, {bool compact = false}) {
    Color bg;
    Color fg;
    final lower = label.toLowerCase();
    if (lower.contains('ideal') || lower.contains('good') || lower.contains('protect')) {
      bg = AppColors.leaf.withValues(alpha: 0.15);
      fg = AppColors.leaf;
    } else if (lower.contains('fair') || lower.contains('moderate') || lower.contains('enhance') || lower.contains('improve')) {
      bg = AppColors.honey.withValues(alpha: 0.2);
      fg = const Color(0xFFB78103);
    } else if (lower.contains('needs work') || lower.contains('critical') || lower.contains('stressful') || lower.contains('high') || lower.contains('investigate')) {
      bg = AppColors.alert.withValues(alpha: 0.15);
      fg = AppColors.alert;
    } else {
      bg = AppColors.sage;
      fg = AppColors.ink;
    }

    return ScoreChip(
      label: label,
      backgroundColor: bg,
      textColor: fg,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg = backgroundColor ?? AppColors.sage;
    Color fg = textColor ?? AppColors.forestDark;

    if (tier != null) {
      final info = tierInfo[tier!];
      final color = Color(info?.colorHex ?? 0xFF2E7D32);
      bg = color.withValues(alpha: 0.15);
      fg = color;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
