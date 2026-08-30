import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/storage/local_storage.dart';
import '../providers/language_provider.dart';

/// Settings screen — language and notification preferences (persisted).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _notifications;

  final _languages = [
    'Urdu',
    'English',
    'Punjabi',
    'Sindhi',
    'Pashto',
    'Balochi',
  ];

  @override
  void initState() {
    super.initState();
    _notifications = LocalStorage.instance.notificationsEnabled;
  }

  void _setLanguage(String lang) {
    ref.read(languageProvider.notifier).setLanguage(lang);
  }

  void _setNotifications(bool v) {
    setState(() => _notifications = v);
    LocalStorage.instance.notificationsEnabled = v;
  }

  @override
  Widget build(BuildContext context) {
    final langState = ref.watch(languageProvider);
    final currentLang = langState.language;

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
        title: Text(
          langState.t('settings.title'),
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

            // Language section
            Text(
              langState.t('settings.language'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _languages.map((lang) {
                  final isSelected = currentLang == lang;
                  return GestureDetector(
                    onTap: () => _setLanguage(lang),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              lang,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.headingText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check,
                                color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Notifications section
            Text(
              langState.t('settings.notifications'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.bodyText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        langState.t('settings.push_notifications'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        langState.t('settings.weather_alerts'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.bodyText,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _notifications,
                    onChanged: _setNotifications,
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
