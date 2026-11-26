import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Our Community',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.asset(
                'assets/images/community_hero.jpg',
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  height: 140,
                  color: AppColors.sage,
                  alignment: Alignment.center,
                  child: const Icon(Icons.people_alt_rounded, size: 48, color: AppColors.forest),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PulseCard(
              color: AppColors.alertSoft,
              borderColor: AppColors.alert.withValues(alpha: 0.3),
              onTap: () => context.push('/report-concern'),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.alert),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report an Ecological Concern',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.alert,
                          ),
                        ),
                        Text(
                          'Notice pesticide use or habitat damage? Let the community know.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.alert),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Recent Community Posts'),
            const SizedBox(height: 8),
            PulseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.forest,
                        child: Text(
                          'GH',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Green Horizons NGO',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '2 hours ago • Community Partner',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pollinator Garden Workshop – This Saturday!',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join us for a hands-on workshop on creating pollinator-friendly gardens in urban spaces. All are welcome!',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/post/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Post'),
      ),
    );
  }
}
