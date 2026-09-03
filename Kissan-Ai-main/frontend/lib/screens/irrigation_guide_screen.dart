import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/error_handler.dart';
import '../providers/language_provider.dart';
import '../providers/plot_provider.dart';

/// Irrigation Guide screen — connected to backend /api/irrigation/direct-guide.
///
/// Farmers pick one of their saved plots, choose a crop and water availability,
/// then get a real irrigation schedule, method, next irrigation timing,
/// fertilizer advice and pest alerts for that crop on that plot.
class IrrigationGuideScreen extends ConsumerStatefulWidget {
  const IrrigationGuideScreen({super.key});

  @override
  ConsumerState<IrrigationGuideScreen> createState() =>
      _IrrigationGuideScreenState();
}

class _IrrigationGuideScreenState
    extends ConsumerState<IrrigationGuideScreen> {
  String _selectedPlotId = '';
  String _selectedCrop = 'Wheat';
  String _waterAvailability = 'Medium';
  DateTime? _plantingDate;
  DateTime? _lastWatered;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  final _waterLevels = ['Low', 'Medium', 'High'];

  // Crops supported by the backend rules engine (matches CROPS dict).
  final _crops = [
    'Wheat', 'Rice', 'Cotton', 'Maize', 'Sugarcane', 'Groundnut', 'Potato',
    'Tomato', 'Onion', 'Chili', 'Brinjal', 'Cucumber', 'Okra', 'Garlic',
    'Pea', 'Lentil', 'Chickpea', 'Barley', 'Mustard', 'Canola', 'Sunflower',
    'Soybean', 'Millet', 'Sesame', 'Jowar', 'Ragi', 'Watermelon', 'Tobacco',
    'Mango', 'Citrus', 'Banana', 'Date Palm', 'Fruits', 'Vegetables', 'Fodder',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final plotState = ref.read(plotProvider);
      if (plotState.plots.isEmpty) {
        ref.read(plotProvider.notifier).fetchPlots();
      } else {
        _autoSelectFromState(plotState.plots);
      }
    });

    ref.listenManual(plotProvider, (prev, next) {
      if (prev?.plots.isEmpty == true && next.plots.isNotEmpty) {
        _autoSelectFromState(next.plots);
      }
    });
  }

  void _autoSelectFromState(List<Map<String, dynamic>> plots) {
    if (_selectedPlotId.isNotEmpty || plots.isEmpty) return;
    setState(() => _selectedPlotId = plots.first['id']?.toString() ?? '');
  }

  Future<void> _getGuide() async {
    if (_selectedPlotId.isEmpty) {
      setState(() => _error = 'Please select a plot first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final res = await ApiClient.instance.getDirectIrrigationGuide(
        plotId: _selectedPlotId,
        cropName: _selectedCrop,
        waterAvailability: _waterAvailability,
        plantingDate: _plantingDate?.toIso8601String().split('T').first,
        lastWatered: _lastWatered?.toIso8601String().split('T').first,
      );

      if (mounted) {
        setState(() {
          _result = res.data as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final msg = AppError.fromException(e);
      if (mounted) setState(() => _error = msg);
    } catch (e) {
      if (mounted) setState(() => _error = AppError.fromException(e));
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plotState = ref.watch(plotProvider);
    final plots = plotState.plots;

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
            _buildInputCard(plots),
            if (_error != null) ...[
              const SizedBox(height: 20),
              _buildErrorCard(_error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildResultCard(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Map<String, dynamic>> plots) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          _buildPlotDropdown(plots),
          const SizedBox(height: 16),
          _buildCropDropdown(),
          const SizedBox(height: 16),
          _buildDatePicker(
            label: 'Planting Date (optional)',
            icon: Icons.calendar_month,
            selectedDate: _plantingDate,
            onPicked: (date) => setState(() => _plantingDate = date),
          ),
          const SizedBox(height: 16),
          _buildDatePicker(
            label: 'Last Watered (optional)',
            icon: Icons.water_drop_outlined,
            selectedDate: _lastWatered,
            onPicked: (date) => setState(() => _lastWatered = date),
          ),
          const SizedBox(height: 16),
          const Text('Water Availability',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText)),
          const SizedBox(height: 10),
          Row(
            children: _waterLevels.map((level) {
              final isSelected = _waterAvailability == level;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _waterAvailability = level),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _getGuide,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Get Irrigation Guide'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlotDropdown(List<Map<String, dynamic>> plots) {
    final lang = ref.watch(languageProvider);

    if (plots.isEmpty) {
      return _NoPlotsCard(lang: lang);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.t('plots.select_plot'),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedPlotId.isNotEmpty ? _selectedPlotId : null,
              hint: Text(lang.t('plots.select_plot'),
                  style: const TextStyle(color: AppColors.bodyText)),
              items: plots.map((p) {
                final id = p['id'].toString();
                final name = p['name'] ?? 'Plot';
                final area = p['area_hectares'];
                final subtitle = area != null ? ' ($area ha)' : '';
                return DropdownMenuItem(
                  value: id,
                  child: Text('$name$subtitle'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedPlotId = v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crop',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCrop,
              items: _crops.map((crop) {
                return DropdownMenuItem(
                  value: crop,
                  child: Text(crop),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCrop = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                        : 'Tap to select date',
                    style: TextStyle(
                      fontSize: 15,
                      color: selectedDate != null
                          ? AppColors.headingText
                          : AppColors.bodyText,
                    ),
                  ),
                ),
                if (selectedDate != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (label.contains('Planting')) {
                        _plantingDate = null;
                      } else {
                        _lastWatered = null;
                      }
                    }),
                    child: const Icon(Icons.close, size: 18, color: AppColors.bodyText),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final data = _result!;
    final crop = data['crop_name']?.toString() ?? _selectedCrop;
    final stage = data['growth_stage']?.toString() ?? 'Active growth';
    final schedule = data['schedule']?.toString() ?? '';
    final water = data['water_amount_liters']?.toString() ?? '';
    final method = data['method']?.toString() ?? '';
    final next = data['next_irrigation']?.toString() ?? '';
    final note = data['note']?.toString();
    final fertilizer = data['fertilizer']?.toString();
    final pests = data['pest_alerts']?.toString();
    final cropAgeDays = data['crop_age_days'];
    final daysSinceWatered = data['days_since_watered'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
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
                    crop,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      stage,
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
              if (schedule.isNotEmpty)
                _infoRow(Icons.calendar_today, 'Schedule', schedule),
              if (water.isNotEmpty)
                _infoRow(Icons.water_drop, 'Water needed', '$water L/acre'),
              if (method.isNotEmpty)
                _infoRow(Icons.settings, 'Method', method),
              if (next.isNotEmpty)
                _infoRow(Icons.schedule, 'Next irrigation', next),
              if (cropAgeDays != null)
                _infoRow(Icons.timer_outlined, 'Crop age', '$cropAgeDays days'),
              if (daysSinceWatered != null)
                _infoRow(Icons.water_drop, 'Days since watered', '$daysSinceWatered days'),
              if (note != null && note.isNotEmpty)
                _infoRow(Icons.warning_amber_rounded, 'Note', note,
                    warning: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (fertilizer != null && fertilizer.isNotEmpty)
          _extraCard(
            icon: Icons.local_florist,
            title: 'Fertilizer Guide',
            body: fertilizer,
            accent: AppColors.primary,
          ),
        if (pests != null && pests.isNotEmpty) ...[
          const SizedBox(height: 16),
          _extraCard(
            icon: Icons.bug_report,
            title: 'Watch Out For',
            body: pests,
            accent: AppColors.warning,
          ),
        ],
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool warning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
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
      ),
    );
  }

  Widget _extraCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.headingText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reused no-plots card from crop recommendation.
class _NoPlotsCard extends StatelessWidget {
  const _NoPlotsCard({required this.lang});
  final LanguageState lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.bodyText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add a plot first to get a field-specific irrigation guide.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
