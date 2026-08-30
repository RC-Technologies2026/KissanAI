import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Data model for a language option with native script + English name.
class LanguageOptionData {
  const LanguageOptionData({
    required this.englishName,
    required this.nativeScript,
    required this.value,
  });

  final String englishName;
  final String nativeScript;
  final String value;
}

/// Reusable language option row.
///
/// Shows the language name in its own native script on the left (bold, large)
/// and the English name in muted gray on the right.
/// Selected row gets green border + light green tint.
class LanguageOption extends StatelessWidget {
  const LanguageOption({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final LanguageOptionData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Native script — bold, large
            Text(
              data.nativeScript,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.headingText,
              ),
            ),
            // English name — muted gray
            Text(
              data.englishName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
