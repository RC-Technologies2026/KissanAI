import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/language_provider.dart';
import '../../providers/plant_provider.dart';
import '../../widgets/answer_card.dart';

/// Plant detail + diagnosis screen.
///
/// Shows the plant info, a "Diagnose" button that opens the camera/gallery,
/// then displays the diagnosis result inline.
class PlantDetailScreen extends ConsumerStatefulWidget {
  const PlantDetailScreen({super.key, required this.plantId});

  final String plantId;

  @override
  ConsumerState<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends ConsumerState<PlantDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  Future<void> _pickAndDiagnose() async {
    setState(() => _picking = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) {
        final gallery = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (gallery == null) {
          setState(() => _picking = false);
          return;
        }
        await _runDiagnosis(gallery.path);
        return;
      }
      await _runDiagnosis(photo.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _runDiagnosis(String filePath) async {
    final lang = ref.read(languageProvider);
    await ref.read(plantProvider.notifier).diagnosePlant(
          plantId: widget.plantId,
          filePath: filePath,
          language: lang.language.toLowerCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final plantState = ref.watch(plantProvider);

    final plant = plantState.plants.cast<PlantData?>().firstWhere(
          (p) => p?.id == widget.plantId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.headingText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          plant?.plantName ?? lang.t('plants.title'),
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
            const SizedBox(height: 8),
            _PlantInfoCard(plant: plant),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _picking ? null : _pickAndDiagnose,
                icon: _picking
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.camera_alt, size: 22),
                label: Text(
                  _picking ? lang.t('plants.diagnosing') : lang.t('plants.diagnose'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildDiagnosisArea(lang, plantState),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisArea(LanguageState lang, PlantState plantState) {
    switch (plantState.status) {
      case PlantStatus.loadingDiagnosis:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Analyzing your plant photo...',
                    style: TextStyle(fontSize: 15, color: AppColors.bodyText)),
              ],
            ),
          ),
        );
      case PlantStatus.failure:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.cloud_off, color: AppColors.error, size: 28),
                SizedBox(width: 10),
                Text('Analysis Failed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.headingText)),
              ]),
              const SizedBox(height: 12),
              Text(plantState.errorMessage ?? 'Something went wrong.',
                  style: const TextStyle(fontSize: 15, color: AppColors.bodyText, height: 1.5)),
            ],
          ),
        );
      case PlantStatus.success:
        final result = plantState.diagnosisResult;
        if (result == null) return const SizedBox.shrink();
        return _DiagnosisResult(result: result);
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            const Icon(Icons.photo_camera_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(lang.t('plants.diagnose_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.bodyText, height: 1.5)),
          ]),
        );
    }
  }
}

// --- Plant info card ---------------------------------------------------------

class _PlantInfoCard extends StatelessWidget {
  const _PlantInfoCard({this.plant});
  final PlantData? plant;

  @override
  Widget build(BuildContext context) {
    if (plant == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Loading...'),
      );
    }

    final healthColor = plant!.healthStatus == 'healthy'
        ? AppColors.primary
        : plant!.healthStatus == 'sick'
            ? AppColors.error
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant!.plantName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingText)),
                    if (plant!.species != null && plant!.species!.isNotEmpty)
                      Text(plant!.species!,
                          style: const TextStyle(fontSize: 14, color: AppColors.bodyText, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(plant!.healthStatus ?? 'healthy',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: healthColor)),
              ),
            ],
          ),
          if (plant!.notes != null && plant!.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(plant!.notes!,
                style: const TextStyle(fontSize: 14, color: AppColors.bodyText, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// --- Diagnosis result --------------------------------------------------------

class _DiagnosisResult extends StatelessWidget {
  const _DiagnosisResult({required this.result});
  final PlantDiagnosisData result;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  bool get _isHighConfidence =>
      result.confidence != null && result.confidence! >= 0.70;

  String? get _confPercent =>
      result.confidence != null ? (result.confidence! * 100).round().toString() : null;

  String get _detectedOn {
    final dt = result.detectedAt;
    if (dt == null) return 'Diagnosed: just now';
    return 'Diagnosed: ${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cards = result.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: result.confidence == null
                ? AppColors.bodyText
                : _isHighConfidence ? AppColors.primary : AppColors.warning,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              result.confidence == null
                  ? 'Confidence unavailable'
                  : _isHighConfidence
                      ? '$_confPercent% Confident'
                      : 'Low Confidence - Consult a horticulturist',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.issueName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.headingText)),
              if (result.issueCategory != null) ...[
                const SizedBox(height: 6),
                Text('Category: ${result.issueCategory}',
                    style: const TextStyle(fontSize: 14, color: AppColors.bodyText)),
              ],
              const SizedBox(height: 4),
              Text(_detectedOn,
                  style: const TextStyle(fontSize: 14, color: AppColors.bodyText)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (cards.isEmpty)
          AnswerCard(
            icon: Icons.description_outlined,
            iconColor: AppColors.primary,
            borderColor: AppColors.primary,
            title: 'Diagnosis',
            body: result.issueName,
          )
        else
          ...cards.map(_cardForSection),
      ],
    );
  }

  Widget _cardForSection(PlantDiagnosisSection section) {
    final t = section.title.toLowerCase();
    if (t.contains('symptom')) {
      return AnswerCard(icon: Icons.search, iconColor: Colors.blue, borderColor: Colors.blue, title: section.title, body: section.body);
    }
    if (t.contains('treatment') || t.contains('care')) {
      return AnswerCard(icon: Icons.check_circle_outline, iconColor: AppColors.primary, borderColor: AppColors.primary, title: section.title, body: section.body);
    }
    return AnswerCard(icon: Icons.help_outline, iconColor: AppColors.primary, borderColor: AppColors.primary, title: section.title, body: section.body);
  }
}
