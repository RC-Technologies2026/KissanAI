import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/detection_provider.dart';
import 'camera_picker_screen.dart';

/// Screen 3 — Analyzing (loading).
///
/// Shows a pulsing green circle with leaf icon while the real
/// /api/disease/detect or /api/pests/detect call runs, then navigates
/// to the result screen once the API responds (success or failure —
/// the result screen renders both states).
class AnalyzingScreen extends ConsumerStatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.detectionType,
    this.imagePath,
  });

  final DetectionType detectionType;
  final String? imagePath;

  @override
  ConsumerState<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends ConsumerState<AnalyzingScreen>
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

    // Run the real detection; navigate as soon as it completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  Future<void> _analyze() async {
    final path = widget.imagePath;
    if (path == null) {
      // Nothing to analyze — send the user back to capture a photo.
      if (mounted) context.pop();
      return;
    }

    await ref.read(detectionProvider.notifier).analyze(
          type: widget.detectionType,
          filePath: path,
        );

    if (mounted) {
      context.pushReplacement(
        '/detection/result',
        extra: {'detectionType': widget.detectionType},
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
      ),
    );
  }
}
