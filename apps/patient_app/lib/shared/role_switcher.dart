import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/providers.dart';

/// Side drawer shared by both portals. Lets a multi-role account flip between
/// Patient and Driver instantly, or "Become a…" if the role isn't held yet.
class PortalDrawer extends ConsumerWidget {
  const PortalDrawer({super.key});

  /// What the driver reaches from the menu, so the home screen can stay bare.
  static List<(IconData, String, String)> _driverSections(AppLocalizations l) =>
      [
        (Icons.event_available_outlined, l.scheduled, '/driver/scheduled'),
        (Icons.payments_outlined, l.earnings, '/driver/earnings'),
        (Icons.trending_up_rounded, l.demandForecast, '/driver/demand'),
        (Icons.account_balance_wallet_outlined, l.wallet, '/driver/wallet'),
        (Icons.history_rounded, l.rideHistory, '/driver/history'),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final active = ref.watch(activeRoleProvider);
    final hasPatient = roles.contains('patient');
    final hasDriver = roles.contains('driver');
    final isDriver = active == 'driver';

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.local_hospital,
                      color: Colors.white, size: 40),
                  const SizedBox(height: core.kSpaceSM),
                  Text(context.l10n.smartRideName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text(
                      isDriver
                          ? context.l10n.driverPortal
                          : context.l10n.patientPortal,
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            // ── Patient portal entry ───────────────────────────────────────
            if (!isDriver)
              ListTile(
                leading:
                    const Icon(Icons.check_circle, color: core.kPatientPrimary),
                title: Text(context.l10n.patientWord,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(context.l10n.currentPortal),
              )
            else if (hasPatient)
              ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: Text(context.l10n.switchToPatient),
                onTap: () => _switch(context, ref, 'patient', '/'),
              )
            else
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(context.l10n.becomePatient),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/become-patient');
                },
              ),

            // ── Driver portal entry ────────────────────────────────────────
            if (isDriver) ...[
              ListTile(
                leading:
                    const Icon(Icons.check_circle, color: core.kOnlineGreen),
                title: Text(context.l10n.driverWord,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(context.l10n.currentPortal),
              ),
              for (final (icon, title, path) in _driverSections(context.l10n))
                ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(path);
                  },
                ),
            ] else if (hasDriver)
              ListTile(
                leading: const Icon(Icons.drive_eta_outlined),
                title: Text(context.l10n.switchToDriver),
                onTap: () => _switch(context, ref, 'driver', '/driver'),
              )
            else
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(context.l10n.becomeDriver),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/become-driver');
                },
              ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(context.l10n.profileTitle),
              onTap: () {
                Navigator.pop(context);
                context.push(isDriver ? '/driver/profile' : '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.l10n.settingsTitle),
              onTap: () {
                Navigator.pop(context);
                context.push(isDriver ? '/driver/settings' : '/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: core.kError),
              title: Text(context.l10n.signOutTitle,
                  style: const TextStyle(color: core.kError)),
              onTap: () async {
                await ref.read(gpsStreamProvider.notifier).stopStreaming();
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/welcome');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switch(
          BuildContext context, WidgetRef ref, String role, String home) =>
      switchPortal(context, ref, role, home, closeDrawer: true);
}

/// Flips the active portal and goes to its home screen. Pass [closeDrawer] when
/// called from the portal drawer so the drawer is closed first.
Future<void> switchPortal(
  BuildContext context,
  WidgetRef ref,
  String role,
  String home, {
  bool closeDrawer = false,
}) async {
  // Edge case: warn if a ride is being driven (GPS streaming) before leaving.
  if (ref.read(gpsStreamProvider).isActive) {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.activeRideInProgress),
        content: const Text(
            'You are currently driving a ride. Switching portals will keep '
            'the ride active in the background. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.stay)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.switchLabel)),
        ],
      ),
    );
    if (leave != true) return;
  }
  try {
    await ref.read(authProvider.notifier).switchActiveRole(role);
  } on core.AppError catch (e) {
    if (context.mounted) _showSwitchError(context, e.message);
    return;
  } on Exception catch (e, st) {
    core.ErrorReporter.report('Switching portal failed', e, st);
    if (context.mounted) {
      _showSwitchError(context, context.l10n.couldNotSwitch);
    }
    return;
  }
  if (context.mounted) {
    if (closeDrawer) Navigator.pop(context);
    context.go(home);
  }
}

void _showSwitchError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: core.kError),
  );
}
