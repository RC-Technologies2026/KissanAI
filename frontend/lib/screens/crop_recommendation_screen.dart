import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';

/// Screen 2 — Crop Recommendation.
class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  String _season = 'Rabi (Winter)';
  String _soilType = 'Loam';
  String _waterAvailability = 'Medium';
  bool _showResults = false;

  final _seasons = ['Rabi (Winter)', 'Kharif (Summer)'];
  final _soilTypes = ['Clay', 'Sandy', 'Loam', 'Silt', 'Mixed'];
  final _waterLevels = ['Low', 'Medium', 'High'];

  final _mockResults = [
    {
      'rank': '🥇',
      'crop': 'Wheat',
      'emoji': '🌾',
      'score': '95% match',
      'reason': 'Ideal for clay soil in Rabi season',
      'details': 'Water: 450mm | Yield: 40 maunds/acre | Plant: Nov-Dec',
    },
    {
      'rank': '🥈',
      'crop': 'Chickpea',
      'emoji': '',
      'score': '82% match',
      'reason': 'Low water requirement, good for rotation',
      'details': 'Water: 200mm | Yield: 15 maunds/acre | Plant: Oct-Nov',
    },
    {
      'rank': '🥉',
      'crop': 'Mustard',
      'emoji': '',
      'score': '74% match',
      'reason': 'Tolerates cool temperatures well',
      'details': 'Water: 300mm | Yield: 12 maunds/acre | Plant: Oct',
    },
  ];

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
                            onTap: () => setState(
                                () => _waterAvailability = level),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                  ElevatedButton(
                    onPressed: () => setState(() => _showResults = true),
                    child: const Text('Get Recommendations'),
                  ),
                ],
              ),
            ),

            if (_showResults) ...[
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
              ..._mockResults.map((r) => Padding(
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
                            child: Text(r['details']!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.headingText)),
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
