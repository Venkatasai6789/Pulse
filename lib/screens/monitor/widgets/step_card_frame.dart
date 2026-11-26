import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StepCardFrame extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final Widget illustration;
  final Widget child;

  const StepCardFrame({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sageBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Light green header strip matching designs/02_new_assessment.jpg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.45),
              border: const Border(
                bottom: BorderSide(color: AppColors.sageBorder, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Numbered green circle (1-4, or icon for 5)
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.forest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: stepNumber <= 4
                      ? Text(
                          '$stepNumber',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(
                          Icons.checklist_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
                const SizedBox(width: 12),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.lora(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Small illustration / icon on the right
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(child: illustration),
                ),
              ],
            ),
          ),
          // Body content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
