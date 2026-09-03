import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../providers/plot_provider.dart';

/// "My Plots" screen — lists, creates, edits and deletes farm plots.
class PlotsScreen extends ConsumerStatefulWidget {
  const PlotsScreen({super.key});

  @override
  ConsumerState<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends ConsumerState<PlotsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(plotProvider.notifier).fetchPlots());
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final plotState = ref.watch(plotProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.headingText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang.t('plots.title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showPlotForm(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          lang.t('plots.add_plot'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _buildBody(context, plotState, lang),
    );
  }

  Widget _buildBody(BuildContext context, PlotState plotState, dynamic lang) {
    if (plotState.isLoading && plotState.plots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (plotState.error != null && plotState.plots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
              const SizedBox(height: 12),
              Text(plotState.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(plotProvider.notifier).fetchPlots(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (plotState.plots.isEmpty) {
      return _EmptyState(
        onAdd: () => _showPlotForm(context),
        lang: lang,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(plotProvider.notifier).fetchPlots(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: plotState.plots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final plot = plotState.plots[index];
          return _PlotCard(
            plot: plot,
            lang: lang,
            onEdit: () => _showPlotForm(context, plot: plot),
            onDelete: () => _confirmDelete(context, plot, lang),
          );
        },
      ),
    );
  }

  void _showPlotForm(BuildContext context, {Map<String, dynamic>? plot}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlotFormSheet(
        plot: plot,
        lang: ref.read(languageProvider),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> plot, dynamic lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(lang.t('plots.delete_plot')),
        content: Text(
          '"${plot['name']}" -- ${lang.t('plots.delete_confirm')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(lang.t('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(plotProvider.notifier)
          .deletePlot(plot['id'].toString());
    }
  }
}

// --- Empty state ---

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.lang});
  final VoidCallback onAdd;
  final dynamic lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.landscape_rounded,
                size: 72, color: AppColors.divider),
            const SizedBox(height: 16),
            Text(
              lang.t('plots.empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.t('plots.empty_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(lang.t('plots.add_first')),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Plot card ---

class _PlotCard extends StatelessWidget {
  const _PlotCard({
    required this.plot,
    required this.lang,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> plot;
  final dynamic lang;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = plot['name'] ?? '-';
    final location = plot['location'] ?? '';
    final area = plot['area_hectares'];
    final soil = plot['soil_type'] ?? '';

    return Container(
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.landscape_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(location,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.bodyText)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    if (area != null)
                      _chip(Icons.square_foot,
                          '${area.toStringAsFixed(2)} ha'),
                    if (soil.isNotEmpty) _chip(Icons.grass, soil),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.primary,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.bodyText),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.bodyText)),
      ],
    );
  }
}

// --- Add / Edit form (bottom sheet) ---

class _PlotFormSheet extends ConsumerStatefulWidget {
  const _PlotFormSheet({this.plot, required this.lang});
  final Map<String, dynamic>? plot;
  final dynamic lang;

  @override
  ConsumerState<_PlotFormSheet> createState() => _PlotFormSheetState();
}

class _PlotFormSheetState extends ConsumerState<_PlotFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  String? _soilType;
  bool _saving = false;

  bool get _isEdit => widget.plot != null;

  final _soilTypes = ['Alluvial', 'Clay', 'Sandy', 'Loamy', 'Black', 'Red'];

  @override
  void initState() {
    super.initState();
    final p = widget.plot;
    _nameCtrl = TextEditingController(text: p?['name'] ?? '');
    _locationCtrl = TextEditingController(text: p?['location'] ?? '');
    _areaCtrl = TextEditingController(
        text: p?['area_hectares']?.toString() ?? '');
    _latCtrl = TextEditingController(text: p?['latitude']?.toString() ?? '');
    _lngCtrl = TextEditingController(text: p?['longitude']?.toString() ?? '');
    _soilType = p?['soil_type'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _areaCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEdit
                      ? widget.lang.t('plots.edit_plot')
                      : widget.lang.t('plots.add_plot'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 20),
                _textField(_nameCtrl, widget.lang.t('plots.name'),
                    widget.lang.t('plots.name_hint'), required: true),
                const SizedBox(height: 14),
                _textField(_locationCtrl, widget.lang.t('plots.location'),
                    widget.lang.t('plots.location_hint')),
                const SizedBox(height: 14),
                _textField(_areaCtrl, widget.lang.t('plots.area'),
                    widget.lang.t('plots.area_hint'),
                    keyboard: TextInputType.number),
                const SizedBox(height: 14),

                // Soil type dropdown
                Text(widget.lang.t('plots.soil_type'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.headingText)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _soilType,
                      hint: Text(widget.lang.t('plots.soil_type'),
                          style:
                              const TextStyle(color: AppColors.bodyText)),
                      items: _soilTypes
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _soilType = v),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.bodyText),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // GPS coordinates
                Text(widget.lang.t('plots.gps_coords'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.headingText)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                          _latCtrl,
                          widget.lang.t('plots.latitude'),
                          'e.g. 31.45',
                          keyboard: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textField(
                          _lngCtrl,
                          widget.lang.t('plots.longitude'),
                          'e.g. 74.35',
                          keyboard: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.lang.t('common.save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headingText)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? widget.lang.t('auth.required')
                  : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
    };
    if (_locationCtrl.text.trim().isNotEmpty) {
      data['location'] = _locationCtrl.text.trim();
    }
    if (_areaCtrl.text.trim().isNotEmpty) {
      data['area_hectares'] = double.tryParse(_areaCtrl.text.trim());
    }
    if (_soilType != null) data['soil_type'] = _soilType;
    if (_latCtrl.text.trim().isNotEmpty) {
      data['latitude'] = double.tryParse(_latCtrl.text.trim());
    }
    if (_lngCtrl.text.trim().isNotEmpty) {
      data['longitude'] = double.tryParse(_lngCtrl.text.trim());
    }

    final notifier = ref.read(plotProvider.notifier);
    bool ok;
    if (_isEdit) {
      ok = await notifier.updatePlot(widget.plot!['id'].toString(), data);
    } else {
      ok = await notifier.createPlot(
        name: data['name'],
        location: data['location'] as String?,
        areaHectares: data['area_hectares'] as double?,
        soilType: data['soil_type'] as String?,
        latitude: data['latitude'] as double?,
        longitude: data['longitude'] as double?,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(plotProvider).error ?? 'Error')),
      );
    }
  }
}
