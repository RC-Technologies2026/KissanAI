import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Reusable casc dropdown with the app's rounded design.
///
/// Displays a label, a styled container with a dropdown, and supports
/// cascading selection (items change based on parent selection).
class CascadingDropdown extends StatelessWidget {
  const CascadingDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isValid = items.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.headingText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: isValid ? value : null,
              hint: Text(
                'Select $label',
                style: const TextStyle(
                    color: AppColors.bodyText, fontSize: 15),
              ),
              items: items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.headingText,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.bodyText, size: 26),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
