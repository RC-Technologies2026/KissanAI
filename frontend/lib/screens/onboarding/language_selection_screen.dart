import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/language_option.dart';

/// Language options with native script + English name.
const _languages = [
  LanguageOptionData(englishName: 'Urdu', nativeScript: 'اردو', value: 'Urdu'),
  LanguageOptionData(englishName: 'Punjabi', nativeScript: 'پنجابی', value: 'Punjabi'),
  LanguageOptionData(englishName: 'Sindhi', nativeScript: 'سنڌي', value: 'Sindhi'),
  LanguageOptionData(englishName: 'Pashto', nativeScript: 'پښتو', value: 'Pashto'),
  LanguageOptionData(englishName: 'Balochi', nativeScript: 'بلوچی', value: 'Balochi'),
];

/// Step 2 — Language Selection (single select, native script rows).
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 2,
      title: 'Which language\nwould you like\nto use?',
      showSkipLink: true,
      onSkip: () => context.go(Routes.dashboard),
      canContinue: state.language != null,
      onBack: () {
        ref.read(onboardingProvider.notifier).previousStep();
        context.go(Routes.onboardingFarmLocation);
      },
      onContinue: () {
        ref.read(onboardingProvider.notifier).nextStep();
        context.go(Routes.onboardingFarmerType);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your preferred language for the app.',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 24),
          ..._languages.map((lang) {
            final isSelected = state.language == lang.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LanguageOption(
                data: lang,
                isSelected: isSelected,
                onTap: () =>
                    ref.read(onboardingProvider.notifier).setLanguage(lang.value),
              ),
            );
          }),
        ],
      ),
    );
  }
}
