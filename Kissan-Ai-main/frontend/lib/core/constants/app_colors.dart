import 'package:flutter/material.dart';

/// Design-system colours from the Kisan AI spec.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF5F0E4); // cream
  static const Color primary = Color(0xFF1F7A3D); // forest green
  static const Color primaryLight = Color(0xFFF0F7F1); // green tint (selected)
  static const Color headingText = Color(0xFF0F1B0F);
  static const Color bodyText = Color(0xFF6B7568);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF9A825);
  static const Color divider = Color(0xFFE5DFC8); // light border
}

/// Radius, spacing and typography constants.
class AppDimens {
  AppDimens._();

  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double pillRadius = 100.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
}

/// Reusable text styles.
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.headingText,
    height: 1.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.headingText,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.headingText,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyText,
    height: 1.5,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.headingText,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.bodyText,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  );

  static const TextStyle buttonOutlined = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.2,
  );
}
