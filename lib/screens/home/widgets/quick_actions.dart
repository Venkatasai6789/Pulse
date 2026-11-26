import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.add_task_rounded,
          label: 'New\nAssessment',
          onTap: () => context.go('/monitor'),
        ),
        _buildActionButton(
          context: context,
          icon: Icons.add_location_alt_outlined,
          label: 'Add\nLocation',
          onTap: () => context.push('/location/new'),
        ),
        _buildActionButton(
          context: context,
          icon: Icons.warning_amber_rounded,
          label: 'Report\nConcern',
          onTap: () => context.push('/report-concern'),
        ),
        _buildActionButton(
          context: context,
          icon: Icons.rate_review_outlined,
          label: 'Share\nUpdate',
          onTap: () => context.push('/post/new'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sageBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 24,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
