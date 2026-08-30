import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'step_progress_bar.dart';

/// Shared scaffold for all onboarding steps.
///
/// Contains:
/// - Translucent farmer portrait background at top (~15% opacity)
/// - 7-segment [StepProgressBar]
/// - Bold H1 title
/// - Scrollable [child] body
/// - Fixed Back / Continue button row
/// - Optional "Skip and explore demo" link
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.currentStep,
    required this.title,
    required this.child,
    required this.onContinue,
    required this.onBack,
    this.onSkip,
    this.continueLabel = 'Continue',
    this.canContinue = true,
    this.isLoading = false,
    this.showSkipLink = false,
    this.totalSteps = 7,
  });

  final int currentStep;
  final String title;
  final Widget child;
  final VoidCallback onContinue;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  final String continueLabel;
  final bool canContinue;
  final bool isLoading;
  final bool showSkipLink;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Translucent farmer portrait behind top ~25% of screen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.28,
            child: Opacity(
              opacity: 0.15,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFB8D4A8), // muted green foliage tint
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.agriculture,
                    size: 120,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  StepProgressBar(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: child,
                    ),
                  ),
                  _ButtonRow(
                    onBack: onBack,
                    onContinue: onContinue,
                    continueLabel: continueLabel,
                    canContinue: canContinue,
                    isLoading: isLoading,
                  ),
                  if (showSkipLink && onSkip != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: onSkip,
                        child: const Text(
                          'Skip and explore demo',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.bodyText,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.bodyText,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.onBack,
    required this.onContinue,
    required this.continueLabel,
    required this.canContinue,
    required this.isLoading,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String continueLabel;
  final bool canContinue;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Back — white bg + green border, ~35% width
        Expanded(
          flex: 35,
          child: OutlinedButton(
            onPressed: isLoading ? null : onBack,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        // Continue — solid green, ~65% width
        Expanded(
          flex: 65,
          child: ElevatedButton(
            onPressed: canContinue && !isLoading ? onContinue : null,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(continueLabel),
          ),
        ),
      ],
    );
  }
}
