import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_colors.dart';

/// Crop Recommendation screen — connected to backend /api/irrigation/recommend.
class CropRecommendationScreen extends ConsumerStatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  ConsumerState<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState
    extends ConsumerState<CropRecommendationScreen> {
  String _season = 'Rabi (Winter)';
  String _soilType = 'Loamy';
  String _waterAvailability = 'Medium';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  final _seasons = ['Rabi (Winter)', 'Kharif (Summer)'];
  final _soilTypes = ['Alluvial', 'Clay', 'Sandy', 'Loamy', 'Black', 'Red'];
  final _waterLevels = ['Low', 'Medium', 'High'];

  Future<void> _getRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final api = ApiClient.instance;

      // 1. Fetch user's plots
      final plotsRes = await api.getPlots();
      final plots = plotsRes.data as List;

      String? plotId;
      for (final p in plots) {
        final plot = p as Map<String, dynamic>;
        if ((plot['soil_type'] ?? '').toString().toLowerCase() ==
            _soilType.toLowerCase()) {
          plotId = plot['id'].toString();
          break;
        }
      }

      // 3. If no matching plot, create one
      if (plotId == null) {
        final createRes = await api.createPlot(
          name: 'My Farm - $_soilType',
          soilType: _soilType,
        );
        plotId = (createRes.data as Map<String, dynamic>)['id'].toString();
      }

      // 4. Get crop recommendation
      final recRes = await api.getCropRecommendation(plotId: plotId);
      final recData = recRes.data as Map<String, dynamic>;

      final recommendedCrops =
          (recData['recommended_crops'] as String? ?? '').split(',');
      final reasoning = recData['reasoning'] as String? ?? '';

      // 5. Get irrigation guide for top crop
      final recId = recData['id'].toString();
      String? irrigationInfo;
      try {
        final irrigRes = await api.getIrrigationGuide(recId);
        final irrigData = irrigRes.data as Map<String, dynamic>;
        irrigationInfo =
            'Schedule: ${irrigData['schedule']}\nMethod: ${irrigData['method'] ?? 'N/A'}';
      } catch (_) {
        // Irrigation guide is optional
      }

      // 6. Build results list
      final cropEmojis = {
        'wheat': '',
        'rice': '🌾',
        'sugarcane': '',
        'cotton': '🌿',
        'maize': '🌽',
        'groundnut': '🥜',
        'potato': '🥔',
        'vegetables': '🥬',
        'fruits': '🍎',
        'chickpea': '🫘',
        'soybean': '🫘',
        'millet': '🌾',
        'sesame': '🌱',
      };

      final ranks = ['', '🥈', '🥉', '4️⃣', '5️'];
      final scores = ['95%', '85%', '75%', '65%', '55%'];

      for (int i = 0; i < recommendedCrops.length && i < 5; i++) {
        final crop = recommendedCrops[i].trim();
        _results.add({
          'rank': ranks[i],
          'crop': crop[0].toUpperCase() + crop.substring(1),
          'emoji': cropEmojis[crop.toLowerCase()] ?? '🌱',
          'score': '${scores[i]} match',
          'reason': i == 0 ? reasoning : 'Suitable for $_soilType soil',
          'irrigation': irrigationInfo ?? 'See irrigation guide for details',
        });
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to get recommendations. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Crop Recommendation',
          style: TextStyle(
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
            // Input form card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownField('Season', _season, _seasons, (v) {
                    if (v != null) setState(() => _season = v);
                  }),
                  const SizedBox(height: 16),
                  _dropdownField('Soil Type', _soilType, _soilTypes, (v) {
                    if (v != null) setState(() => _soilType = v);
                  }),
                  const SizedBox(height: 16),
                  const Text('Water Availability',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.headingText)),
                  const SizedBox(height: 8),
                  Row(
                    children: _waterLevels.map((level) {
                      final isSelected = _waterAvailability == level;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _waterAvailability = level),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.headingText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _getRecommendations,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Get Recommendations'),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            fontSize: 14, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_results.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Best Crops for Your Farm',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 16),
              ..._results.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(r['rank']!,
                                  style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Text(
                                '${r['emoji']} ${r['crop']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.headingText,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  r['score']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r['reason']!,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.bodyText)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F0E4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r['irrigation']!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.headingText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.bodyText),
            ),
          ),
        ),
      ],
    );
  }
}
