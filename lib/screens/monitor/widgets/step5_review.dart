import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/phi.dart';
import '../../../core/recommendations.dart';
import '../../../core/score_format.dart';
import '../../../core/soil.dart';
import '../../../core/soil_reading.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../home/widgets/ring_gauge.dart';

class Step5Review extends StatelessWidget {
  final Assessment draft;
  final Location? selectedLocation;
  final ValueChanged<int> onJumpToStep;

  const Step5Review({
    super.key,
    required this.draft,
    required this.selectedLocation,
    required this.onJumpToStep,
  });

  Widget _buildThumbnailRow(List<String> paths) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: paths.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final p = paths[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: p.startsWith('assets/')
                  ? Image.asset(p, width: 48, height: 48, fit: BoxFit.cover)
                  : Image.file(File(p), width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionSummaryCard({
    required String title,
    required IconData icon,
    required int stepIndex,
    required List<Widget> details,
    List<String> photos = const [],
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.forest, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => onJumpToStep(stepIndex),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.forest),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.sageBorder),
          ...details,
          if (photos.isNotEmpty) _buildThumbnailRow(photos),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false, String? caption}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                  color: isHighlight ? AppColors.forest : AppColors.ink,
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = draft.isComplete;
    PhiResult? result;
    if (isComplete) {
      result = calculatePhi(draft.toInputs());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Preview Card
        if (isComplete && result != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.leaf, width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.preview_rounded, color: AppColors.forest, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Live PHI Preview',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TierBadge(tier: result.tier, showCategory: false, compact: true),
                  ],
                ),
                const SizedBox(height: 16),
                RingGauge(
                  phi: result.phi,
                  size: 130,
                  animate: true,
                ),
                const SizedBox(height: 12),
                Text(
                  tierInfo[result.tier]!.categoryName,
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preview score based on your exact entered readings',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                // 4 sub-scores row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildMiniScore('Activity', formatSubScore(result.activity))),
                      Expanded(child: _buildMiniScore('Habitat', formatSubScore(result.habitat))),
                      Expanded(child: _buildMiniScore('Environment', formatSubScore(result.environmental))),
                      Expanded(child: _buildMiniScore('Risk', '${result.risk}')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.alertSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.alert.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.alert, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${draft.missingFields.length} Required Fields Remaining',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.alert,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Please complete the missing items before calculating PHI:',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: draft.missingFields
                      .map((f) => Chip(
                            label: Text(f, style: const TextStyle(fontSize: 11.5)),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.alert, width: 0.8),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Section 1 Summary: Activity
        _buildSectionSummaryCard(
          title: 'Pollinator Activity',
          icon: Icons.pest_control_outlined,
          stepIndex: 0,
          details: [
            _buildSummaryRow(
              'Visits recorded',
              draft.visits == null ? 'Not entered' : '${draft.visits} visits',
              isHighlight: true,
            ),
            _buildSummaryRow(
              'Duration',
              draft.durationMinutes == null ? '—' : '${draft.durationMinutes} min',
            ),
            _buildSummaryRow(
              'Observed at',
              draft.observedAt != null
                  ? DateFormat('d MMM yyyy, h:mm a').format(draft.observedAt!)
                  : 'Not entered',
            ),
            _buildSummaryRow('Weather', draft.weather ?? 'Not entered'),
          ],
          photos: draft.activityPhotoPaths,
        ),

        // Section 2 Summary: Habitat Quality
        _buildSectionSummaryCard(
          title: 'Habitat Quality',
          icon: Icons.local_florist_outlined,
          stepIndex: 1,
          details: [
            _buildSummaryRow('Flowers', draft.flowers?.name.toUpperCase() ?? 'Not selected'),
            _buildSummaryRow('Nesting spaces', draft.nesting?.name.toUpperCase() ?? 'Not selected'),
            _buildSummaryRow('Shelter', draft.shelter?.name.toUpperCase() ?? 'Not selected'),
            _buildSummaryRow('Water', draft.water?.name.toUpperCase() ?? 'Not selected'),
            if (draft.flowers != null &&
                draft.nesting != null &&
                draft.shelter != null &&
                draft.water != null)
              _buildSummaryRow(
                'Habitat sub-score',
                '${formatSubScore(habitatScore(draft.flowers!, draft.nesting!, draft.shelter!, draft.water!))} / 100',
                isHighlight: true,
              ),
          ],
        ),

        // Section 3 Summary: Environmental Conditions
        _buildSectionSummaryCard(
          title: 'Environmental Conditions',
          icon: Icons.thermostat_outlined,
          stepIndex: 2,
          details: [
            _buildSummaryRow(
              'Temperature',
              draft.temperatureC != null ? '${draft.temperatureC} °C' : 'Not entered',
            ),
            _buildSummaryRow(
              'Humidity',
              draft.humidityPct != null ? '${draft.humidityPct} %' : 'Not entered',
            ),
            _buildSummaryRow(
              'CO₂ level',
              draft.co2Ppm != null ? '${draft.co2Ppm!.toInt()} ppm' : 'Not entered',
            ),
            if (draft.soil != null)
              _buildSummaryRow(
                'Soil moisture',
                '${draft.soil!.percent.toStringAsFixed(draft.soil!.percent % 1 == 0 ? 0 : 1)} % · ${soilLabel(draft.soil!.status)}',
                caption: draft.soil!.source == SoilSource.esp32
                    ? 'Sensor ${draft.soil!.deviceId ?? "Node"} · ${DateFormat('HH:mm').format(draft.soil!.capturedAt)}'
                    : 'Entered manually',
              ),
            if (draft.temperatureC != null &&
                draft.humidityPct != null &&
                draft.co2Ppm != null)
              _buildSummaryRow(
                'Environmental sub-score',
                '${formatSubScore(environmentalScore(draft.temperatureC!, draft.humidityPct!, draft.co2Ppm!, draft.soilMoisturePercent))} / 100',
                isHighlight: true,
              ),
          ],
        ),

        // Section 4 Summary: Potential Risks
        _buildSectionSummaryCard(
          title: 'Potential Risks',
          icon: Icons.warning_amber_rounded,
          stepIndex: 3,
          details: [
            _buildSummaryRow(
              'Risk Level',
              draft.riskLevel != null
                  ? (draft.riskLevel!.name[0].toUpperCase() +
                      draft.riskLevel!.name.substring(1).toLowerCase())
                  : 'Not selected',
              isHighlight: true,
            ),
            _buildSummaryRow(
              'Indicators identified',
              draft.riskIndicators.count == 0
                  ? 'None selected'
                  : [
                      if (draft.riskIndicators.pesticide) 'Pesticide',
                      if (draft.riskIndicators.chemical) 'Chemical',
                      if (draft.riskIndicators.traffic) 'Traffic',
                      if (draft.riskIndicators.other) 'Other',
                    ].join(', '),
            ),
            if (draft.riskDescription != null && draft.riskDescription!.isNotEmpty)
              _buildSummaryRow('Description', draft.riskDescription!),
          ],
          photos: draft.riskPhotoPaths,
        ),
      ],
    );
  }

  Widget _buildMiniScore(String title, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
          maxLines: 1,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.muted),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
