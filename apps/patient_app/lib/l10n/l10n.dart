import 'package:flutter/widgets.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/l10n/app_localizations_en.dart';

export 'package:patient_app/l10n/app_localizations.dart';

/// The app's translated text for the current language. Falls back to English
/// when no localization is installed, so a bare widget (in a test) still shows
/// real text.
extension L10nContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}
