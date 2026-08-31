import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Reusable answer card with colored left border.
///
/// Used in the detection result screen to display the 4-question contract:
/// What is the problem? / Why did it happen? / What to do? / What to avoid?
class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
            top: const BorderSide(color: AppColors.divider, width: 1),
            right: const BorderSide(color: AppColors.divider, width: 1),
            bottom: const BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }
}
