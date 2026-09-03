import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/detection_provider.dart';
import '../../providers/language_provider.dart';
import 'camera_picker_screen.dart';

/// Screen 3 — Analyzing (loading).
///
/// Kicks off the real /api/disease/detect or /api/pests/detect call and
/// shows a pulsing green circle with leaf icon while it's in flight.
/// Navigates to the result screen only once the real API call has
/// finished (success OR failure) — never on a fixed timer.
class AnalyzingScreen extends ConsumerStatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.detectionType,
    required this.imagePath,
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
  bool _started = false;

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

    // Kick off the real analysis after first frame (needs ref + imagePath).
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnalysis());
  }

  void _startAnalysis() {
    if (_started) return;
    _started = true;

    final path = widget.imagePath;
    if (path == null) {
      // No image was passed in — nothing to analyze, bail out cleanly.
      context.pushReplacement(
        '/detection/result',
        extra: {'detectionType': widget.detectionType},
      );
      return;
    }

    final language = ref.read(languageProvider).language;

    ref.read(detectionProvider.notifier).analyze(
          type: widget.detectionType,
          filePath: path,
          language: language,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Once the real API call resolves (success or failure), move on to the
    // result screen — it reads the same detectionProvider state.
    ref.listen<DetectionState>(detectionProvider, (previous, next) {
      if (!mounted) return;
      if (next.status == DetectionStatus.success ||
          next.status == DetectionStatus.failure) {
        context.pushReplacement(
          '/detection/result',
          extra: {'detectionType': widget.detectionType},
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing green circle with leaf icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, _) => Transform.scale(
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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
