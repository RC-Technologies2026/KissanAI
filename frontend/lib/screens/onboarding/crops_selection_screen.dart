import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Crop data with icon + label for the 2-column grid.
class _CropItem {
  const _CropItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

const _crops = [
  _CropItem(label: 'Wheat', icon: Icons.grain),
  _CropItem(label: 'Rice', icon: Icons.rice_bowl),
  _CropItem(label: 'Cotton', icon: Icons.yard),
  _CropItem(label: 'Maize', icon: Icons.grass),
  _CropItem(label: 'Sugarcane', icon: Icons.water_drop),
  _CropItem(label: 'Vegetables', icon: Icons.eco),
  _CropItem(label: 'Fruits', icon: Icons.apple),
  _CropItem(label: 'Other', icon: Icons.more_horiz),
];

/// Step 4 — Crops (multi-select, 2-column grid of icon cards).
class CropsSelectionScreen extends ConsumerWidget {
  const CropsSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 4,
      title: 'What do you\ngrow?',
      showSkipLink: true,
      onSkip: () => context.go(Routes.dashboard),
      canContinue: state.selectedCrops.isNotEmpty,
      onBack: () {
        ref.read(onboardingProvider.notifier).previousStep();
        context.go(Routes.onboardingFarmerType);
      },
      onContinue: () {
        ref.read(onboardingProvider.notifier).nextStep();
        context.go(Routes.onboardingLivestock);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select all crops you grow (multi-select).',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 24),
          // 2-column grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: _crops.map((crop) {
              final isSelected =
                  state.selectedCrops.contains(crop.label);
              return GestureDetector(
                onTap: () => ref
                    .read(onboardingProvider.notifier)
                    .toggleCrop(crop.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.divider,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        crop.icon,
                        size: 26,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.bodyText,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          crop.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.headingText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
