import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import 'camera_picker_screen.dart';
import '../../widgets/answer_card.dart';

/// Mock detection result data.
class _MockResult {
  final String name;
  final String crop;
  final double confidence;
  final String whatIsProblem;
  final String whyDidItHappen;
  final String whatToDo;
  final String whatToAvoid;

  const _MockResult({
    required this.name,
    required this.crop,
    required this.confidence,
    required this.whatIsProblem,
    required this.whyDidItHappen,
    required this.whatToDo,
    required this.whatToAvoid,
  });
}

const _diseaseMock = _MockResult(
  name: 'Leaf Blight',
  crop: 'Wheat',
  confidence: 0.87,
  whatIsProblem:
      'Leaf Blight caused by Alternaria fungus affecting wheat leaves',
  whyDidItHappen:
      'High humidity (>80%) combined with warm temperatures in recent days',
  whatToDo:
      'Apply fungicide within 48 hours. Remove heavily infected leaves.',
  whatToAvoid:
      'Do not apply chemicals before rain or when wind speed is above 20 km/h',
);

const _pestMock = _MockResult(
  name: 'Whitefly',
  crop: 'Cotton',
  confidence: 0.91,
  whatIsProblem:
      'Whitefly infestation on cotton plants causing yellowing and stunted growth',
  whyDidItHappen:
      'Hot dry weather and dense crop canopy trap whiteflies',
  whatToDo:
      'Apply insecticide in early morning or evening for best results',
  whatToAvoid:
      'Do not spray in direct sunlight or before rain',
);

/// Screen 4 — Detection Result (shared for Disease + Pest).
class DetectionResultScreen extends StatelessWidget {
  const DetectionResultScreen({super.key, required this.detectionType});

  final DetectionType detectionType;

  @override
  Widget build(BuildContext context) {
    final mock = detectionType == DetectionType.disease
        ? _diseaseMock
        : _pestMock;
    final isHighConfidence = mock.confidence >= 0.70;
    final confPercent = (mock.confidence * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.headingText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          detectionType.resultTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Confidence banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isHighConfidence
                    ? AppColors.primary
                    : AppColors.warning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isHighConfidence
                      ? '$confPercent% Confident'
                      : 'Low Confidence — Consult an agronomist',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (isHighConfidence) ...[
              // Disease/Pest info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: const Border(
                    left: BorderSide(
                        color: AppColors.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mock.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Affected crop: ${mock.crop}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.bodyText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detected: Aug 24, 2025',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4 answer cards
              AnswerCard(
                icon: Icons.help_outline,
                iconColor: AppColors.primary,
                borderColor: AppColors.primary,
                title: 'What is the problem?',
                body: mock.whatIsProblem,
              ),
              AnswerCard(
                icon: Icons.search,
                iconColor: Colors.blue,
                borderColor: Colors.blue,
                title: 'Why did it happen?',
                body: mock.whyDidItHappen,
              ),
              AnswerCard(
                icon: Icons.check_circle_outline,
                iconColor: AppColors.primary,
                borderColor: AppColors.primary,
                title: 'What should I do now?',
                body: mock.whatToDo,
              ),
              AnswerCard(
                icon: Icons.block,
                iconColor: AppColors.error,
                borderColor: AppColors.error,
                title: 'What should I avoid?',
                body: mock.whatToAvoid,
              ),
              const SizedBox(height: 20),

              // View Recommendation button
              ElevatedButton(
                onPressed: () => context.push(
                  '/detection/recommendation',
                  extra: {'detectionType': detectionType},
                ),
                child: Text(detectionType.recommendationButton),
              ),
            ] else ...[
              // Low confidence fallback
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Low Confidence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headingText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We couldn\'t identify this with enough confidence.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.headingText,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please consult a local agronomist for accurate diagnosis.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.bodyText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Try Again with a Clearer Photo'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
