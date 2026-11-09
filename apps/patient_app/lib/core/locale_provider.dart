import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _kLocaleKey = 'app_locale';

/// Languages the app is translated into, with each one's own name.
const supportedLanguages = <(Locale, String)>[
  (Locale('en'), 'English'),
  (Locale('ur'), 'اردو'),
];

/// The language the user chose in Settings, or null to follow the phone.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final saved = await core.SecureStorage.instance.readValue(_kLocaleKey);
    final match = supportedLanguages
        .where((entry) => entry.$1.languageCode == saved)
        .firstOrNull;
    if (match != null && mounted) state = match.$1;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await core.SecureStorage.instance
        .saveValue(_kLocaleKey, locale.languageCode);
  }
}

/// Whether the person has picked a language on this phone: true once one is
/// saved, false on a first launch, null while storage is still being read.
final languageChosenProvider =
    StateNotifierProvider<LanguageChosenNotifier, bool?>(
  (ref) => LanguageChosenNotifier(),
);

class LanguageChosenNotifier extends StateNotifier<bool?> {
  LanguageChosenNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final saved = await core.SecureStorage.instance.readValue(_kLocaleKey);
    final isKnown =
        supportedLanguages.any((entry) => entry.$1.languageCode == saved);
    if (mounted) state = isKnown;
  }

  /// Called after the chosen language has been saved by [LocaleNotifier].
  void markChosen() => state = true;
}

/// Where to send someone who has not picked a language yet, or null to leave
/// the route alone. People who are signed in never see the language screen.
String? languageRedirect({
  required bool? chosen,
  required bool isLoggedIn,
  required String location,
}) {
  const screen = '/language';
  if (chosen == null) return null;
  if (isLoggedIn) return location == screen ? '/' : null;
  if (!chosen) return location == screen ? null : screen;
  return location == screen ? '/welcome' : null;
}
