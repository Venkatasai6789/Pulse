import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/phi.dart';
import '../../../core/recommendations.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

class HomeLocationCard extends StatelessWidget {
  final Location location;
  final Assessment? latestAssessment;
  final double? width;
  final double? height;

  const HomeLocationCard({
    super.key,
    required this.location,
    this.latestAssessment,
    this.width,
    this.height,
  });

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return 'Today';
    }
  }

  Widget _buildPhoto() {
    final photo = location.photoPaths.isNotEmpty ? location.photoPaths.first : null;
    Widget img;
    if (photo != null) {
      if (photo.startsWith('assets/')) {
        img = Image.asset(
          photo,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/images/loc_garden.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      } else {
        img = Image.file(
          File(photo),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/images/loc_garden.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      }
    } else {
      // Default fallbacks based on id/name
      final fallbackAsset = location.id.contains('garden')
          ? 'assets/images/loc_garden.jpg'
          : location.id.contains('house2')
              ? 'assets/images/loc_house2.jpg'
              : 'assets/images/loc_house1.jpg';
      img = Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Hero(
      tag: 'location-photo-${location.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        child: SizedBox.expand(
          child: img,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phi = latestAssessment?.result?.phi;
    final hasAssessment = phi != null;
    final tier = hasAssessment ? tierFor(phi) : Tier.investigate;
    final tierColor = hasAssessment ? Color(tierInfo[tier]!.colorHex) : AppColors.muted;
    final assessmentDate = latestAssessment?.submittedAt ?? latestAssessment?.createdAt;
    final timeStr = _formatRelativeTime(assessmentDate ?? location.createdAt);

    return Container(
      width: width ?? 230,
      height: height,
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/location/${location.id}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final photoWidget = _buildPhoto();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (constraints.hasBoundedHeight)
                    Expanded(child: photoWidget)
                  else
                    SizedBox(height: 114, child: photoWidget),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          location.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // PHI Chip
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: tierColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tierColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  hasAssessment
                                      ? '$phi · ${tierInfo[tier]!.label}'
                                      : 'Not assessed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tierColor,
                                  ),
                                ),
                              ),
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                timeStr,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AddLocationCard extends StatelessWidget {
  final double? width;
  final double? height;

  const AddLocationCard({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: () => context.push('/location/new'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: width ?? 170,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.forest.withValues(alpha: 0.4),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_location_alt_outlined,
                  size: 24,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add Location',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Register new site',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
