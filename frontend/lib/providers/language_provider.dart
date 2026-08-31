import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/app_translations.dart';
import '../core/storage/local_storage.dart';

/// Language provider — manages current language and provides translation helper.
class LanguageState {
  const LanguageState({this.language = 'English'});

  final String language;

  /// Translate a key using the current language.
  String t(String key) => AppTranslations.t(key, language);

  LanguageState copyWith({String? language}) =>
      LanguageState(language: language ?? this.language);
}

class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier() : super(LanguageState(
    language: LocalStorage.instance.language,
  ));

  void setLanguage(String language) {
    state = state.copyWith(language: language);
    LocalStorage.instance.language = language;
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>(
  (_) => LanguageNotifier(),
);
