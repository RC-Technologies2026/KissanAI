import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Result info card following the 4-question contract from the spec.
///
/// 1. What is the problem?
/// 2. Why did it happen?
/// 3. What should I do now?
/// 4. What should I avoid?
class ResultInfoCard extends StatelessWidget {
  const ResultInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final String body;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.bodyText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Low-confidence fallback card.
class LowConfidenceCard extends StatelessWidget {
  const LowConfidenceCard({
    super.key,
    required this.guesses,
  });

  final List<String> guesses;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'We could not confidently identify this. Please consult an agronomist.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.headingText,
              height: 1.5,
            ),
          ),
          if (guesses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Possible matches:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 8),
            ...guesses.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $g',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.bodyText)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Weather-blocked banner for chemical recommendations.
class WeatherBlockedBanner extends StatelessWidget {
  const WeatherBlockedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: AppColors.error, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chemical application not safe right now due to weather conditions.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
