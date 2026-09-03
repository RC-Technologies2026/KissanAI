import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_image_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/weather_provider.dart';
import '../../router/app_router.dart';

/// Dashboard — post-onboarding home screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);
    final firstName = (authState.userName ?? 'Farmer').split(' ').first;

    // Preload all dashboard card images in the background so later opens are instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DashboardImageProvider.precacheAll(context);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const _AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded,
                color: AppColors.headingText, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/kisan_ai_icon.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            Text(
              lang.t('app.name'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _openQuickMenu(context, ref),
              child: _buildAvatar(authState, firstName),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Greeting
            Text(
              '${lang.t('dashboard.greeting')}, $firstName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.headingText,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lang.t('dashboard.your_farm'),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 24),

            // Weather card
            const _WeatherCard(),
            const SizedBox(height: 28),

            // Quick Actions heading
            Text(
              lang.t('dashboard.quick_actions'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 16),

            // Feature cards — 2-column grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                _FeatureCard(
                  title: lang.t('dashboard.disease_detection'),
                  icon: Icons.bug_report,
                  imageKey: 'disease',
                  fallbackAsset: 'assets/images/card_disease.png',
                  route: Routes.diseaseCapture,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.pest_detection'),
                  icon: Icons.science,
                  imageKey: 'pest',
                  fallbackAsset: 'assets/images/card_pest.png',
                  route: Routes.pestCapture,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.crop_recommendation'),
                  icon: Icons.agriculture,
                  imageKey: 'crop',
                  fallbackAsset: 'assets/images/card_crop.png',
                  route: Routes.cropRecommendation,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.irrigation_guide'),
                  icon: Icons.water_drop,
                  imageKey: 'irrigation',
                  fallbackAsset: 'assets/images/card_irrigation.png',
                  route: Routes.irrigationGuide,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.ask_kisan'),
                  icon: Icons.chat_bubble,
                  imageKey: 'chat',
                  fallbackAsset: 'assets/images/card_chat.png',
                  route: Routes.chat,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.view_history'),
                  icon: Icons.history,
                  imageKey: 'history',
                  fallbackAsset: 'assets/images/card_history.png',
                  route: Routes.history,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.my_plots'),
                  icon: Icons.landscape_rounded,
                  imageKey: 'plots',
                  fallbackAsset: 'assets/images/card_crop.png',
                  route: Routes.plots,
                ),
                _FeatureCard(
                  title: lang.t('dashboard.my_plants'),
                  icon: Icons.eco,
                  imageKey: 'plants',
                  fallbackAsset: 'assets/images/card_crop.png',
                  route: Routes.plants,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openQuickMenu(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _QuickMenuSheet(lang: lang),
    );
  }

  /// Build avatar widget: shows profile image if available, otherwise initial letter.
  static Widget _buildAvatar(AuthState authState, String firstName) {
    final imageUrl = authState.profileImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Full navigation drawer with every app feature.
class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);
    final name = authState.userName ?? 'Farmer';
    final firstName = name.split(' ').first;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final storage = LocalStorage.instance;
    final city = storage.farmCity;
    final province = storage.farmProvince;
    final location = (city != null && city.isNotEmpty && province != null && province.isNotEmpty)
        ? '$city, $province'
        : (province != null && province.isNotEmpty ? province : 'Location not set');
    final imageUrl = authState.profileImageUrl;

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.background,
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      image: (imageUrl != null && imageUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? Center(
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headingText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Feature navigation
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerTile(context, lang: lang,
                    icon: Icons.home_rounded,
                    labelKey: 'drawer.dashboard',
                    route: Routes.dashboard,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.wb_sunny,
                    labelKey: 'drawer.weather',
                    route: Routes.weather,
                    currentRoute: currentRoute,
                  ),
                  const Divider(height: 8, indent: 16, endIndent: 16),
                  _drawerTile(context, lang: lang,
                    icon: Icons.bug_report,
                    labelKey: 'drawer.disease',
                    route: Routes.diseaseCapture,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.science,
                    labelKey: 'drawer.pest',
                    route: Routes.pestCapture,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.medication,
                    labelKey: 'drawer.pesticide',
                    route: Routes.detectionRecommendation,
                    routeExtra: {'detectionType': 'disease'},
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.medication_liquid,
                    labelKey: 'drawer.insecticide',
                    route: Routes.detectionRecommendation,
                    routeExtra: {'detectionType': 'pest'},
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.agriculture,
                    labelKey: 'drawer.crop_rec',
                    route: Routes.cropRecommendation,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.water_drop,
                    labelKey: 'drawer.irrigation',
                    route: Routes.irrigationGuide,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.chat_bubble,
                    labelKey: 'drawer.chat',
                    route: Routes.chat,
                    currentRoute: currentRoute,
                  ),
                  const Divider(height: 8, indent: 16, endIndent: 16),
                  _drawerTile(context, lang: lang,
                    icon: Icons.landscape_rounded,
                    labelKey: 'drawer.plots',
                    route: Routes.plots,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.eco,
                    labelKey: 'drawer.plants',
                    route: Routes.plants,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.history,
                    labelKey: 'drawer.history',
                    route: Routes.history,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.person,
                    labelKey: 'drawer.profile',
                    route: Routes.profile,
                    currentRoute: currentRoute,
                  ),
                  _drawerTile(context, lang: lang,
                    icon: Icons.settings,
                    labelKey: 'drawer.settings',
                    route: Routes.settings,
                    currentRoute: currentRoute,
                  ),
                ],
              ),
            ),

            // Logout
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: Text(
                  lang.t('drawer.logout'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                  context.go(Routes.welcome);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required LanguageState lang,
    required IconData icon,
    required String labelKey,
    required String route,
    required String currentRoute,
    Map<String, dynamic>? routeExtra,
  }) {
    final isActive = currentRoute == route;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.primary : AppColors.bodyText,
      ),
      title: Text(
        lang.t(labelKey),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.headingText : AppColors.bodyText,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppColors.primaryLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        Navigator.pop(context);
        if (route == Routes.dashboard && currentRoute == Routes.dashboard) {
          return;
        }
        if (routeExtra != null) {
          context.push(route, extra: routeExtra);
        } else {
          context.push(route);
        }
      },
    );
  }
}

/// Quick-access bottom sheet tied to the avatar.
class _QuickMenuSheet extends ConsumerWidget {
  const _QuickMenuSheet({required this.lang});
  final LanguageState lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _menuTile(Icons.person, lang.t('drawer.profile'), () {
              Navigator.pop(context);
              context.push(Routes.profile);
            }),
            _menuTile(Icons.history, lang.t('drawer.history'), () {
              Navigator.pop(context);
              context.push(Routes.history);
            }),
            _menuTile(Icons.settings, lang.t('drawer.settings'), () {
              Navigator.pop(context);
              context.push(Routes.settings);
            }),
            const Divider(height: 24, indent: 24, endIndent: 24),
            _menuTile(Icons.logout, lang.t('drawer.logout'), () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
              context.go(Routes.welcome);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isDestructive ? AppColors.error : AppColors.primary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppColors.error : AppColors.headingText,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Simplified weather card with "See more" link to weather screen.
class _WeatherCard extends ConsumerWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);

    if (weather.loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF1565C0)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push(Routes.weather),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1565C0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(weather.conditionIcon, color: Colors.white, size: 48),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperatureC}°C',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  weather.condition,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${weather.rainProbability}%',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.air, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${weather.windSpeedKmh} km/h',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        weather.location,
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Feature entry card with local asset photo background + dark overlay.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.imageKey,
    required this.fallbackAsset,
    required this.route,
  });

  final String title;
  final IconData icon;
  final String imageKey;
  final String fallbackAsset;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live cached network image — rotates daily, falls back to asset.
              Image(
                image: DashboardImageProvider.imageProvider(imageKey),
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, _) {
                  if (frame != null) return child;
                  // Show local asset while the network image loads.
                  return Image.asset(
                    fallbackAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: AppColors.primary),
                  );
                },
                errorBuilder: (_, _, _) => Image.asset(
                  fallbackAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: AppColors.primary),
                ),
              ),

              // Dark gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
