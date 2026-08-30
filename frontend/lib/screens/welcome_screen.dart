import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../router/app_router.dart';
import '../widgets/pill_button.dart';

/// Welcome / landing screen — first thing users see.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Full Kisan AI logo with text and Urdu tagline
              Image.asset(
                'assets/images/kisan_ai_logo.png',
                width: 320,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),

              const Spacer(flex: 3),

              // Get Started → Register
              PillButton(
                label: lang.t('welcome.get_started'),
                onPressed: () => context.go(Routes.register),
              ),
              const SizedBox(height: 16),

              // Skip and explore demo link
              GestureDetector(
                onTap: () => context.go(Routes.dashboard),
                child: Text(
                  lang.t('welcome.skip_demo'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.bodyText,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.bodyText,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
