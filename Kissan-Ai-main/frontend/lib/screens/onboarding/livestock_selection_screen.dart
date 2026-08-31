import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Livestock data with icon + label for the 2-column grid.
class _LivestockItem {
  const _LivestockItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

const _livestock = [
  _LivestockItem(label: 'Cattle', icon: Icons.pets),
  _LivestockItem(label: 'Buffalo', icon: Icons.water),
  _LivestockItem(label: 'Goat', icon: Icons.emoji_nature),
  _LivestockItem(label: 'Poultry', icon: Icons.flutter_dash),
  _LivestockItem(label: 'None', icon: Icons.block),
];

/// Step 5 — Livestock (multi-select, 2-column grid of icon cards).
class LivestockSelectionScreen extends ConsumerWidget {
  const LivestockSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 5,
      title: 'Do you keep\nlivestock?',
      showSkipLink: true,
      onSkip: () => context.go(Routes.dashboard),
      canContinue: true, // "None" is a valid choice
      onBack: () {
        ref.read(onboardingProvider.notifier).previousStep();
        context.go(Routes.onboardingCrops);
      },
      onContinue: () {
        ref.read(onboardingProvider.notifier).nextStep();
        context.go(Routes.onboardingFarmSize);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select all livestock you keep (multi-select).',
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
            children: _livestock.map((item) {
              final isSelected =
                  state.selectedLivestock.contains(item.label);
              return GestureDetector(
                onTap: () => ref
                    .read(onboardingProvider.notifier)
                    .toggleLivestock(item.label),
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
                        item.icon,
                        size: 26,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.bodyText,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
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
