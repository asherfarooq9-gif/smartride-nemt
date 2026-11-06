import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/settings/delete_account_dialog.dart';

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
        children: [
          _SectionHeader(context.l10n.account),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(context.l10n.profile),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () =>
                context.push(isDriver ? '/driver/profile' : '/profile'),
          ),
          const Divider(),
          _SectionHeader(context.l10n.appearance),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(context.l10n.darkMode),
            value: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (val) =>
                ref.read(themeModeProvider.notifier).setDark(val),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.language),
            trailing: Text(
              _currentLanguageName(ref),
              style: const TextStyle(color: core.kTextSecondary),
            ),
            onTap: () => _chooseLanguage(context, ref),
          ),
          const Divider(),
          _SectionHeader(context.l10n.support),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(context.l10n.helpAndFaq),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: Text(context.l10n.contactUs),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/contact'),
          ),
          const Divider(),
          _SectionHeader(context.l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.appVersion),
            trailing: const Text(
              '1.0.0',
              style: TextStyle(color: core.kTextSecondary),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: core.kError),
            title: Text(
              context.l10n.signOut,
              style: const TextStyle(color: core.kError),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.devices_other, color: core.kError),
            title: Text(
              context.l10n.signOutEverywhere,
              style: const TextStyle(color: core.kError),
            ),
            onTap: () => _signOutEverywhere(context, ref),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_forever_outlined, color: core.kError),
            title: Text(
              context.l10n.deleteAccount,
              style: const TextStyle(color: core.kError),
            ),
            onTap: () => _deleteAccount(context, ref),
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
        title: const Text('Sign Out'),
        content: Text(
          isDriver
              ? 'This will stop GPS streaming and sign you out.'
              : 'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: core.kError),
            child: const Text('Sign Out'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        core.kSpaceLG,
        core.kSpaceLG,
        core.kSpaceLG,
        core.kSpaceXS,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: core.kTextSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
