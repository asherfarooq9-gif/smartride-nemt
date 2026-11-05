import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () =>
                context.push(isDriver ? '/driver/profile' : '/profile'),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (val) =>
                ref.read(themeModeProvider.notifier).setDark(val),
          ),
          const Divider(),
          const _SectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Contact Us'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/contact'),
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            trailing: Text(
              '1.0.0',
              style: TextStyle(color: core.kTextSecondary),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: core.kError),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: core.kError),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_forever_outlined, color: core.kError),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: core.kError),
            ),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
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
