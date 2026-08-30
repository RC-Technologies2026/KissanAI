import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';

/// Screen 3 — Irrigation Guide.
class IrrigationGuideScreen extends StatefulWidget {
  const IrrigationGuideScreen({super.key});

  @override
  State<IrrigationGuideScreen> createState() => _IrrigationGuideScreenState();
}

class _IrrigationGuideScreenState extends State<IrrigationGuideScreen> {
  String _selectedCrop = 'Wheat';
  final _crops = ['Wheat', 'Rice', 'Cotton', 'Maize'];

  final Map<String, Map<String, String>> _mockData = {
    'Wheat': {
      'stage': 'Tillering',
      'water': '35mm per week',
      'next': 'In 2 days',
      'method': 'Furrow irrigation recommended',
      'note': 'Reduce if rain expected in 48h',
    },
    'Rice': {
      'stage': 'Vegetative',
      'water': '50mm per week',
      'next': 'Today',
      'method': 'Flood irrigation recommended',
      'note': 'Maintain 5cm water level',
    },
    'Cotton': {
      'stage': 'Flowering',
      'water': '40mm per week',
      'next': 'In 3 days',
      'method': 'Drip irrigation recommended',
      'note': 'Avoid waterlogging during flowering',
    },
    'Maize': {
      'stage': 'Tasseling',
      'water': '45mm per week',
      'next': 'In 1 day',
      'method': 'Furrow irrigation recommended',
      'note': 'Critical stage — do not skip irrigation',
    },
  };

  @override
  Widget build(BuildContext context) {
    final data = _mockData[_selectedCrop]!;

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
          'Irrigation Guide',
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
            const Text(
              'Select a crop',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 12),

            // Crop selector chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _crops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final crop = _crops[i];
                  final isSelected = _selectedCrop == crop;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCrop = crop),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        crop,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.headingText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Result card
            Container(
              width: double.infinity,
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
                  Row(
                    children: [
                      const Icon(Icons.grass,
                          color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _selectedCrop,
                        style: const TextStyle(
                          fontSize: 20,
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
                          data['stage']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _irrigationRow(Icons.water_drop, 'Water needed', data['water']!),
                  const SizedBox(height: 12),
                  _irrigationRow(Icons.schedule, 'Next irrigation', data['next']!),
                  const SizedBox(height: 12),
                  _irrigationRow(Icons.list_alt, 'Method', data['method']!),
                  const SizedBox(height: 12),
                  _irrigationRow(Icons.warning_amber_rounded, 'Note', data['note']!,
                      warning: true),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _irrigationRow(
      IconData icon, String label, String value,
      {bool warning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 20,
            color: warning ? AppColors.warning : AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bodyText)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: warning
                          ? AppColors.warning
                          : AppColors.headingText)),
            ],
          ),
        ),
      ],
    );
  }
}
