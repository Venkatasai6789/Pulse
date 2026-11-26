import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ActivityItem {
  final String title;
  final String detail;
  final DateTime date;
  final Color dotColor;

  const ActivityItem({
    required this.title,
    required this.detail,
    required this.date,
    required this.dotColor,
  });
}

class ActivityTimeline extends StatelessWidget {
  final List<ActivityItem> items;

  const ActivityTimeline({
    super.key,
    required this.items,
  });

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.sageBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          'No activity yet. Your assessments will show up here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
      );
    }

    final displayItems = items.take(3).toList();

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: List.generate(displayItems.length, (index) {
          final item = displayItems[index];
          final isLast = index == displayItems.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline column: dot + connecting vertical line
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: item.dotColor.withValues(alpha: 0.3),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: AppColors.sageBorder,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 2 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.detail,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Relative time on the right
                Text(
                  _formatRelativeTime(item.date),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
