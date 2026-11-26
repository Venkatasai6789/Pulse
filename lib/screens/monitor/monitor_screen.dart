import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/soil_reading.dart';
import '../../data/api_service.dart';
import '../../hardware/models/node_connection.dart';
import '../../hardware/sensor_node_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'widgets/location_picker_card.dart';
import 'widgets/shake_wrapper.dart';
import 'widgets/step_card_frame.dart';
import 'widgets/stepper_progress_bar.dart';
import 'widgets/step1_activity.dart';
import 'widgets/step2_habitat.dart';
import 'widgets/step3_environment.dart';
import 'widgets/step4_risk.dart';
import 'widgets/step5_review.dart';

class MonitorScreen extends StatefulWidget {
  final String? locationId;
  final String? preselectedLocationId;

  const MonitorScreen({
    super.key,
    this.locationId,
    this.preselectedLocationId,
  });

  String? get effectiveLocationId => locationId ?? preselectedLocationId;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final PageController _pageController;
  int _currentStep = 0;

  // Locations
  List<Location> _locations = [];
  Map<String, int?> _latestPhis = {};
  bool _loadingLocations = true;

  // Draft state
  late Assessment _draft;
  Assessment? _resumableDraft;
  Location? _draftLocation;
  bool _showResumeBanner = false;

  Timer? _debounceTimer;
  bool _isSubmitting = false;

  // Shake keys for step validation
  final _locationShakeKey = GlobalKey<ShakeWrapperState>();
  // Step 1
  final _visitsKey = GlobalKey<ShakeWrapperState>();
  final _dateKey = GlobalKey<ShakeWrapperState>();
  final _durationKey = GlobalKey<ShakeWrapperState>();
  final _weatherKey = GlobalKey<ShakeWrapperState>();
  // Step 2
  final _flowersKey = GlobalKey<ShakeWrapperState>();
  final _nestingKey = GlobalKey<ShakeWrapperState>();
  final _shelterKey = GlobalKey<ShakeWrapperState>();
  final _waterKey = GlobalKey<ShakeWrapperState>();
  // Step 3
  final _tempKey = GlobalKey<ShakeWrapperState>();
  final _humidityKey = GlobalKey<ShakeWrapperState>();
  final _co2Key = GlobalKey<ShakeWrapperState>();
  // Step 4
  final _riskLevelKey = GlobalKey<ShakeWrapperState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initFreshDraft();
    _loadInitialData();
  }

  void _initFreshDraft() {
    _draft = Assessment(
      id: newId(),
      locationId: widget.effectiveLocationId,
      status: AssessmentStatus.draft,
      durationMinutes: 5,
      createdAt: DateTime.now(),
    );
  }

  @override
  void didUpdateWidget(covariant MonitorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.effectiveLocationId != null &&
        widget.effectiveLocationId != oldWidget.effectiveLocationId &&
        widget.effectiveLocationId != _draft.locationId) {
      setState(() {
        _draft = _draft.copyWith(locationId: widget.effectiveLocationId);
      });
      _scheduleAutosave();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final api = context.read<ApiService>();
    try {
      final locs = await api.getLocations();
      final phis = <String, int?>{};
      for (final l in locs) {
        final latest = await api.latestAssessment(l.id);
        phis[l.id] = latest?.result?.phi;
      }

      // Check for any saved drafts
      final allAssessments = await api.getAssessments(submittedOnly: false);
      final existing = allAssessments.where((a) => !a.isSubmitted).firstOrNull;

      Location? draftLoc;
      if (existing != null && existing.locationId != null) {
        draftLoc = locs.where((l) => l.id == existing.locationId).firstOrNull;
      }

      if (mounted) {
        setState(() {
          _locations = locs;
          _latestPhis = phis;
          _loadingLocations = false;
          if (existing != null) {
            _resumableDraft = existing;
            _draftLocation = draftLoc;
            _showResumeBanner = true;
          } else if (widget.effectiveLocationId != null) {
            _draft = _draft.copyWith(locationId: widget.effectiveLocationId);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  void _scheduleAutosave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        final api = context.read<ApiService>();
        await api.saveDraft(_draft);
      } catch (_) {}
    });
  }

  void _onDraftChanged(Assessment updated) {
    setState(() {
      _draft = updated;
    });
    _scheduleAutosave();
  }

  Future<void> _saveDraftExplicitly() async {
    _debounceTimer?.cancel();
    try {
      final api = context.read<ApiService>();
      await api.saveDraft(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully.'),
            backgroundColor: AppColors.forest,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft: $e')),
        );
      }
    }
  }

  void _resumeDraft() {
    if (_resumableDraft == null) return;
    setState(() {
      _draft = _resumableDraft!;
      _showResumeBanner = false;
    });
    _scheduleAutosave();
  }

  Future<void> _discardDraft() async {
    if (_resumableDraft != null) {
      final api = context.read<ApiService>();
      await api.deleteDraft(_resumableDraft!.id);
    }
    setState(() {
      _resumableDraft = null;
      _showResumeBanner = false;
      _initFreshDraft();
    });
  }

  bool _isStep0Complete() {
    return _draft.locationId != null &&
        _draft.visits != null &&
        _draft.observedAt != null &&
        _draft.durationMinutes != null &&
        _draft.weather != null;
  }

  bool _isStep1Complete() {
    return _draft.flowers != null &&
        _draft.nesting != null &&
        _draft.shelter != null &&
        _draft.water != null;
  }

  bool _isStep2Complete() {
    return _draft.temperatureC != null &&
        _draft.humidityPct != null &&
        _draft.co2Ppm != null;
  }

  bool _isStep3Complete() {
    return _draft.riskLevel != null;
  }

  List<bool> _getCompletedSteps() {
    return [
      _isStep0Complete(),
      _isStep1Complete(),
      _isStep2Complete(),
      _isStep3Complete(),
      _draft.isComplete,
    ];
  }

  void _goToStep(int step) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateAndProceed() {
    if (_currentStep == 0) {
      if (_draft.locationId == null) {
        _locationShakeKey.currentState?.shake();
        return false;
      }
      if (_draft.visits == null) {
        _visitsKey.currentState?.shake();
        return false;
      }
      if (_draft.observedAt == null) {
        _dateKey.currentState?.shake();
        return false;
      }
      if (_draft.durationMinutes == null) {
        _durationKey.currentState?.shake();
        return false;
      }
      if (_draft.weather == null) {
        _weatherKey.currentState?.shake();
        return false;
      }
      _goToStep(1);
      return true;
    } else if (_currentStep == 1) {
      if (_draft.flowers == null) {
        _flowersKey.currentState?.shake();
        return false;
      }
      if (_draft.nesting == null) {
        _nestingKey.currentState?.shake();
        return false;
      }
      if (_draft.shelter == null) {
        _shelterKey.currentState?.shake();
        return false;
      }
      if (_draft.water == null) {
        _waterKey.currentState?.shake();
        return false;
      }
      _goToStep(2);
      return true;
    } else if (_currentStep == 2) {
      if (_draft.temperatureC == null) {
        _tempKey.currentState?.shake();
        return false;
      }
      if (_draft.humidityPct == null) {
        _humidityKey.currentState?.shake();
        return false;
      }
      if (_draft.co2Ppm == null) {
        _co2Key.currentState?.shake();
        return false;
      }
      if (_draft.soil == null) {
        final sensorController = context.readSensorNode();
        if (sensorController != null &&
            sensorController.state == NodeConnection.online &&
            sensorController.latest != null &&
            sensorController.latest!.isFresh &&
            sensorController.latest!.isSensorOk) {
          unawaited(() async {
            final autoReading = await sensorController.capture();
            if (autoReading != null && mounted) {
              setState(() {
                _draft = _draft.copyWith(soil: autoReading);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Soil moisture ${autoReading.percent.toInt()} % captured from sensor',
                  ),
                ),
              );
            }
          }());
        }
      }
      _goToStep(3);
      return true;
    } else if (_currentStep == 3) {
      if (_draft.riskLevel == null) {
        _riskLevelKey.currentState?.shake();
        return false;
      }
      _goToStep(4);
      return true;
    } else if (_currentStep == 4) {
      _submitAssessment();
      return true;
    }
    return true;
  }

  Future<void> _submitAssessment() async {
    if (!_draft.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete: ${_draft.missingFields.join(', ')}'),
          backgroundColor: AppColors.alert,
        ),
      );
      return;
    }

    // Stale capture check (> 30 mins)
    if (_draft.soil != null && _draft.soil!.source == SoilSource.esp32) {
      final ageMinutes = DateTime.now().difference(_draft.soil!.capturedAt).inMinutes;
      if (ageMinutes >= 30) {
        final sensorController = context.readSensorNode();
        final isOnline = sensorController?.state == NodeConnection.online;
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Soil reading is $ageMinutes min old'),
            content: const Text(
              'Take a fresh reading from the sensor before calculating?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keep'),
              ),
              if (isOnline)
                FilledButton(
                  onPressed: () async {
                    final fresh = await sensorController?.capture();
                    if (fresh != null) {
                      setState(() => _draft = _draft.copyWith(soil: fresh));
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Refresh'),
                ),
            ],
          ),
        );
        if (shouldProceed != true) return;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();
    final sensorController = context.readSensorNode();

    try {
      // LeafLoader for at least 800 ms
      final results = await Future.wait([
        api.submitAssessment(_draft),
        Future.delayed(const Duration(milliseconds: 900)),
      ]);

      final submitted = results.first as Assessment;

      // Push PHI to node display (fire and forget)
      if (submitted.result != null && sensorController != null) {
        final loc = _locations.where((l) => l.id == submitted.locationId).firstOrNull;
        sensorController.pushPhi(submitted.result!, loc?.name ?? 'Site');
      }

      if (mounted) {
        context.go('/results/${submitted.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting assessment: $e'),
            backgroundColor: AppColors.alert,
          ),
        );
      }
    }
  }

  bool _hasUnsavedChanges() {
    return _draft.visits != null ||
        _draft.flowers != null ||
        _draft.temperatureC != null ||
        _draft.riskLevel != null;
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Save draft before leaving?',
          style: GoogleFonts.lora(fontWeight: FontWeight.w700, color: AppColors.forest),
        ),
        content: Text(
          'You have unsubmitted progress for this assessment.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard', style: TextStyle(color: AppColors.alert)),
          ),
          FilledButton(
            onPressed: () async {
              await _saveDraftExplicitly();
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLocations) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Center(
            child: LeafLoader(message: 'Loading assessment...'),
          ),
        ),
      );
    }

    final completedSteps = _getCompletedSteps();
    final remainingFieldsCount = _draft.missingFields.length;
    final selectedLoc = _locations
        .where((l) => l.id == _draft.locationId)
        .firstOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep > 0) {
          _goToStep(_currentStep - 1);
        } else {
          if (_hasUnsavedChanges()) {
            final saved = await _showExitConfirmation();
            if (saved && context.mounted) {
              context.go('/');
            }
          } else {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.cream,
            body: SafeArea(
              child: Column(
                children: [
                  // Top Fixed Region: Header, Resume Banner, Location Card, Stepper
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Header with bee background image (F13: constrained to right 35%, fade mask, hidden < 380dp)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final showBee = constraints.maxWidth >= 380;
                            return Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                              child: Stack(
                                children: [
                                  if (showBee)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: constraints.maxWidth * 0.35,
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [Colors.transparent, Colors.white],
                                          stops: [0.0, 0.45],
                                        ).createShader(bounds),
                                        blendMode: BlendMode.dstIn,
                                        child: Opacity(
                                          opacity: 0.18,
                                          child: Image.asset(
                                            'assets/images/header_bee.jpg',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'New Assessment',
                                          style: GoogleFonts.lora(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Record what you see at this site',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Resume draft banner if any
                        if (_showResumeBanner) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.sage.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                              border: Border.all(color: AppColors.forest),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, color: AppColors.forest, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Continue your draft for ${_draftLocation?.name ?? 'Location'}?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _resumeDraft,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  child: const Text(
                                    'Continue',
                                    style: TextStyle(color: AppColors.forest, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _discardDraft,
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // 2. Location Card (required, always visible at top)
                        ShakeWrapper(
                          key: _locationShakeKey,
                          child: LocationPickerCard(
                            locations: _locations,
                            latestPhis: _latestPhis,
                            selectedLocationId: _draft.locationId,
                            hasError: _draft.locationId == null && _currentStep > 0,
                            onLocationSelected: (id) {
                              setState(() {
                                _draft = _draft.copyWith(locationId: id);
                              });
                              _scheduleAutosave();
                            },
                            onLocationCreated: () => _loadInitialData(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 3. Step Progress Bar (5 segments)
                        StepperProgressBar(
                          currentStep: _currentStep,
                          completedSteps: completedSteps,
                          onStepTapped: (step) => _goToStep(step),
                        ),
                      ],
                    ),
                  ),

                  // Middle Region: Smooth horizontal slide between steps (PageView)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (step) => setState(() => _currentStep = step),
                      children: [
                        // Step 1: Pollinator Activity
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: StepCardFrame(
                            stepNumber: 1,
                            title: 'Pollinator Activity',
                            subtitle: 'Observe and record pollinator visits in a 5-minute window',
                            illustration: const Icon(Icons.pest_control_outlined, color: Color(0xFFE65100), size: 28),
                            child: Step1Activity(
                              draft: _draft,
                              onDraftChanged: _onDraftChanged,
                              visitsKey: _visitsKey,
                              dateKey: _dateKey,
                              durationKey: _durationKey,
                              weatherKey: _weatherKey,
                            ),
                          ),
                        ),

                        // Step 2: Habitat Quality
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: StepCardFrame(
                            stepNumber: 2,
                            title: 'Habitat Quality',
                            subtitle: 'Assess the availability of key habitat features',
                            illustration: const Icon(Icons.local_florist_rounded, color: Color(0xFFE91E63), size: 28),
                            child: Step2Habitat(
                              draft: _draft,
                              onDraftChanged: _onDraftChanged,
                              flowersKey: _flowersKey,
                              nestingKey: _nestingKey,
                              shelterKey: _shelterKey,
                              waterKey: _waterKey,
                            ),
                          ),
                        ),

                        // Step 3: Environmental Conditions
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: StepCardFrame(
                            stepNumber: 3,
                            title: 'Environmental Conditions',
                            subtitle: 'Record temperature, humidity and CO₂ levels',
                            illustration: const Icon(Icons.thermostat_outlined, color: Color(0xFF0288D1), size: 28),
                            child: Step3Environment(
                              draft: _draft,
                              onDraftChanged: _onDraftChanged,
                              tempKey: _tempKey,
                              humidityKey: _humidityKey,
                              co2Key: _co2Key,
                            ),
                          ),
                        ),

                        // Step 4: Potential Risks
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: StepCardFrame(
                            stepNumber: 4,
                            title: 'Potential Risks',
                            subtitle: 'Identify any potential risks in the area',
                            illustration: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 28),
                            child: Step4Risk(
                              draft: _draft,
                              onDraftChanged: _onDraftChanged,
                              riskLevelKey: _riskLevelKey,
                            ),
                          ),
                        ),

                        // Step 5: Review & Calculate
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          child: StepCardFrame(
                            stepNumber: 5,
                            title: 'Review & Calculate',
                            subtitle: 'Review your entries and calculate the Pollinator Health Index',
                            illustration: const Icon(Icons.fact_check_outlined, color: AppColors.forest, size: 28),
                            child: Step5Review(
                              draft: _draft,
                              selectedLocation: selectedLoc,
                              onJumpToStep: (step) => _goToStep(step),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Fixed Region: Sticky Bottom Bar (SafeArea)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: const BoxDecoration(
                      color: AppColors.card,
                      border: Border(
                        top: BorderSide(color: AppColors.sageBorder, width: 1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status counter above bar
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: remainingFieldsCount == 0
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.leaf, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All set ✓',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.leaf,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '$remainingFieldsCount required ${remainingFieldsCount == 1 ? 'field' : 'fields'} left',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.muted,
                                  ),
                                ),
                        ),
                        // Buttons row
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: OutlinedButton(
                                onPressed: _saveDraftExplicitly,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.forest, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: Text(
                                  'Save draft',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: FilledButton(
                                onPressed: _validateAndProceed,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.forestDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: Text(
                                  _currentStep == 4 ? 'Calculate PHI →' : 'Next →',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay on submit
          if (_isSubmitting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  color: AppColors.card,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LeafLoader(size: 52),
                        SizedBox(height: 16),
                        Text(
                          'Calculating PHI...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
