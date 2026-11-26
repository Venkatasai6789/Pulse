import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/phi.dart';
import '../core/recommendations.dart';
import '../theme/app_theme.dart';

/// Prominent badge / pill showing the assessment Tier (PROTECT, ENHANCE, IMPROVE, etc.),
/// icon, and optional category title.
class TierBadge extends StatelessWidget {
  final Tier tier;
  final String? categoryName;
  final bool showCategory;
  final bool compact;

  const TierBadge({
    super.key,
    required this.tier,
    this.categoryName,
    this.showCategory = false,
    this.compact = false,
  });

  IconData? _iconForTier(Tier tier) => switch (tier) {
        Tier.protect => Icons.shield_rounded,
        Tier.enhance => null, // F11: sparkle removed
        Tier.improve => Icons.trending_up_rounded,
        Tier.restore => Icons.build_rounded,
        Tier.investigate => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = tierInfo[tier];
    final color = Color(info?.colorHex ?? 0xFF2E7D32);
    final category = categoryName ?? info?.categoryName;
    final icon = _iconForTier(tier);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 14 : 16, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              info?.label ?? tier.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.6,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!showCategory || category == null) {
      return badge;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(height: 8),
        Text(
          category,
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
