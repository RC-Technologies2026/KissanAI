import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_colors.dart';

/// History item model.
class _HistoryItem {
  const _HistoryItem({
    required this.type,
    required this.title,
    required this.crop,
    required this.date,
    required this.status,
  });

  final HistoryType type;
  final String title;
  final String crop;
  final String date;
  final String status;
}

enum HistoryType { disease, pest, crop, irrigation }

/// Filter chip labels.
const _filters = <String, HistoryType?>{
  'All': null,
  'Disease': HistoryType.disease,
  'Pest': HistoryType.pest,
  'Crop': HistoryType.crop,
  'Irrigation': HistoryType.irrigation,
};

/// History screen — connected to backend /api/history.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _activeFilter = 'All';
  List<_HistoryItem> _allItems = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.instance.getHistoryList(limit: 100);
      final items = res.data as List;

      final parsed = items.map<_HistoryItem>((item) {
        final map = item as Map<String, dynamic>;
        final analysisType = (map['analysis_type'] as String? ?? '').toLowerCase();
        final snapshot = map['result_snapshot'] as Map<String, dynamic>? ?? {};
        final createdAt = map['created_at'] as String? ?? '';

        HistoryType type;
        String title;
        String crop;

        if (analysisType.contains('disease')) {
          type = HistoryType.disease;
          title = snapshot['disease_name'] as String? ?? 'Disease Detection';
          crop = snapshot['crop_name'] as String? ?? '';
        } else if (analysisType.contains('pest')) {
          type = HistoryType.pest;
          title = snapshot['pest_name'] as String? ?? 'Pest Detection';
          crop = snapshot['crop_name'] as String? ?? '';
        } else if (analysisType.contains('crop') || analysisType.contains('irrigation')) {
          type = analysisType.contains('irrigation')
              ? HistoryType.irrigation
              : HistoryType.crop;
          final recommendedCrops = snapshot['recommended_crops'] as String? ?? '';
          title = recommendedCrops.isNotEmpty ? recommendedCrops : 'Crop Recommendation';
          crop = snapshot['soil_type'] as String? ?? '';
        } else {
          type = HistoryType.crop;
          title = 'Analysis';
          crop = '';
        }

        return _HistoryItem(
          type: type,
          title: title,
          crop: crop,
          date: _formatDate(createdAt),
          status: 'Completed',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allItems = parsed;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load history. Pull to refresh.';
        });
      }
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  List<_HistoryItem> get _filteredItems {
    if (_activeFilter == 'All') return _allItems;
    final type = _filters[_activeFilter];
    return _allItems.where((item) => item.type == type).toList();
  }

  /// Returns icon, bg colour, and icon colour for each history type.
  _TypeStyle _styleFor(HistoryType type) {
    switch (type) {
      case HistoryType.disease:
        return const _TypeStyle(
          icon: Icons.bug_report,
          bg: Color(0xFFE8F5E9),
          iconColor: Color(0xFF2E7D32),
        );
      case HistoryType.pest:
        return const _TypeStyle(
          icon: Icons.bubble_chart,
          bg: Color(0xFFFFF8E1),
          iconColor: Color(0xFFF9A825),
        );
      case HistoryType.crop:
        return const _TypeStyle(
          icon: Icons.eco_outlined,
          bg: Color(0xFFE3F2FD),
          iconColor: Color(0xFF1565C0),
        );
      case HistoryType.irrigation:
        return const _TypeStyle(
          icon: Icons.water_drop,
          bg: Color(0xFFE0F7FA),
          iconColor: Color(0xFF00838F),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

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
          'My History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loading ? null : _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final label = _filters.keys.elementAt(i);
                final isActive = _activeFilter == label;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isActive ? AppColors.primary : AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : AppColors.headingText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off,
                                size: 48, color: AppColors.bodyText),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.bodyText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchHistory,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : items.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _buildHistoryCard(items[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(_HistoryItem item) {
    final style = _styleFor(item.type);

    return GestureDetector(
      onTap: () {
        // TODO: navigate to read-only result screen
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            // Colour-coded icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Title + crop · date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.crop.isNotEmpty)
                    Text(
                      '${item.crop} \u00B7 ${item.date}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.bodyText,
                      ),
                    )
                  else
                    Text(
                      item.date,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.bodyText,
                      ),
                    ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F33E}', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'No analysis yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.headingText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your crop to get started!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.bodyText,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/detection/camera/disease'),
            child: const Text('Scan Now'),
          ),
        ],
      ),
    );
  }
}

/// Internal helper to hold type-specific style.
class _TypeStyle {
  const _TypeStyle({
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  final IconData icon;
  final Color bg;
  final Color iconColor;
}
