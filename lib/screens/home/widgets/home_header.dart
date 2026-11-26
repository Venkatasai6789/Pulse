import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';

class HomeHeader extends StatelessWidget {
  final AppUser? user;
  final VoidCallback? onNotificationTap;

  const HomeHeader({
    super.key,
    required this.user,
    this.onNotificationTap,
  });

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = user?.firstName ?? 'there';
    final photoUrl = user?.photoUrl;
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 110,
      collapsedHeight: 60,
      toolbarHeight: 60,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icon/icon_foreground.png',
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/images/pulse_logo.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'P.U.L.S.E.',
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
      actions: [
        const SensorStatusButton(),
        // Notification bell with badge dot
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.forest,
                size: 24,
              ),
              onPressed: onNotificationTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No new notifications'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.honey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),

        // User avatar (36 px)
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 4),
          child: GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.forest, width: 1.5),
              ),
              child: ClipOval(
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? Image.network(
                        photoUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildInitialsAvatar(user),
                      )
                    : _buildInitialsAvatar(user),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          // Only show greeting subtitle when expanded
          final isExpanded = top > 85;

          return FlexibleSpaceBar(
            background: Container(
              color: AppColors.cream,
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
              alignment: Alignment.bottomLeft,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isExpanded ? 1.0 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getTimeBasedGreeting()}, $firstName!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialsAvatar(AppUser? user) {
    return Container(
      color: AppColors.forest,
      alignment: Alignment.center,
      child: Text(
        user?.initials ?? 'JS',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
