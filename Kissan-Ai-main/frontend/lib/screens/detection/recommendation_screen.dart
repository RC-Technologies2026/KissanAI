import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/weather_provider.dart';
import 'camera_picker_screen.dart';

/// Screen 5 — Pesticide / Insecticide Recommendation (shared).
///
/// Shows product details, safety precautions, and a weather-blocked banner.
/// Connected to backend /api/pesticides/recommend or /api/insecticides/recommend.
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({
    super.key,
    required this.detectionType,
    this.detectionId,
  });

  final DetectionType detectionType;
  final String? detectionId;

  @override
  ConsumerState<RecommendationScreen> createState() =>
      _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _recommendation;

  @override
  void initState() {
    super.initState();
    if (widget.detectionId != null) {
      _fetchRecommendation();
    } else {
      setState(() {
        _loading = false;
        _error = 'No detection ID available';
      });
    }
  }

  Future<void> _fetchRecommendation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiClient.instance;
      final isDisease = widget.detectionType == DetectionType.disease;

      final res = isDisease
          ? await api.getPesticides(diseaseDetectionId: widget.detectionId!)
          : await api.getInsecticides(pestDetectionId: widget.detectionId!);

      final data = res.data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _loading = false;
          _recommendation = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to get recommendation. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);
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
          widget.detectionType.recommendationTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.bodyText),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchRecommendation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _recommendation == null
                  ? const Center(child: Text('No recommendation available'))
                  : SingleChildScrollView(
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
                                border:
                                    Border.all(color: const Color(0xFFFF9800)),
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
                                  _recommendation!['product_name'] ??
                                      'Product',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.headingText,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _infoRow(
                                    Icons.medication,
                                    'Dosage',
                                    _recommendation!['dosage'] ?? 'N/A'),
                                const SizedBox(height: 12),
                                _infoRow(
                                    Icons.water_drop,
                                    'Application Method',
                                    _recommendation!['application_method'] ??
                                        'N/A'),
                                if (_recommendation!['application_guidance'] !=
                                    null) ...[
                                  const SizedBox(height: 12),
                                  _infoRow(
                                      Icons.check_circle_outline,
                                      'Guidance',
                                      _recommendation![
                                          'application_guidance']),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Safety card
                          if (_recommendation!['safety_precautions'] != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F1),
                                borderRadius: BorderRadius.circular(20),
                                border: const Border(
                                  left: BorderSide(
                                      color: AppColors.error, width: 3),
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
                                  Text(
                                    _recommendation!['safety_precautions'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.bodyText,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Back to Dashboard — outline green
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                context.go('/dashboard');
                              },
                              child: const Text('Back to Dashboard'),
                            ),
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
