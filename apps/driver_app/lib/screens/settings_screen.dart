import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications_active_rounded,
            label: 'Ride Alerts',
            subtitle: 'Sound when a new ride is assigned',
            trailing: Switch(value: true, activeThumbColor: kGreen, activeTrackColor: kGreen.withValues(alpha: 0.3), onChanged: (_) {}),
          ),
          _SettingsTile(
            icon: Icons.vibration_rounded,
            label: 'Vibration',
            subtitle: 'Vibrate on new ride request',
            trailing: Switch(value: true, activeThumbColor: kGreen, activeTrackColor: kGreen.withValues(alpha: 0.3), onChanged: (_) {}),
          ),
          const SizedBox(height: 8),

          _SectionHeader(label: 'App'),
          _SettingsTile(
            icon: Icons.language_rounded,
            label: 'Language',
            subtitle: 'English',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'About SmartRide',
            subtitle: 'Version 1.0.0 — NEMT Driver App',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'SmartRide Driver',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 SmartRide NEMT',
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            subtitle: 'FAQs and contact support',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () {},
          ),
          const SizedBox(height: 8),

          _SectionHeader(label: 'Account'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: kRed,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(gpsStreamProvider.notifier).stopStreaming();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: color ?? kGreen, size: 22),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
