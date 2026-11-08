import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/shared/apple_list.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Shown once, on the first launch before signing in: pick English or Urdu.
/// Tapping a language switches the screen straight away, so people can see
/// what they are choosing; Continue confirms it and opens the welcome page.
/// The choice can be changed later in Settings.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  /// The language the app is showing now, or English if the phone's language
  /// is not one we translate into.
  String _shown(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final isSupported =
        supportedLanguages.any((entry) => entry.$1.languageCode == code);
    return isSupported ? code : 'en';
  }

  Future<void> _continue(
    BuildContext context,
    WidgetRef ref,
    String shown,
  ) async {
    final locale = supportedLanguages
        .firstWhere((entry) => entry.$1.languageCode == shown)
        .$1;
    await ref.read(localeProvider.notifier).setLocale(locale);
    ref.read(languageChosenProvider.notifier).markChosen();
    if (context.mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final shown = _shown(context);
    final link = scheme.brightness == Brightness.dark
        ? core.kDarkAccent
        : scheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: core.kSpaceLG),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child:
                    const Icon(Icons.language, size: 40, color: Colors.white),
              ),
              const SizedBox(height: core.kSpaceXL),
              Text(
                context.l10n.chooseLanguage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: core.kSpaceXL),
              AppleSection(
                children: [
                  for (final (locale, name) in supportedLanguages)
                    AppleRow(
                      title: name,
                      trailing: locale.languageCode == shown
                          ? Icon(Icons.check, size: 22, color: link)
                          // Keeps the row from showing a "more" chevron.
                          : const SizedBox(width: 22),
                      onTap: () =>
                          ref.read(localeProvider.notifier).setLocale(locale),
                    ),
                ],
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: core.kSpaceLG),
                child: core.PrimaryButton(
                  label: context.l10n.continueLabel,
                  onPressed: () => _continue(context, ref, shown),
                  color: core.kPatientPrimary,
                  height: core.kButtonHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
