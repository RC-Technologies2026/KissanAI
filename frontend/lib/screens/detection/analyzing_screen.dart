import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import 'camera_picker_screen.dart';

/// Screen 3 — Analyzing (loading).
///
/// Shows a pulsing green circle with leaf icon, then auto-navigates
/// to the result screen after a 2-second mock delay.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.detectionType});

  final DetectionType detectionType;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-navigate to result after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.pushReplacement(
          '/detection/result',
          extra: {'detectionType': widget.detectionType},
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing green circle with leaf icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.eco,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Bold text
            const Text(
              'Analyzing your crop...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 8),

            // Muted subtitle
            const Text(
              'Our AI is examining the image for disease patterns',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
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
