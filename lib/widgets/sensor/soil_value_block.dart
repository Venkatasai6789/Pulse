import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/soil.dart';
import '../../theme/app_theme.dart';

/// Renders the big tabular numeric value, % symbol, status word, and band chip.
class SoilValueBlock extends StatelessWidget {
  final double percent;
  final SoilStatus status;

  const SoilValueBlock({
    super.key,
    required this.percent,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusName = soilLabel(status);
    final score = soilScore(percent);
    final (chipLabel, chipColor, chipBg) = switch (score) {
      100 => ('Suitable', AppColors.forest, AppColors.sage),
      60 => ('Moderate', const Color(0xFFE65100), const Color(0xFFFFECC8)),
      _ => ('Stressful', AppColors.alert, AppColors.alertSoft),
    };

    final displayVal = percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Big number with %
        Text(
          displayVal,
          style: GoogleFonts.inter(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '%',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
        const Spacer(),

        // Status word + Band chip
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusName,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chipColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                chipLabel,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: chipColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
