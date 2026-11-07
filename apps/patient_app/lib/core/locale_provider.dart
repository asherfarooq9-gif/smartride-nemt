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
