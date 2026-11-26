import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/soil.dart';
import '../../theme/app_theme.dart';

/// Horizontal 8 dp track with optimal 40–60 % shaded band and status-colored animated fill.
class SoilMoistureBar extends StatelessWidget {
  final double percent;
  final SoilStatus status;

  const SoilMoistureBar({
    super.key,
    required this.percent,
    required this.status,
  });

  Color _statusColor(SoilStatus s) {
    switch (s) {
      case SoilStatus.dry:
      case SoilStatus.wet:
        return const Color(0xFFEF6C00); // RESTORE tier orange
      case SoilStatus.low:
      case SoilStatus.moist:
        return AppColors.honey;
      case SoilStatus.optimal:
        return AppColors.leaf;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 100.0);
    final fillRatio = clamped / 100.0;
    final color = _statusColor(status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final fillWidth = totalWidth * fillRatio;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Base track
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // 2. Optimal 40–60% shaded zone
                Positioned(
                  left: totalWidth * 0.40,
                  width: totalWidth * 0.20,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.leafLight.withValues(alpha: 0.35),
                    ),
                  ),
                ),

                // 3. Animated fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // 4. Ink marker at current value
                Positioned(
                  left: (fillWidth - 1).clamp(0.0, totalWidth - 2),
                  top: -2,
                  child: Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),

        // Tick Labels underneath
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: _tickStyle),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text('40', style: _tickStyle),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Text('60', style: _tickStyle),
            ),
            Text('100', style: _tickStyle),
          ],
        ),
      ],
    );
  }

  TextStyle get _tickStyle => GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.muted,
        fontWeight: FontWeight.w500,
      );
}
