import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/error_handler.dart';
import '../providers/language_provider.dart';
import '../providers/plot_provider.dart';
import '../router/app_router.dart';

/// Crop Recommendation screen — connected to backend /api/irrigation/recommend.
///
/// Farmers pick one of their saved plots and adjust season/soil/water. The
/// backend returns ranked crops plus fertilizer, pest alerts and irrigation
/// guidance for the top pick.
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
  Map<String, dynamic>? _topCropMeta;
  Map<String, dynamic>? _irrigation;
  String? _selectedPlotId;

  final _seasons = ['Rabi (Winter)', 'Kharif (Summer)'];
  final _soilTypes = ['Alluvial', 'Clay', 'Sandy', 'Loamy', 'Black', 'Red'];
  final _waterLevels = ['Low', 'Medium', 'High'];

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

    // Auto-select first plot + sync its soil type whenever plots load.
    ref.listenManual(plotProvider, (prev, next) {
      if (prev?.plots.isEmpty == true && next.plots.isNotEmpty) {
        _autoSelectFromState(next.plots);
      }
    });
  }

  /// Pick the first plot by default and copy its saved soil type.
  void _autoSelectFromState(List<Map<String, dynamic>> plots) {
    if (_selectedPlotId != null || plots.isEmpty) return;
    final first = plots.first;
    final savedSoil = first['soil_type']?.toString();
    setState(() {
      _selectedPlotId = first['id']?.toString();
      if (savedSoil != null && savedSoil.isNotEmpty) {
        final normalized = _normalizeSoil(savedSoil);
        if (_soilTypes.contains(normalized)) {
          _soilType = normalized;
        }
      }
    });
  }

  String _normalizeSoil(String? s) {
    if (s == null) return 'Loamy';
    final lower = s.trim().toLowerCase();
    if (lower.contains('alluvial')) return 'Alluvial';
    if (lower.contains('clay')) return 'Clay';
    if (lower.contains('sand')) return 'Sandy';
    if (lower.contains('loam')) return 'Loamy';
    if (lower.contains('black')) return 'Black';
    if (lower.contains('red')) return 'Red';
    return 'Loamy';
  }

  Future<void> _getRecommendations() async {
    if (_selectedPlotId == null) {
      setState(() => _error = 'Please select a plot first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _topCropMeta = null;
      _irrigation = null;
    });

    try {
      final api = ApiClient.instance;
      final plotId = _selectedPlotId!;

      final recRes = await api.getCropRecommendation(
        plotId: plotId,
        season: _season,
        soilType: _soilType,
        waterAvailability: _waterAvailability,
      );
      final recData = recRes.data as Map<String, dynamic>;

      final recommendedCrops =
          (recData['recommended_crops'] as String? ?? '').split(',');
      final reasoning = recData['reasoning'] as String? ?? '';

      // Pull rich metadata stored in analysis_history snapshot
      final snapshot = recData['result_snapshot'] as Map<String, dynamic>?;
      final fertilizer = snapshot?['fertilizer'] as String?;
      final pestAlerts = snapshot?['pest_alerts'] as String?;
      final cropMeta = snapshot?['crop_metadata'] as Map<String, dynamic>?;

      // Get irrigation guide for top crop
      final recId = recData['id'].toString();
      Map<String, dynamic>? irrigData;
      try {
        final irrigRes = await api.getIrrigationGuide(recId);
        irrigData = irrigRes.data as Map<String, dynamic>?;
      } catch (_) {
        // Irrigation guide is optional
      }

      final cropEmojis = {
        'wheat': '🌾',
        'barley': '🌾',
        'rice': '🍚',
        'sugarcane': '🎋',
        'cotton': '🌿',
        'maize': '🌽',
        'groundnut': '🥜',
        'potato': '🥔',
        'vegetables': '🥬',
        'fruits': '🍎',
        'mango': '🥭',
        'citrus': '🍊',
        'banana': '🍌',
        'chickpea': '🫘',
        'soybean': '🫘',
        'millet': '🌾',
        'sesame': '🌱',
        'mustard': '🌼',
        'canola': '🌼',
        'sunflower': '🌻',
        'lentil': '🫘',
        'garlic': '🧄',
        'onion': '🧅',
        'tomato': '🍅',
        'pea': '🟢',
        'okra': '🥒',
        'chili': '🌶️',
        'brinjal': '🍆',
        'cucumber': '🥒',
        'date palm': '🌴',
        'fodder': '🌱',
        'watermelon': '🍉',
        'jowar': '🌾',
        'ragi': '🌾',
        'tobacco': '🍃',
      };

      final ranks = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
      final scores = ['95%', '87%', '80%', '72%', '65%'];

      final newResults = <Map<String, dynamic>>[];
      for (int i = 0; i < recommendedCrops.length && i < 5; i++) {
        final crop = recommendedCrops[i].trim();
        newResults.add({
          'rank': ranks[i],
          'crop': crop[0].toUpperCase() + crop.substring(1),
          'emoji': cropEmojis[crop.toLowerCase()] ?? '🌱',
          'score': '${scores[i]} match',
          'reason': i == 0
              ? reasoning
              : 'Suitable for $_soilType soil in $_season with $_waterAvailability water.',
        });
      }

      if (mounted) {
        setState(() {
          _results = newResults;
          _topCropMeta = {
            'fertilizer': fertilizer,
            'pest_alerts': pestAlerts,
            'duration_days': cropMeta?['duration_days'],
            'water_need': cropMeta?['water_need'],
          };
          _irrigation = irrigData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppError.fromException(e);
        });
      }
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
            _buildInputCard(plots),
            if (_error != null) ...[
              const SizedBox(height: 20),
              _buildErrorCard(_error!),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildResultsSection(),
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
          _buildPlotSummary(plots),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
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
              value: _selectedPlotId,
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
              onChanged: (v) {
                final selected = plots.firstWhere(
                  (p) => p['id'].toString() == v,
                  orElse: () => {},
                );
                setState(() {
                  _selectedPlotId = v;
                  final savedSoil = selected['soil_type']?.toString();
                  if (savedSoil != null && savedSoil.isNotEmpty) {
                    final normalized = _normalizeSoil(savedSoil);
                    if (_soilTypes.contains(normalized)) {
                      _soilType = normalized;
                    }
                  }
                });
              },
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.bodyText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlotSummary(List<Map<String, dynamic>> plots) {
    if (_selectedPlotId == null) return const SizedBox.shrink();
    final plot = plots.firstWhere(
      (p) => p['id'].toString() == _selectedPlotId,
      orElse: () => {},
    );
    if (plot.isEmpty) return const SizedBox.shrink();

    final area = plot['area_hectares'];
    final soil = plot['soil_type']?.toString();
    final location = plot['location']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using plot data: ${[
                if (soil != null && soil.isNotEmpty) 'soil $soil',
                if (area != null) '$area ha',
                if (location != null && location.isNotEmpty) location,
              ].join(' · ')}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Best Crops for Your Farm',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        const SizedBox(height: 16),
        ..._results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CropCard(
              rank: r['rank']!,
              crop: r['crop']!,
              emoji: r['emoji']!,
              score: r['score']!,
              reason: r['reason']!,
              isTop: i == 0,
            ),
          );
        }),
        if (_topCropMeta != null) _buildTopCropGuide(),
      ],
    );
  }

  Widget _buildTopCropGuide() {
    final fertilizer = _topCropMeta?['fertilizer'] as String?;
    final pestAlerts = _topCropMeta?['pest_alerts'] as String?;
    final duration = _topCropMeta?['duration_days'] as int?;

    return Column(
      children: [
        if (duration != null)
          _infoCard(
            icon: Icons.calendar_today_outlined,
            title: 'Crop Calendar',
            body: 'Approximately $duration days from sowing to harvest. Plan sowing according to the selected season.',
            accent: const Color(0xFFE8F5E9),
            accentIcon: const Color(0xFF2E7D32),
          ),
        if (fertilizer != null && fertilizer.isNotEmpty)
          _infoCard(
            icon: Icons.local_florist,
            title: 'Fertilizer Guide',
            body: fertilizer,
            accent: const Color(0xFFFFF3E0),
            accentIcon: const Color(0xFFE65100),
          ),
        if (_irrigation != null)
          _infoCard(
            icon: Icons.water_drop,
            title: 'Irrigation Plan',
            body: _irrigationBody(),
            accent: const Color(0xFFE0F7FA),
            accentIcon: const Color(0xFF00838F),
          ),
        if (pestAlerts != null && pestAlerts.isNotEmpty)
          _infoCard(
            icon: Icons.warning_amber_rounded,
            title: 'Watch Out For',
            body: pestAlerts,
            accent: const Color(0xFFFFF1F1),
            accentIcon: AppColors.error,
          ),
      ],
    );
  }

  String _irrigationBody() {
    if (_irrigation == null) return '';
    final schedule = _irrigation!['schedule'] ?? 'N/A';
    final method = _irrigation!['method'] ?? 'N/A';
    final amount = _irrigation!['water_amount_liters'];
    final note = _irrigation!['note'] as String?;
    final buffer = StringBuffer()
      ..writeln('Schedule: $schedule')
      ..writeln('Method: $method');
    if (amount != null) {
      buffer.writeln('Amount: ~$amount litres/hectare');
    }
    if (note != null && note.isNotEmpty) {
      buffer.writeln('\n⚠ $note');
    }
    return buffer.toString().trim();
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accent,
    required Color accentIcon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentIcon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.bodyText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
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
              message,
              style: TextStyle(fontSize: 14, color: Colors.red.shade700),
            ),
          ),
        ],
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
            color: AppColors.background,
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

/// Result crop card with rank, emoji and match score.
class _CropCard extends StatelessWidget {
  const _CropCard({
    required this.rank,
    required this.crop,
    required this.emoji,
    required this.score,
    required this.reason,
    required this.isTop,
  });

  final String rank;
  final String crop;
  final String emoji;
  final String score;
  final String reason;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isTop
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
            : null,
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
              Text(rank, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                '$emoji $crop',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  score,
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
          Text(
            reason,
            style: const TextStyle(fontSize: 14, color: AppColors.bodyText, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Shown when the farmer has no plots.
class _NoPlotsCard extends StatelessWidget {
  const _NoPlotsCard({required this.lang});
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.landscape_rounded,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            lang.t('plots.no_plots'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.headingText,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.push(Routes.plots),
            icon: const Icon(Icons.add, size: 18),
            label: Text(lang.t('plots.add_first')),
          ),
        ],
      ),
    );
  }
}
