import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../router/app_router.dart';

/// Animated splash screen — logo reveal with smooth staggered animation.
/// Checks auth status and navigates to dashboard or welcome accordingly.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _leafLeftSlide;
  late final Animation<double> _leafRightSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );

    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.50, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.55, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
      ),
    );

    _leafLeftSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _leafRightSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), _navigate);
    });
  }

  void _navigate() {
    if (!mounted) return;
    final authState = ref.read(authProvider);
    // If still initializing, wait a bit longer and retry
    if (authState.status == AuthStatus.initial) {
      Future.delayed(const Duration(milliseconds: 300), _navigate);
      return;
    }
    if (authState.status == AuthStatus.authenticated) {
      context.go(Routes.dashboard);
    } else {
      context.go(Routes.welcome);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Farmer portrait background (low opacity)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/splash_farmer.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.25),
                  ),
                ),
              ),

              // Subtle radial gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFFE8F5E9).withValues(alpha: 0.5),
                      AppColors.background,
                    ],
                  ),
                ),
              ),

              // Decorative floating leaves (left)
              Positioned(
                left: _leafLeftSlide.value,
                top: MediaQuery.sizeOf(context).height * 0.25,
                child: Opacity(
                  opacity: _iconOpacity.value * 0.15,
                  child: const Icon(Icons.eco,
                      color: AppColors.primary, size: 80),
                ),
              ),

              // Decorative floating leaves (right)
              Positioned(
                right: _leafRightSlide.value,
                top: MediaQuery.sizeOf(context).height * 0.35,
                child: Opacity(
                  opacity: _iconOpacity.value * 0.12,
                  child: const Icon(Icons.grass,
                      color: AppColors.primary, size: 60),
                ),
              ),

              // Centre content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo icon with glow
                    Transform.scale(
                      scale: _iconScale.value,
                      child: Opacity(
                        opacity: _iconOpacity.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25 * _glowOpacity.value),
                                    blurRadius: 60,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            // Logo image
                            Image.asset(
                              'assets/images/kisan_ai_icon.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // "Kisan AI" text
                    Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: const Text(
                          'Kisan AI',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headingText,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Localized tagline
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        ref.watch(languageProvider).t('app.tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.bodyText,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Loading indicator
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
