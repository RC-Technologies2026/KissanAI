import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';

/// Step 3 — Farmer Type (single select, horizontal card layout).
class FarmerTypeScreen extends ConsumerWidget {
  const FarmerTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 3,
      title: 'Tell us about\nyourself',
      showSkipLink: true,
      onSkip: () => context.go(Routes.dashboard),
      canContinue: state.farmerType != null,
      onBack: () {
        ref.read(onboardingProvider.notifier).previousStep();
        context.go(Routes.onboardingLanguage);
      },
      onContinue: () {
        ref.read(onboardingProvider.notifier).nextStep();
        context.go(Routes.onboardingCrops);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose the profile that fits you best.',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 28),

          // Two cards side by side
          Row(
            children: [
              Expanded(
                child: _FarmerTypeCard(
                  icon: Icons.eco_outlined,
                  title: 'New Farmer',
                  subtitle: 'I want step-by-step guidance',
                  isSelected: state.farmerType == 'New Farmer',
                  onTap: () => ref
                      .read(onboardingProvider.notifier)
                      .setFarmerType('New Farmer'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FarmerTypeCard(
                  icon: Icons.grain,
                  title: 'Experienced\nFarmer',
                  subtitle: 'I want to verify my decisions',
                  isSelected: state.farmerType == 'Experienced Farmer',
                  onTap: () => ref
                      .read(onboardingProvider.notifier)
                      .setFarmerType('Experienced Farmer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FarmerTypeCard extends StatelessWidget {
  const _FarmerTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFF5F0E4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 30,
                color: isSelected ? AppColors.primary : AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.headingText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.bodyText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
