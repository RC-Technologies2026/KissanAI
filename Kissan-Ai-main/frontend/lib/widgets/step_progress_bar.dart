import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// 6-segment horizontal progress bar for the onboarding flow.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 7,
  });

  final int currentStep; // 0-based
  final int totalSteps; // default 7 segments per reference design

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index <= currentStep;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? 6 : 0,
            ),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
