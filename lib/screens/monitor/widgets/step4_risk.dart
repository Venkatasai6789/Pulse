import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/phi.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'photo_uploader.dart';
import 'shake_wrapper.dart';

class Step4Risk extends StatefulWidget {
  final Assessment draft;
  final ValueChanged<Assessment> onDraftChanged;
  final GlobalKey<ShakeWrapperState> riskLevelKey;

  const Step4Risk({
    super.key,
    required this.draft,
    required this.onDraftChanged,
    required this.riskLevelKey,
  });

  @override
  State<Step4Risk> createState() => _Step4RiskState();
}

class _Step4RiskState extends State<Step4Risk> {
  late final TextEditingController _descController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.draft.riskDescription ?? '');
    _notesController = TextEditingController(text: widget.draft.riskNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant Step4Risk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.riskDescription != _descController.text) {
      _descController.text = widget.draft.riskDescription ?? '';
    }
    if (widget.draft.riskNotes != _notesController.text) {
      _notesController.text = widget.draft.riskNotes ?? '';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildRiskTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(!isSelected);
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sage.withValues(alpha: 0.4) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: isSelected ? AppColors.forest : AppColors.sageBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.forest : AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.forest : AppColors.ink,
                  ),
                ),
              ),
              Checkbox(
                value: isSelected,
                activeColor: AppColors.forest,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onToggle(v ?? false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRiskObservedDate() async {
    final now = DateTime.now();
    final initial = widget.draft.riskObservedAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    widget.onDraftChanged(widget.draft.copyWith(riskObservedAt: combined));
  }

  @override
  Widget build(BuildContext context) {
    final indicators = widget.draft.riskIndicators;
    final anyIndicatorSelected = indicators.count > 0;
    final suggested = suggestedRiskLevel(indicators);
    final currentLevel = widget.draft.riskLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Any Observed Environmental Risks',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),

        // 4 selectable tiles
        _buildRiskTile(
          title: 'Nearby pesticide spraying',
          icon: Icons.science_outlined,
          isSelected: indicators.pesticide,
          onToggle: (v) => widget.onDraftChanged(
            widget.draft.copyWith(
              riskIndicators: indicators.copyWith(pesticide: v),
            ),
          ),
        ),
        _buildRiskTile(
          title: 'Nearby chemical use',
          icon: Icons.biotech_outlined,
          isSelected: indicators.chemical,
          onToggle: (v) => widget.onDraftChanged(
            widget.draft.copyWith(
              riskIndicators: indicators.copyWith(chemical: v),
            ),
          ),
        ),
        _buildRiskTile(
          title: 'Heavy traffic or pollution',
          icon: Icons.directions_car_outlined,
          isSelected: indicators.traffic,
          onToggle: (v) => widget.onDraftChanged(
            widget.draft.copyWith(
              riskIndicators: indicators.copyWith(traffic: v),
            ),
          ),
        ),
        _buildRiskTile(
          title: 'Other concerns',
          icon: Icons.warning_amber_rounded,
          isSelected: indicators.other,
          onToggle: (v) => widget.onDraftChanged(
            widget.draft.copyWith(
              riskIndicators: indicators.copyWith(other: v),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Risk Level dropdown *
        ShakeWrapper(
          key: widget.riskLevelKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Risk Level *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                    color: currentLevel == null
                        ? AppColors.sageBorder
                        : AppColors.forest,
                    width: currentLevel == null ? 1 : 1.5,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RiskLevel>(
                    value: currentLevel,
                    isExpanded: true,
                    hint: Text(
                      'Select risk level',
                      style: GoogleFonts.inter(color: AppColors.muted, fontSize: 14),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RiskLevel.low,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Color(0xFF2E7D32), size: 12),
                            SizedBox(width: 8),
                            Text('Low'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: RiskLevel.moderate,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Color(0xFFF9A825), size: 12),
                            SizedBox(width: 8),
                            Text('Moderate'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: RiskLevel.high,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Color(0xFFC62828), size: 12),
                            SizedBox(width: 8),
                            Text('High'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (lvl) {
                      if (lvl != null) {
                        HapticFeedback.selectionClick();
                        widget.onDraftChanged(widget.draft.copyWith(riskLevel: lvl));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Suggestion hint under dropdown
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Based on your selections we suggest: ${suggested.name[0].toUpperCase()}${suggested.name.substring(1)}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onDraftChanged(widget.draft.copyWith(riskLevel: suggested));
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // High Risk red alert notice
        if (currentLevel == RiskLevel.high) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.alertSoft,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.alert.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.alert, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A High Risk alert will appear on your results.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.alert,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Conditional fields if any risk tile selected
        if (anyIndicatorSelected) ...[
          const SizedBox(height: 20),
          Text(
            'Concern Details',
            style: GoogleFonts.lora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 12),

          // Description of concern (multiline)
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description of concern',
              hintText: 'Describe where and how the risk was observed...',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => widget.onDraftChanged(
              widget.draft.copyWith(riskDescription: v.trim().isEmpty ? null : v.trim()),
            ),
          ),

          const SizedBox(height: 12),

          // Approximate date/time observed
          InkWell(
            onTap: _pickRiskObservedDate,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.sageBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note_outlined, size: 18, color: AppColors.forest),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.draft.riskObservedAt != null
                          ? 'Observed: ${DateFormat('d MMM yyyy, h:mm a').format(widget.draft.riskObservedAt!)}'
                          : 'Approximate date / time observed',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: widget.draft.riskObservedAt != null
                            ? AppColors.ink
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.muted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Additional notes (optional)
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Any other relevant context or details...',
              alignLabelWithHint: true,
            ),
            onChanged: (v) => widget.onDraftChanged(
              widget.draft.copyWith(riskNotes: v.trim().isEmpty ? null : v.trim()),
            ),
          ),

          const SizedBox(height: 16),

          // Risk photos (optional)
          PhotoUploader(
            assessmentId: widget.draft.id,
            photoPaths: widget.draft.riskPhotoPaths,
            onPhotosChanged: (photos) {
              widget.onDraftChanged(widget.draft.copyWith(riskPhotoPaths: photos));
            },
            label: 'Risk Photographs (Optional)',
          ),
        ],

        const SizedBox(height: 16),

        // Footer note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.sageBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'P.U.L.S.E. records potential risk indicators. It does not detect specific chemicals or pesticide residues.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
