import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/detection_provider.dart';
import 'camera_picker_screen.dart';
import '../../widgets/answer_card.dart';

/// Screen 4 — Detection Result (shared for Disease + Pest).
///
/// Renders the live API response from /api/disease/detect or
/// /api/pests/detect: disease/pest name, crop, confidence score and the
/// localized diagnosis sections (symptoms, treatment, …).
class DetectionResultScreen extends ConsumerWidget {
  const DetectionResultScreen({super.key, required this.detectionType});

  final DetectionType detectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detection = ref.watch(detectionProvider);

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
      body: switch (detection.status) {
        DetectionStatus.failure => _ErrorBody(message: detection.errorMessage),
        DetectionStatus.idle || DetectionStatus.loading => _LoadingBody(),
        DetectionStatus.success =>
          _ResultBody(result: detection.result!),
      },
    );
  }
}

// ─── Success (real API data) ───────────────────────────────────────────────

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result});

  final DetectionResultData result;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool get _isHighConfidence =>
      result.confidence != null && result.confidence! >= 0.70;

  String? get _confPercent =>
      result.confidence != null ? (result.confidence! * 100).round().toString() : null;

  String get _detectedOn {
    final dt = result.detectedAt;
    if (dt == null) return 'Detected: just now';
    return 'Detected: ${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Drop the "Crop" section — it already renders in the info card.
    final cards = result.sections
        .where((s) => s.title.toLowerCase() != 'crop')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence banner — real confidence_score from the API
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: result.confidence == null
                  ? AppColors.bodyText
                  : _isHighConfidence
                      ? AppColors.primary
                      : AppColors.warning,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                result.confidence == null
                    ? 'Confidence unavailable'
                    : _isHighConfidence
                        ? '$_confPercent% Confident'
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

          if (_isHighConfidence) ...[
            // Disease/Pest info card — name, crop and date from the API
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Affected crop: ${result.cropName ?? 'Not identified'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.bodyText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detectedOn,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.bodyText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Diagnosis sections (symptoms, treatment, …) from the API
            if (cards.isEmpty)
              AnswerCard(
                icon: Icons.description_outlined,
                iconColor: AppColors.primary,
                borderColor: AppColors.primary,
                title: 'Diagnosis',
                body: result.name,
              )
            else
              ...cards.map(_cardForSection),
            const SizedBox(height: 20),

            // View Recommendation button — carries the detection id
            ElevatedButton(
              onPressed: () => context.push(
                '/detection/recommendation',
                extra: {
                  'detectionType': result.type,
                  'detectionId': result.detectionId,
                },
              ),
              child: Text(result.type.recommendationButton),
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
                  Text(
                    result.cropName != null
                        ? 'Closest match on ${result.cropName}: ${result.name}${_confPercent != null ? ' ($_confPercent% confident)' : ''}.'
                        : 'Closest match: ${result.name}${_confPercent != null ? ' ($_confPercent% confident)' : ''}.',
                    style: const TextStyle(
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
    );
  }

  /// Maps a parsed diagnosis section to a styled answer card.
  Widget _cardForSection(DetectionSection section) {
    final t = section.title.toLowerCase();
    if (t.contains('symptom') || t.contains('damage')) {
      return AnswerCard(
        icon: Icons.search,
        iconColor: Colors.blue,
        borderColor: Colors.blue,
        title: section.title,
        body: section.body,
      );
    }
    if (t.contains('avoid') ||
        t.contains('caution') ||
        t.contains('warning') ||
        t.contains('prevent')) {
      return AnswerCard(
        icon: Icons.block,
        iconColor: AppColors.error,
        borderColor: AppColors.error,
        title: section.title,
        body: section.body,
      );
    }
    if (t.contains('treatment') ||
        t.contains('pesticide') ||
        t.contains('insecticide') ||
        t.contains('management')) {
      return AnswerCard(
        icon: Icons.check_circle_outline,
        iconColor: AppColors.primary,
        borderColor: AppColors.primary,
        title: section.title,
        body: section.body,
      );
    }
    return AnswerCard(
      icon: Icons.help_outline,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary,
      title: section.title,
      body: section.body,
    );
  }
}

// ─── Failure (friendly error, no raw Dio traces) ──────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_off, color: AppColors.error, size: 28),
                SizedBox(width: 10),
                Text(
                  'Analysis Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Something went wrong. Please try again.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.bodyText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No result available (deep-link / app restart) ────────────────────────

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Waiting for analysis results…',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
        ],
      ),
    );
  }
}
