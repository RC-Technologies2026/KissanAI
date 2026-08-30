import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/core_providers.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../core/storage/local_storage.dart';

/// Step 6 — Farm Size (stepper + unit selector).
class FarmSizeScreen extends ConsumerWidget {
  const FarmSizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 6,
      title: 'Farm Size',
      continueLabel: 'Finish',
      canContinue: state.farmSize > 0,
      isLoading: state.isSubmitting,
      onBack: () {
        ref.read(onboardingProvider.notifier).previousStep();
        context.go(Routes.onboardingLivestock);
      },
      onContinue: () async {
        final notifier = ref.read(onboardingProvider.notifier);
        notifier.setSubmitting(true);

        try {
          final api = ref.read(apiClientProvider);
          await api.submitOnboarding(state.toPayload());

          // Mark onboarding as complete
          LocalStorage.instance.onboardingComplete = true;
          notifier.setSubmitting(false);

          if (context.mounted) {
            context.go(Routes.dashboard);
          }
        } catch (e) {
          notifier.setError(e.toString());
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Submission failed: $e')),
            );
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How large is your farm?',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 32),

          // Unit selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: OnboardingData.sizeUnits.map((unit) {
              final isSelected = state.sizeUnit == unit;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => ref
                      .read(onboardingProvider.notifier)
                      .setSizeUnit(unit),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.headingText,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),

          // Size display
          Center(
            child: Text(
              '${state.farmSize.toStringAsFixed(1)}',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          Center(
            child: Text(
              state.sizeUnit.toLowerCase(),
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.bodyText,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton(
                icon: Icons.remove,
                onPressed: state.farmSize > 0
                    ? () => ref
                        .read(onboardingProvider.notifier)
                        .setFarmSize(
                            (state.farmSize - 0.5).clamp(0, 9999))
                    : null,
              ),
              const SizedBox(width: 40),
              _stepButton(
                icon: Icons.add,
                onPressed: () => ref
                    .read(onboardingProvider.notifier)
                    .setFarmSize(
                        (state.farmSize + 0.5).clamp(0, 9999)),
              ),
            ],
          ),

          if (state.error != null) ...[
            const SizedBox(height: 20),
            Text(
              state.error!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? AppColors.divider : AppColors.primary,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
