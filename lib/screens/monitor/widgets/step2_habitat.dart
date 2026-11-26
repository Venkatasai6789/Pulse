import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../ai/ai_service.dart';
import '../../../core/phi.dart';
import '../../../core/score_format.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'photo_uploader.dart';
import 'shake_wrapper.dart';

class Step2Habitat extends StatefulWidget {
  final Assessment draft;
  final ValueChanged<Assessment> onDraftChanged;
  final GlobalKey<ShakeWrapperState> flowersKey;
  final GlobalKey<ShakeWrapperState> nestingKey;
  final GlobalKey<ShakeWrapperState> shelterKey;
  final GlobalKey<ShakeWrapperState> waterKey;

  const Step2Habitat({
    super.key,
    required this.draft,
    required this.onDraftChanged,
    required this.flowersKey,
    required this.nestingKey,
    required this.shelterKey,
    required this.waterKey,
  });

  @override
  State<Step2Habitat> createState() => _Step2HabitatState();
}

class _Step2HabitatState extends State<Step2Habitat> {
  bool _isAnalysing = false;
  List<HabitatSuggestion> _suggestions = [];
  AiInsight? _lastInsight;
  bool _isNotHabitat = false;

  String _getFlowersHelper(Level? level) => switch (level) {
        Level.low => 'Few or no flowering plants available',
        Level.medium => 'Some flowering patches scattered',
        Level.high => 'Many flowering plants across the area',
        null => 'Select availability of nectar & pollen',
      };

  String _getNestingHelper(Level? level) => switch (level) {
        Level.low => 'No visible bare soil or nesting spots',
        Level.medium => 'Some bare soil, wood or bee hotels',
        Level.high => 'Abundant nesting sites and bare ground',
        null => 'Select availability of nesting sites',
      };

  String _getShelterHelper(Level? level) => switch (level) {
        Level.low => 'Exposed space with minimal cover',
        Level.medium => 'Some shrubs, hedgerows or grasses',
        Level.high => 'Dense vegetation and wind shelter',
        null => 'Select windbreaks and protective cover',
      };

  String _getWaterHelper(Water? water) => switch (water) {
        Water.absent => 'No accessible shallow water source',
        Water.present => 'Shallow water dish or bird bath with stones',
        null => 'Select whether clean water is available',
      };

  Future<void> _analysePhotos() async {
    if (widget.draft.activityPhotoPaths.isEmpty) return;

    setState(() {
      _isAnalysing = true;
    });

    try {
      final insight = await AiService.instance.analyseHabitatPhotos(
        widget.draft.activityPhotoPaths,
      );
      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
        _lastInsight = insight;
        _isNotHabitat = !insight.isHabitatPhoto;
        _suggestions = insight.habitatSuggestions;
      });
      if (!insight.isHabitatPhoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              insight.summary.isNotEmpty
                  ? insight.summary
                  : 'Notice: Non-habitat image detected (person or indoor scene).',
            ),
            backgroundColor: const Color(0xFFE65100),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (insight.habitatSuggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No habitat suggestions could be determined from the photos.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
      });
      final msg = e is AiException ? e.message : kAiFallbackMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _applySuggestion(HabitatSuggestion s) {
    final field = s.field.toLowerCase();
    final val = s.value.toLowerCase();
    Assessment updated = widget.draft;

    Level? parseLevel(String v) {
      if (v.contains('high')) return Level.high;
      if (v.contains('med')) return Level.medium;
      if (v.contains('low')) return Level.low;
      return null;
    }

    Water? parseWater(String v) {
      if (v.contains('present') || v.contains('natural') || v.contains('artificial')) {
        return Water.present;
      }
      if (v.contains('absent') || v.contains('none') || v.contains('no')) {
        return Water.absent;
      }
      return null;
    }

    if (field.contains('flower')) {
      final lvl = parseLevel(val);
      if (lvl != null) updated = updated.copyWith(flowers: lvl);
    } else if (field.contains('nest')) {
      final lvl = parseLevel(val);
      if (lvl != null) updated = updated.copyWith(nesting: lvl);
    } else if (field.contains('shelter')) {
      final lvl = parseLevel(val);
      if (lvl != null) updated = updated.copyWith(shelter: lvl);
    } else if (field.contains('water')) {
      final w = parseWater(val);
      if (w != null) updated = updated.copyWith(water: w);
    }

    widget.onDraftChanged(updated);
    HapticFeedback.selectionClick();
  }

  Widget _buildAiPhotoAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6A1B9A), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Habitat Insights',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A148C),
                  ),
                ),
              ),
              if (_isAnalysing)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Analysing...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _analysePhotos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '✨ Analyse photos with AI',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (_isNotHabitat) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Non-Habitat Photo Detected',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastInsight?.summary.isNotEmpty == true
                              ? _lastInsight!.summary
                              : 'The photo appears to depict a person, portrait, or indoor subject rather than outdoor pollinator habitat. Pollinator features (flowers, nesting, shelter) cannot be evaluated from this photo. Please upload photos of outdoor flowers, plants, or gardens.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.ink),
                        ),
                        if (_lastInsight?.photoFindings.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          ..._lastInsight!.photoFindings.map((f) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('• $f',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF795548))),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (_lastInsight != null && _lastInsight!.summary.isNotEmpty) ...[
              Text(
                _lastInsight!.summary,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4A148C),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              'Suggestions (tap Apply to fill; you can change it anytime):',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) {
                return ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF6A1B9A)),
                  label: Text(
                    s.chipLabel, // "AI suggests Flowers: High (80%) · Apply"
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A148C),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFAB47BC)),
                  ),
                  onPressed: () => _applySuggestion(s),
                );
              }).toList(),
            ),
          ] else if (_lastInsight == null && widget.draft.activityPhotoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '📷 ${widget.draft.activityPhotoPaths.length} photo attached. Tap "✨ Analyse photos with AI" to detect flowers, nesting spaces, and shelter.',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required BuildContext context,
    required GlobalKey<ShakeWrapperState> shakeKey,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Level? selected,
    required String helperText,
    required ValueChanged<Level> onSelected,
  }) {
    return ShakeWrapper(
      key: shakeKey,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected == null ? AppColors.sageBorder : AppColors.forest,
            width: selected == null ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stacked selectable pills: Low / Medium / High
            ...Level.values.map((lvl) {
              final isChosen = selected == lvl;
              final label = lvl.name[0].toUpperCase() + lvl.name.substring(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(lvl);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isChosen ? AppColors.forestDark : AppColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isChosen ? AppColors.forestDark : AppColors.sageBorder,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                        color: isChosen ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 2),
            // Helper text
            Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: selected == null ? AppColors.muted : AppColors.forest,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterCard({
    required BuildContext context,
    required GlobalKey<ShakeWrapperState> shakeKey,
    required Water? selected,
    required ValueChanged<Water> onSelected,
  }) {
    return ShakeWrapper(
      key: shakeKey,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected == null ? AppColors.sageBorder : AppColors.forest,
            width: selected == null ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF0288D1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Water',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stacked selectable pills: Absent / Present
            ...Water.values.map((w) {
              final isChosen = selected == w;
              final label = w == Water.absent ? 'Absent' : 'Present';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(w);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isChosen ? AppColors.forestDark : AppColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isChosen ? AppColors.forestDark : AppColors.sageBorder,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                        color: isChosen ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 2),
            // Helper text
            Text(
              _getWaterHelper(selected),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: selected == null ? AppColors.muted : AppColors.forest,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasAllFour = draft.flowers != null &&
        draft.nesting != null &&
        draft.shelter != null &&
        draft.water != null;

    final score = hasAllFour
        ? habitatScore(draft.flowers!, draft.nesting!, draft.shelter!, draft.water!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.activityPhotoPaths.isNotEmpty) ...[
          _buildAiPhotoAnalysisSection(),
          const SizedBox(height: 16),
        ] else ...[
          PhotoUploader(
            assessmentId: draft.id,
            photoPaths: draft.activityPhotoPaths,
            onPhotosChanged: (photos) {
              widget.onDraftChanged(draft.copyWith(activityPhotoPaths: photos));
            },
            label: 'Add Habitat Photograph for AI (Optional)',
          ),
          const SizedBox(height: 16),
        ],

        // 2x2 grid adapted to mobile
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLevelCard(
                context: context,
                shakeKey: widget.flowersKey,
                title: 'Flowers',
                icon: Icons.local_florist_rounded,
                iconColor: const Color(0xFFE91E63),
                selected: draft.flowers,
                helperText: _getFlowersHelper(draft.flowers),
                onSelected: (lvl) =>
                    widget.onDraftChanged(draft.copyWith(flowers: lvl)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLevelCard(
                context: context,
                shakeKey: widget.nestingKey,
                title: 'Nesting Spaces',
                icon: Icons.home_work_outlined,
                iconColor: const Color(0xFF8D6E63),
                selected: draft.nesting,
                helperText: _getNestingHelper(draft.nesting),
                onSelected: (lvl) =>
                    widget.onDraftChanged(draft.copyWith(nesting: lvl)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLevelCard(
                context: context,
                shakeKey: widget.shelterKey,
                title: 'Shelter',
                icon: Icons.eco_rounded,
                iconColor: const Color(0xFF4CAF50),
                selected: draft.shelter,
                helperText: _getShelterHelper(draft.shelter),
                onSelected: (lvl) =>
                    widget.onDraftChanged(draft.copyWith(shelter: lvl)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWaterCard(
                context: context,
                shakeKey: widget.waterKey,
                selected: draft.water,
                onSelected: (w) => widget.onDraftChanged(draft.copyWith(water: w)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Live preview chip at bottom
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: hasAllFour
              ? Container(
                  key: const ValueKey('habitat_score_card'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.leaf),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.forest, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Habitat Quality Score',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${formatSubScore(score!)} / 100',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  key: const ValueKey('habitat_incomplete_card'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked_rounded,
                          color: AppColors.muted, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Select all 4 features to preview Habitat Score',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
