import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/weather_provider.dart';
import 'camera_picker_screen.dart';

/// Screen 5 — Pesticide / Insecticide Recommendation (shared).
///
/// Shows product details, safety precautions, and a weather-blocked banner.
class RecommendationScreen extends ConsumerWidget {
  const RecommendationScreen({super.key, required this.detectionType});

  final DetectionType detectionType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisease = detectionType == DetectionType.disease;
    final weather = ref.watch(weatherProvider);

    // Mock data
    final productName = isDisease ? 'Mancozeb 80% WP' : 'Imidacloprid 200 SL';
    final dosage = isDisease
        ? '2.5g per liter of water'
        : '0.5ml per liter of water';
    final application = isDisease
        ? 'Spray every 7 days, repeat 2-3 times'
        : 'Apply insecticide in early morning or evening';
    final coverage = isDisease
        ? 'Spray on all affected leaves and stems'
        : 'Spray on all affected leaves and stems';
    final safetyPrecautions = [
      'Wear gloves and mask while spraying',
      'Keep children away from treated area for 24 hours',
      'Store chemicals in original container, away from food',
    ];
    final weatherBlocked = weather.isBlocked;

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
          detectionType.recommendationTitle,
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
            // Weather blocked banner
            if (weatherBlocked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF9800)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud,
                        color: Color(0xFFFF9800), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '⚠ ${weather.alertMessage}\n'
                        'Apply after weather clears for best results.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Product card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.medication, 'Dosage', dosage),
                  const SizedBox(height: 12),
                  _infoRow(Icons.schedule, 'Application', application),
                  const SizedBox(height: 12),
                  _infoRow(Icons.grass, 'Coverage', coverage),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Safety card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(20),
                border: const Border(
                  left: BorderSide(color: AppColors.error, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Safety Precautions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...safetyPrecautions.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.bodyText)),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.bodyText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Rule audit row
            const Text(
              'Rule ID: PEST-001 · Rules Engine v1.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 24),

            // Save to History — solid green
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to history')),
                );
              },
              child: Text(detectionType.saveHistoryButton),
            ),
            const SizedBox(height: 12),

            // Back to Dashboard — outline green
            OutlinedButton(
              onPressed: () {
                context.go('/dashboard');
              },
              child: const Text('Back to Dashboard'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
