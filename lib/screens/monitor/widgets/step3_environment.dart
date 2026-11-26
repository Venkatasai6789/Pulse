import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/phi.dart';
import '../../../core/score_format.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import 'shake_wrapper.dart';

class Step3Environment extends StatefulWidget {
  final Assessment draft;
  final ValueChanged<Assessment> onDraftChanged;
  final GlobalKey<ShakeWrapperState> tempKey;
  final GlobalKey<ShakeWrapperState> humidityKey;
  final GlobalKey<ShakeWrapperState> co2Key;

  const Step3Environment({
    super.key,
    required this.draft,
    required this.onDraftChanged,
    required this.tempKey,
    required this.humidityKey,
    required this.co2Key,
  });

  @override
  State<Step3Environment> createState() => _Step3EnvironmentState();
}

class _Step3EnvironmentState extends State<Step3Environment> {
  late final TextEditingController _tempController;
  late final TextEditingController _humidityController;
  late final TextEditingController _co2Controller;

  String? _tempError;
  String? _humidityError;
  String? _co2Error;

  @override
  void initState() {
    super.initState();
    _tempController = TextEditingController(
      text: widget.draft.temperatureC != null
          ? (widget.draft.temperatureC! % 1 == 0
              ? widget.draft.temperatureC!.toInt().toString()
              : widget.draft.temperatureC!.toString())
          : '',
    );
    _humidityController = TextEditingController(
      text: widget.draft.humidityPct != null
          ? (widget.draft.humidityPct! % 1 == 0
              ? widget.draft.humidityPct!.toInt().toString()
              : widget.draft.humidityPct!.toString())
          : '',
    );
    _co2Controller = TextEditingController(
      text: widget.draft.co2Ppm != null
          ? widget.draft.co2Ppm!.toInt().toString()
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant Step3Environment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.temperatureC == null && _tempController.text.isNotEmpty && _tempError == null) {
      _tempController.clear();
    }
    if (widget.draft.humidityPct == null && _humidityController.text.isNotEmpty && _humidityError == null) {
      _humidityController.clear();
    }
    if (widget.draft.co2Ppm == null && _co2Controller.text.isNotEmpty && _co2Error == null) {
      _co2Controller.clear();
    }
  }

  @override
  void dispose() {
    _tempController.dispose();
    _humidityController.dispose();
    _co2Controller.dispose();
    super.dispose();
  }

  void _onTempChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() => _tempError = null);
      widget.onDraftChanged(widget.draft.clear('temperatureC'));
      return;
    }
    final numVal = double.tryParse(val.trim());
    if (numVal == null || numVal < Limits.minTemp || numVal > Limits.maxTemp) {
      setState(() => _tempError = 'Must be between ${Limits.minTemp.toInt()} and ${Limits.maxTemp.toInt()} °C');
      widget.onDraftChanged(widget.draft.clear('temperatureC'));
    } else {
      setState(() => _tempError = null);
      widget.onDraftChanged(widget.draft.copyWith(temperatureC: numVal));
    }
  }

  void _onHumidityChanged(String val) {
    if (val.trim().isEmpty) {
      setState(() => _humidityError = null);
      widget.onDraftChanged(widget.draft.clear('humidityPct'));
      return;
    }
    final numVal = double.tryParse(val.trim());
    if (numVal == null || numVal < 0 || numVal > 100) {
      setState(() => _humidityError = 'Must be between 0 and 100%');
      widget.onDraftChanged(widget.draft.clear('humidityPct'));
    } else {
      setState(() => _humidityError = null);
      widget.onDraftChanged(widget.draft.copyWith(humidityPct: numVal));
    }
  }

  void _onCo2Changed(String val) {
    if (val.trim().isEmpty) {
      setState(() => _co2Error = null);
      widget.onDraftChanged(widget.draft.clear('co2Ppm'));
      return;
    }
    final numVal = double.tryParse(val.trim());
    if (numVal == null || numVal < Limits.minCo2 || numVal > Limits.maxCo2) {
      setState(() => _co2Error = 'Must be between ${Limits.minCo2.toInt()} and ${Limits.maxCo2.toInt()} ppm');
      widget.onDraftChanged(widget.draft.clear('co2Ppm'));
    } else {
      setState(() => _co2Error = null);
      widget.onDraftChanged(widget.draft.copyWith(co2Ppm: numVal));
    }
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_rounded, color: AppColors.forest),
                  const SizedBox(width: 8),
                  Text(
                    'Environmental Ranges',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'These are prototype scoring ranges from the P.U.L.S.E. project, not universal biological safety thresholds.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _buildRangeRow('Temperature', 'Suitable: 18–30 °C', 'Moderate: 15–18 or 30–34 °C'),
              _buildRangeRow('Humidity', 'Suitable: 50–70%', 'Moderate: 35–50 or 70–85%'),
              _buildRangeRow('CO₂', 'Suitable: < 800 ppm', 'Moderate: 800–1000 ppm'),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeRow(String param, String suitable, String mod) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(param, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
          Text('$suitable · $mod', style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int score, String rangeHint) {
    final (label, color, bg) = switch (score) {
      100 => ('Suitable', AppColors.forest, AppColors.sage),
      60 => ('Moderate', const Color(0xFFE65100), const Color(0xFFFFECC8)),
      _ => ('Stressful', AppColors.alert, AppColors.alertSoft),
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            rangeHint,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.draft.temperatureC;
    final h = widget.draft.humidityPct;
    final c = widget.draft.co2Ppm;
    final s = widget.draft.soilMoisturePercent;

    final hasAllThree = t != null && h != null && c != null;
    final score = hasAllThree ? environmentalScore(t, h, c, s) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top info bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sensor & Ambient Readings',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.forest),
              tooltip: 'Scoring threshold info',
              onPressed: _showInfoSheet,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 0. Soil Sensor Panel
        SoilSensorPanel(
          draft: widget.draft,
          onDraftChanged: widget.onDraftChanged,
        ),
        const SizedBox(height: 14),

        // 1. Temperature Card
        ShakeWrapper(
          key: widget.tempKey,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: _tempError != null
                    ? AppColors.alert
                    : (t != null ? AppColors.forest : AppColors.sageBorder),
                width: t != null || _tempError != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.thermostat_outlined, color: Color(0xFF0288D1), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Temperature (°C) *',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '−20 to 60 °C',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tempController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 25',
                    suffixText: '°C',
                    suffixStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.forest),
                    errorText: _tempError,
                  ),
                  onChanged: _onTempChanged,
                ),
                if (t != null && _tempError == null) ...[
                  const SizedBox(height: 8),
                  _buildStatusChip(temperatureScore(t), 'Suitable 18–30 °C'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Humidity Card
        ShakeWrapper(
          key: widget.humidityKey,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: _humidityError != null
                    ? AppColors.alert
                    : (h != null ? AppColors.forest : AppColors.sageBorder),
                width: h != null || _humidityError != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined, color: Color(0xFF0288D1), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Humidity (%) *',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '0 to 100 %',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _humidityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 60',
                    suffixText: '%',
                    suffixStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.forest),
                    errorText: _humidityError,
                  ),
                  onChanged: _onHumidityChanged,
                ),
                if (h != null && _humidityError == null) ...[
                  const SizedBox(height: 8),
                  _buildStatusChip(humidityScore(h), 'Suitable 50–70%'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3. CO2 Card
        ShakeWrapper(
          key: widget.co2Key,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: _co2Error != null
                    ? AppColors.alert
                    : (c != null ? AppColors.forest : AppColors.sageBorder),
                width: c != null || _co2Error != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.co2_rounded, color: Color(0xFF5C6B5C), size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'CO₂ Levels (ppm) *',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '0 to 10000 ppm',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _co2Controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'e.g. 600',
                    suffixText: 'ppm',
                    suffixStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.forest),
                    errorText: _co2Error,
                  ),
                  onChanged: _onCo2Changed,
                ),
                if (c != null && _co2Error == null) ...[
                  const SizedBox(height: 8),
                  _buildStatusChip(co2Score(c), 'Suitable < 800 ppm'),
                  if (c < 300) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.honey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.honey.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFB78103)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Outdoor air is usually around 400 ppm. Check the reading.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFFB78103),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Live Environmental score chip
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: hasAllThree
              ? Container(
                  key: const ValueKey('env_score_card'),
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
                          'Environmental Score',
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
                  key: const ValueKey('env_incomplete_card'),
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
                        'Enter valid readings for all 3 parameters',
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
