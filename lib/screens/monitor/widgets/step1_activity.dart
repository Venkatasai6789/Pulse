import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/phi.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'photo_uploader.dart';
import 'shake_wrapper.dart';

class Step1Activity extends StatefulWidget {
  final Assessment draft;
  final ValueChanged<Assessment> onDraftChanged;
  final GlobalKey<ShakeWrapperState> visitsKey;
  final GlobalKey<ShakeWrapperState> dateKey;
  final GlobalKey<ShakeWrapperState> durationKey;
  final GlobalKey<ShakeWrapperState> weatherKey;

  const Step1Activity({
    super.key,
    required this.draft,
    required this.onDraftChanged,
    required this.visitsKey,
    required this.dateKey,
    required this.durationKey,
    required this.weatherKey,
  });

  @override
  State<Step1Activity> createState() => _Step1ActivityState();
}

class _Step1ActivityState extends State<Step1Activity> {
  // Timer state
  bool _timerOpen = false;
  bool _timerRunning = false;
  int _timerSecondsTotal = 5 * 60;
  int _timerSecondsRemaining = 5 * 60;
  Timer? _countdownTimer;
  Timer? _repeatTimer;
  bool _protocolExpanded = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------ visits counter
  void _changeVisits(int delta) {
    HapticFeedback.selectionClick();
    final current = widget.draft.visits ?? 0;
    final next = (current + delta).clamp(0, Limits.maxVisits);
    widget.onDraftChanged(widget.draft.copyWith(visits: next));
  }

  void _startRepeating(int delta) {
    _changeVisits(delta);
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _changeVisits(delta);
    });
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _promptDirectVisitInput() async {
    final controller = TextEditingController(
      text: widget.draft.visits == null ? '' : widget.draft.visits.toString(),
    );
    final val = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Enter Visits',
          style: GoogleFonts.lora(fontWeight: FontWeight.w700, color: AppColors.forest),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: '0–500',
            labelText: 'Number of pollinator visits',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (val != null) {
      final clamped = val.clamp(0, Limits.maxVisits);
      widget.onDraftChanged(widget.draft.copyWith(visits: clamped));
    }
  }

  // ------------------------------------------------ observation timer
  void _startTimer() {
    setState(() {
      _timerOpen = true;
      _timerRunning = true;
      _timerSecondsTotal = (widget.draft.durationMinutes ?? 5) * 60;
      _timerSecondsRemaining = _timerSecondsTotal;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSecondsRemaining <= 1) {
        timer.cancel();
        _onTimerComplete();
      } else {
        setState(() {
          _timerSecondsRemaining--;
        });
      }
    });
  }

  void _pauseTimer() {
    _countdownTimer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resumeTimer() {
    setState(() => _timerRunning = true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSecondsRemaining <= 1) {
        timer.cancel();
        _onTimerComplete();
      } else {
        setState(() {
          _timerSecondsRemaining--;
        });
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _timerRunning = false;
      _timerOpen = false;
    });
  }

  void _onTimerComplete() {
    HapticFeedback.vibrate();
    final elapsedSec = _timerSecondsTotal - _timerSecondsRemaining;
    final elapsedMin = (elapsedSec / 60).round().clamp(1, 30);
    setState(() {
      _timerRunning = false;
      _timerOpen = false;
    });
    // Set duration to elapsed minutes (or nearest chip)
    final matchedDuration = Limits.durations.contains(elapsedMin)
        ? elapsedMin
        : 5;
    widget.onDraftChanged(widget.draft.copyWith(durationMinutes: matchedDuration));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Observation window completed! Great observation.'),
        backgroundColor: AppColors.forest,
      ),
    );
  }

  void _recordVisitDuringTimer() {
    HapticFeedback.lightImpact();
    final current = widget.draft.visits ?? 0;
    widget.onDraftChanged(widget.draft.copyWith(visits: (current + 1).clamp(0, Limits.maxVisits)));
  }

  // ------------------------------------------------ date & time pickers
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = widget.draft.observedAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.forest,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.ink,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final initialTime = TimeOfDay.fromDateTime(widget.draft.observedAt ?? now);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.forest,
            onPrimary: Colors.white,
            surface: AppColors.card,
            onSurface: AppColors.ink,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    widget.onDraftChanged(widget.draft.copyWith(observedAt: combined));
  }

  bool _isSoftWarningCondition() {
    final d = widget.draft;
    final isOffHour = d.observedAt != null && d.observedAt!.hour != 10;
    final isUnfavourableWeather = d.weather != null &&
        ['Windy', 'Light rain', 'Rain'].contains(d.weather);
    return isOffHour || isUnfavourableWeather;
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.draft.visits;
    final weatherList = [
      ('Sunny', Icons.wb_sunny_rounded),
      ('Partly cloudy', Icons.cloud_queue_rounded),
      ('Cloudy', Icons.cloud_rounded),
      ('Windy', Icons.air_rounded),
      ('Light rain', Icons.grain_rounded),
      ('Rain', Icons.water_drop_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Number of pollinator visits *
        ShakeWrapper(
          key: widget.visitsKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: visits == null ? AppColors.sageBorder : AppColors.forest,
                width: visits == null ? 1.0 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Number of Pollinator Visits *',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (visits != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '0–500 allowed',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Round − and + buttons (56 px) around a big editable number (Inter 40)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decrement button
                    GestureDetector(
                      onLongPressStart: (_) => _startRepeating(-1),
                      onLongPressEnd: (_) => _stopRepeating(),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: visits == null ? null : () => _changeVisits(-1),
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: AppColors.forest, width: 1.5),
                            backgroundColor: AppColors.sage.withValues(alpha: 0.3),
                          ),
                          child: const Icon(Icons.remove_rounded, size: 26, color: AppColors.forest),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Big number or dash
                    GestureDetector(
                      onTap: _promptDirectVisitInput,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cream.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          visits == null ? '0' : '$visits',
                          style: GoogleFonts.inter(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: visits == null
                                ? AppColors.muted.withValues(alpha: 0.4)
                                : AppColors.forest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Increment button
                    GestureDetector(
                      onLongPressStart: (_) => _startRepeating(1),
                      onLongPressEnd: (_) => _stopRepeating(),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            if (visits == null) {
                              widget.onDraftChanged(widget.draft.copyWith(visits: 1));
                            } else {
                              _changeVisits(1);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: AppColors.forest, width: 1.5),
                            backgroundColor: AppColors.sage.withValues(alpha: 0.3),
                          ),
                          child: const Icon(Icons.add_rounded, size: 26, color: AppColors.forest),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  visits == null
                      ? 'Use + and −, or tap the number to type it'
                      : 'Tap number to edit directly',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Observation Timer Card (advanced, optional)
        if (!_timerOpen)
          OutlinedButton.icon(
            onPressed: _startTimer,
            icon: const Icon(Icons.timer_outlined, color: AppColors.forest),
            label: const Text('Start 5-min observation timer'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.forest, width: 1.2),
            ),
          )
        else
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
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: AppColors.forest, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Observation Timer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
                      onPressed: _stopTimer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Countdown text
                Text(
                  '${(_timerSecondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_timerSecondsRemaining % 60).toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 12),
                // Huge "Tap each visit" button with haptic feedback
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _timerRunning ? _recordVisitDuringTimer : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.touch_app_rounded, size: 26),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Tap each visit! (${visits ?? 0})',
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_timerRunning)
                      TextButton.icon(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause_rounded, size: 18),
                        label: const Text('Pause'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: _resumeTimer,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Resume'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _stopTimer,
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Stop & Use Count'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // 2. Date & time *
        ShakeWrapper(
          key: widget.dateKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Date & Time *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.access_time_rounded, size: 14, color: AppColors.forest),
                    label: const Text('Use now'),
                    labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onDraftChanged(widget.draft.copyWith(observedAt: DateTime.now()));
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: widget.draft.observedAt == null
                          ? AppColors.sageBorder
                          : AppColors.forest,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.forest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.draft.observedAt != null
                              ? DateFormat('d MMM yyyy, h:mm a')
                                  .format(widget.draft.observedAt!)
                              : 'Select date & time',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: widget.draft.observedAt != null
                                ? AppColors.ink
                                : AppColors.muted,
                            fontWeight: widget.draft.observedAt != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Observation duration * (5 / 10 / 15 / 20 / 30 min)
        ShakeWrapper(
          key: widget.durationKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Observation Duration *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Limits.durations.map((duration) {
                  final isSelected = widget.draft.durationMinutes == duration;
                  return ChoiceChip(
                    label: Text('$duration min'),
                    selected: isSelected,
                    selectedColor: AppColors.forestDark,
                    checkmarkColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.ink,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        widget.onDraftChanged(
                          widget.draft.copyWith(durationMinutes: duration),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Weather conditions * (icon chips)
        ShakeWrapper(
          key: widget.weatherKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weather Conditions *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: weatherList.map((item) {
                  final name = item.$1;
                  final icon = item.$2;
                  final isSelected = widget.draft.weather == name;

                  return ChoiceChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.forest,
                    ),
                    label: Text(name),
                    selected: isSelected,
                    selectedColor: AppColors.forestDark,
                    checkmarkColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.ink,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        widget.onDraftChanged(widget.draft.copyWith(weather: name));
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Collapsible card "How to observe" (Protocol tip)
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _protocolExpanded,
                onExpansionChanged: (exp) => setState(() => _protocolExpanded = exp),
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.forest),
                title: Text(
                  'How to observe',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      'Observe a marked 2 m × 2 m patch of flowers for 5 minutes. Count each insect visit (landing on flowers). The best time is 10:00–11:00 AM on a warm, calm, sunny day.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Soft warning banner (amber, not blocking)
        if (_isSoftWarningCondition()) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Counts may be lower than usual in these conditions (outside 10–11 AM or windy/rainy weather).',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF5D4037),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Add a photograph (optional)
        PhotoUploader(
          assessmentId: widget.draft.id,
          photoPaths: widget.draft.activityPhotoPaths,
          onPhotosChanged: (photos) {
            widget.onDraftChanged(widget.draft.copyWith(activityPhotoPaths: photos));
          },
          label: 'Add a Photograph (Optional)',
        ),
      ],
    );
  }
}
