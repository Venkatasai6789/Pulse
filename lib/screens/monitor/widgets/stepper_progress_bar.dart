import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StepItemData {
  final String label;
  final IconData icon;

  const StepItemData({required this.label, required this.icon});
}

class StepperProgressBar extends StatelessWidget {
  final int currentStep;
  final List<bool> completedSteps;
  final ValueChanged<int> onStepTapped;

  const StepperProgressBar({
    super.key,
    required this.currentStep,
    required this.completedSteps,
    required this.onStepTapped,
  });

  static const List<StepItemData> steps = [
    StepItemData(label: 'Activity', icon: Icons.pest_control_outlined),
    StepItemData(label: 'Habitat', icon: Icons.local_florist_outlined),
    StepItemData(label: 'Environment', icon: Icons.thermostat_outlined),
    StepItemData(label: 'Risk', icon: Icons.warning_amber_rounded),
    StepItemData(label: 'Review', icon: Icons.fact_check_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.sageBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCurrent = index == currentStep;
          final isCompleted = index < completedSteps.length && completedSteps[index];
          final canTap = isCompleted && index != currentStep;

          return Expanded(
            child: InkWell(
              onTap: canTap ? () => onStepTapped(index) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Step circle / badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent
                            ? AppColors.forest
                            : (isCompleted
                                ? AppColors.sage
                                : Colors.transparent),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.forest
                              : (isCompleted
                                  ? AppColors.forest
                                  : AppColors.sageBorder),
                          width: isCurrent || isCompleted ? 2 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: isCompleted && !isCurrent
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AppColors.forest,
                              )
                            : Icon(
                                steps[index].icon,
                                size: 16,
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.muted,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Label (F14: FittedBox scaleDown to avoid truncation, consistent font weight)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        steps[index].label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppColors.forest
                              : (isCompleted ? AppColors.ink : AppColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
