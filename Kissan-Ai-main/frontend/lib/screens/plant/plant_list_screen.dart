import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/language_provider.dart';
import '../../providers/plant_provider.dart';
import '../../router/app_router.dart';

/// Screen showing all the user's registered plants.
class PlantListScreen extends ConsumerStatefulWidget {
  const PlantListScreen({super.key});

  @override
  ConsumerState<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends ConsumerState<PlantListScreen> {
  @override
  void initState() {
    super.initState();
    // Load plants on first display.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(plantProvider.notifier).loadPlants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final plantState = ref.watch(plantProvider);

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
          lang.t('plants.title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push(Routes.plantAdd),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          lang.t('plants.add_plant'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(lang, plantState),
    );
  }

  Widget _buildBody(LanguageState lang, PlantState plantState) {
    if (plantState.status == PlantStatus.loadingPlants && plantState.plants.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (plantState.plants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco_outlined, size: 64, color: AppColors.bodyText),
              const SizedBox(height: 16),
              Text(
                lang.t('plants.empty'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.headingText),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t('plants.empty_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.bodyText),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: plantState.plants.length,
      itemBuilder: (_, i) {
        final plant = plantState.plants[i];
        return _PlantCard(plant: plant);
      },
    );
  }
}

/// Card for a single plant in the list.
class _PlantCard extends ConsumerWidget {
  const _PlantCard({required this.plant});
  final PlantData plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthColor = plant.healthStatus == 'healthy'
        ? AppColors.primary
        : plant.healthStatus == 'sick'
            ? AppColors.error
            : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push('${Routes.plants}/${plant.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              // Plant icon / thumbnail
              Container(
                width: 48,
                height: 48,
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
                    Text(
                      plant.plantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.headingText,
                      ),
                    ),
                    if (plant.species != null && plant.species!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          plant.species!,
                          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
                        ),
                      ),
                  ],
                ),
              ),
              // Health badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plant.healthStatus ?? 'healthy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: healthColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.bodyText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
