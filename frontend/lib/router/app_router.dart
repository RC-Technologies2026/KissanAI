import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/welcome_screen.dart';
import '../screens/register_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding/farm_location_screen.dart';
import '../screens/onboarding/language_selection_screen.dart';
import '../screens/onboarding/farmer_type_screen.dart';
import '../screens/onboarding/crops_selection_screen.dart';
import '../screens/onboarding/livestock_selection_screen.dart';
import '../screens/onboarding/farm_size_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/detection/camera_picker_screen.dart';
import '../screens/detection/image_preview_screen.dart';
import '../screens/detection/analyzing_screen.dart';
import '../screens/detection/detection_result_screen.dart';
import '../screens/detection/recommendation_screen.dart';
import '../screens/crop_recommendation_screen.dart';
import '../screens/irrigation_guide_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/weather_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';

/// Route path constants.
class Routes {
  Routes._();

  static const String splash = '/splash';
  static const String welcome = '/';
  static const String register = '/register';
  static const String login = '/login';

  // Onboarding
  static const String onboardingFarmLocation = '/onboarding/location';
  static const String onboardingLanguage = '/onboarding/language';
  static const String onboardingFarmerType = '/onboarding/farmer-type';
  static const String onboardingCrops = '/onboarding/crops';
  static const String onboardingLivestock = '/onboarding/livestock';
  static const String onboardingFarmSize = '/onboarding/farm-size';

  // Main app
  static const String dashboard = '/dashboard';

  // Detection flow (shared screens parameterized by DetectionType)
  static const String diseaseCapture = '/detection/camera/disease';
  static const String pestCapture = '/detection/camera/pest';
  static const String detectionPreview = '/detection/preview';
  static const String detectionAnalyzing = '/detection/analyzing';
  static const String detectionResult = '/detection/result';
  static const String detectionRecommendation = '/detection/recommendation';

  // Crop Recommendation
  static const String cropRecommendation = '/crop-recommendation';

  // Irrigation
  static const String irrigationGuide = '/irrigation';

  // Chat
  static const String chat = '/chat';

  // Menu
  static const String history = '/history';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String weather = '/weather';
  static const String settings = '/settings';
}

/// GoRouter instance provider — watches auth state for redirect logic.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isSplashRoute = state.matchedLocation == Routes.splash;
      final isAuthRoute = state.matchedLocation == Routes.welcome ||
          state.matchedLocation == Routes.register ||
          state.matchedLocation == Routes.login;
      final isOnboardingRoute =
          state.matchedLocation.startsWith('/onboarding');

      // Splash is always accessible
      if (isSplashRoute) return null;

      // Not authenticated and trying to access protected route → Welcome
      if (!isAuth && !isAuthRoute && !isOnboardingRoute) {
        return Routes.welcome;
      }

      // Authenticated and on auth route → Dashboard
      if (isAuth && isAuthRoute) {
        return Routes.dashboard;
      }

      return null;
    },
    routes: [
      // ── Splash ────────────────────────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      
      // ── Auth ────────────────────────────────────────────
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginScreen(),
      ),

      // ─── Onboarding ──────────────────────────────────────
      GoRoute(
        path: Routes.onboardingFarmLocation,
        builder: (_, _) => const FarmLocationScreen(),
      ),
      GoRoute(
        path: Routes.onboardingLanguage,
        builder: (_, _) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: Routes.onboardingFarmerType,
        builder: (_, _) => const FarmerTypeScreen(),
      ),
      GoRoute(
        path: Routes.onboardingCrops,
        builder: (_, _) => const CropsSelectionScreen(),
      ),
      GoRoute(
        path: Routes.onboardingLivestock,
        builder: (_, _) => const LivestockSelectionScreen(),
      ),
      GoRoute(
        path: Routes.onboardingFarmSize,
        builder: (_, _) => const FarmSizeScreen(),
      ),

      // ─── Dashboard ───────────────────────────────────────
      GoRoute(
        path: Routes.dashboard,
        builder: (_, _) => const DashboardScreen(),
      ),

      // ── Detection Flow (shared screens) ─────────────────
      GoRoute(
        path: Routes.diseaseCapture,
        builder: (_, _) =>
            const CameraPickerScreen(detectionType: DetectionType.disease),
      ),
      GoRoute(
        path: Routes.pestCapture,
        builder: (_, _) =>
            const CameraPickerScreen(detectionType: DetectionType.pest),
      ),
      GoRoute(
        path: Routes.detectionPreview,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final type =
              extra?['detectionType'] as DetectionType? ?? DetectionType.disease;
          final imagePath = extra?['imagePath'] as String?;
          return ImagePreviewScreen(detectionType: type, imagePath: imagePath);
        },
      ),
      GoRoute(
        path: Routes.detectionAnalyzing,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final type =
              extra?['detectionType'] as DetectionType? ?? DetectionType.disease;
          final imagePath = extra?['imagePath'] as String?;
          return AnalyzingScreen(detectionType: type, imagePath: imagePath);
        },
      ),
      GoRoute(
        path: Routes.detectionResult,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final type =
              extra?['detectionType'] as DetectionType? ?? DetectionType.disease;
          return DetectionResultScreen(detectionType: type);
        },
      ),
      GoRoute(
        path: Routes.detectionRecommendation,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final type =
              extra?['detectionType'] as DetectionType? ?? DetectionType.disease;
          return RecommendationScreen(detectionType: type);
        },
      ),

      // ─── Crop Recommendation ────────────────────────────
      GoRoute(
        path: Routes.cropRecommendation,
        builder: (_, _) => const CropRecommendationScreen(),
      ),

      // ─── Irrigation ──────────────────────────────────────
      GoRoute(
        path: Routes.irrigationGuide,
        builder: (_, _) => const IrrigationGuideScreen(),
      ),

      // ─── Chat ────────────────────────────────────────────
      GoRoute(
        path: Routes.chat,
        builder: (_, _) => const ChatScreen(),
      ),

      // ─── Menu ────────────────────────────────────────────
      GoRoute(
        path: Routes.history,
        builder: (_, _) => const HistoryScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.weather,
        builder: (_, _) => const WeatherScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
});
