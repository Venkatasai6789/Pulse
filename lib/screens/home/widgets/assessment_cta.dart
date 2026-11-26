import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';

class AssessmentCtaCard extends StatelessWidget {
  final String? draftLocationName;
  final String? draftLocationId;

  const AssessmentCtaCard({
    super.key,
    this.draftLocationName,
    this.draftLocationId,
  });

  @override
  Widget build(BuildContext context) {
    final hasDraft = draftLocationName != null && draftLocationName!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1E4D2B),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle decorative illustration on the right
          Positioned(
            right: -24,
            bottom: -28,
            child: Opacity(
              opacity: 0.16,
              child: Image.asset(
                'assets/icon/icon_foreground.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/pulse_logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDraft
                      ? 'Continue draft for $draftLocationName'
                      : 'Start a new assessment',
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasDraft
                      ? 'Resume where you left off · Fast & easy'
                      : 'About 5 minutes · 4 steps and a review',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      if (hasDraft && draftLocationId != null) {
                        context.go('/monitor?locationId=$draftLocationId');
                      } else {
                        context.go('/monitor');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.honey,
                      foregroundColor: AppColors.forestDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasDraft ? 'Resume →' : 'Begin →',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forestDark,
                          ),
                        ),
                      ],
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
}
