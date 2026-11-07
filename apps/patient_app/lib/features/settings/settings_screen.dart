import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/settings/delete_account_dialog.dart';
import 'package:patient_app/shared/apple_list.dart';

/// Shared by the patient and driver apps. [isDriver] picks the profile route,
/// the sign-out wording and destination, and stops GPS streaming on sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.isDriver = false});

  final bool isDriver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: core.kSpaceXXL),
        children: [
          AppleSection(
            header: context.l10n.account,
            children: [
              AppleRow(
                icon: Icons.person,
                title: context.l10n.profile,
                onTap: () =>
                    context.push(isDriver ? '/driver/profile' : '/profile'),
              ),
            ],
          ),
          AppleSection(
            header: context.l10n.appearance,
            dividerIndent: appleIconDividerIndent,
            children: [
              AppleSwitchRow(
                icon: Icons.dark_mode_outlined,
                title: context.l10n.darkMode,
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (val) =>
                    ref.read(themeModeProvider.notifier).setDark(val),
              ),
              AppleRow(
                icon: Icons.language,
                title: context.l10n.language,
                value: _currentLanguageName(ref),
                onTap: () => _chooseLanguage(context, ref),
              ),
            ],
          ),
          AppleSection(
            header: context.l10n.support,
            dividerIndent: appleIconDividerIndent,
            children: [
              AppleRow(
                icon: Icons.help_outline,
                title: context.l10n.helpAndFaq,
                onTap: () => context.push('/help'),
              ),
              AppleRow(
                icon: Icons.contact_support,
                title: context.l10n.contactUs,
                onTap: () => context.push('/contact'),
              ),
            ],
          ),
          AppleSection(
            header: context.l10n.about,
            children: [
              AppleRow(
                icon: Icons.info_outline,
                title: context.l10n.appVersion,
                value: '1.0.0',
              ),
            ],
          ),
          AppleSection(
            children: [
              AppleRow(
                title: context.l10n.signOut,
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
              AppleRow(
                title: context.l10n.signOutEverywhere,
                destructive: true,
                onTap: () => _signOutEverywhere(context, ref),
              ),
              AppleRow(
                title: context.l10n.deleteAccount,
                destructive: true,
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _currentLanguageName(WidgetRef ref) {
    final chosen = ref.watch(localeProvider);
    return supportedLanguages
        .firstWhere(
          (entry) => entry.$1.languageCode == (chosen?.languageCode ?? 'en'),
          orElse: () => supportedLanguages.first,
        )
        .$2;
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(localeProvider)?.languageCode ?? 'en';
    final picked = await showModalBottomSheet<Locale>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(core.kSpaceLG),
              child: Text(
                sheetContext.l10n.chooseLanguage,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final (locale, name) in supportedLanguages)
              ListTile(
                title: Text(name),
                trailing: locale.languageCode == current
                    ? const Icon(Icons.check, color: core.kPatientPrimary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, locale),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(localeProvider.notifier).setLocale(picked);
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final isDeleted = await showDeleteAccountDialog(context);
    if (isDeleted != true || !context.mounted) return;
    if (isDriver) {
      await ref.read(gpsStreamProvider.notifier).stopStreaming();
      if (!context.mounted) return;
    }
    context.go(isDriver ? '/welcome' : '/login');
  }

  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.signOutEverywhere),
        content: Text(l10n.signOutEverywhereBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: core.kError),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (isDriver) {
      await ref.read(gpsStreamProvider.notifier).stopStreaming();
      if (!context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authProvider.notifier).signOutEverywhere();
    } on core.AppError {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.signOutEverywhereFailed)),
      );
      return;
    }
    if (context.mounted) context.go(isDriver ? '/welcome' : '/login');
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.signOutTitle),
        content: Text(
          isDriver ? context.l10n.signOutDriverBody : context.l10n.signOutBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: core.kError),
            child: Text(context.l10n.signOutTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (isDriver) {
      await ref.read(gpsStreamProvider.notifier).stopStreaming();
      if (!context.mounted) return;
    }
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go(isDriver ? '/welcome' : '/login');
  }
}
