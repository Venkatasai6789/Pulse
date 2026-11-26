import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';

class ParameterData {
  final String title;
  final String weight;
  final int? score;
  final String label;
  final Color labelColor;
  final IconData icon;
  final Color iconColor;
  final String? caption;

  const ParameterData({
    required this.title,
    required this.weight,
    required this.score,
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.iconColor,
    this.caption,
  });
}

class ParametersCard extends StatelessWidget {
  final List<ParameterData> parameters;
  final bool hasData;

  const ParametersCard({
    super.key,
    required this.parameters,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: List.generate(parameters.length, (index) {
          final param = parameters[index];
          final isLast = index == parameters.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () => context.push('/reports'),
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(AppRadius.card) : Radius.zero,
                  bottom: isLast ? const Radius.circular(AppRadius.card) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Icon circle (36 px)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: param.iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          param.icon,
                          size: 19,
                          color: param.iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Parameter name + weight + progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${param.title} · ${param.weight}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: hasData && param.score != null
                                    ? (param.score!.clamp(0, 100) / 100.0)
                                    : 0.0,
                                minHeight: 6,
                                backgroundColor: AppColors.sage.withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  hasData ? param.labelColor : AppColors.muted,
                                ),
                              ),
                            ),
                            if (param.caption != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                param.caption!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Score & status label right-aligned
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            hasData && param.score != null ? '${param.score}' : '—',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ).copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasData ? param.label : 'No data yet',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasData ? param.labelColor : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.sageBorder,
                  indent: 64,
                ),
            ],
          );
        }),
      ),
    );
  }
}
