import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../l10n/app_strings.dart';

class LanguageNotifier extends StateNotifier<AppLanguage> {
  static const _box = 'settings';
  static const _key = 'language';

  LanguageNotifier() : super(_load());

  static AppLanguage _load() {
    try {
      return Hive.box(_box).get(_key, defaultValue: 'en') == 'he'
          ? AppLanguage.he
          : AppLanguage.en;
    } catch (_) {
      return AppLanguage.en;
    }
  }

  void toggle() {
    final next = state == AppLanguage.en ? AppLanguage.he : AppLanguage.en;
    state = next;
    try {
      Hive.box(_box).put(_key, next == AppLanguage.he ? 'he' : 'en');
    } catch (_) {}
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) => LanguageNotifier(),
);

final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(languageProvider)),
);
