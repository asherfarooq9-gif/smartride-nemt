import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/providers.dart';

/// Side drawer shared by both portals. Lets a multi-role account flip between
/// Patient and Driver instantly, or "Become a…" if the role isn't held yet.
class PortalDrawer extends ConsumerWidget {
  const PortalDrawer({super.key});

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
                  const Icon(Icons.local_hospital, color: Colors.white, size: 40),
                  const SizedBox(height: core.kSpaceSM),
                  const Text('SmartRide',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text(isDriver ? 'Driver portal' : 'Patient portal',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            // ── Patient portal entry ───────────────────────────────────────
            if (!isDriver)
              const ListTile(
                leading: Icon(Icons.check_circle, color: core.kPatientPrimary),
                title: Text('Patient',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Current portal'),
              )
            else if (hasPatient)
              ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: const Text('Switch to Patient'),
                onTap: () => _switch(context, ref, 'patient', '/'),
              )
            else
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Become a Patient'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/become-patient');
                },
              ),

            // ── Driver portal entry ────────────────────────────────────────
            if (isDriver)
              const ListTile(
                leading: Icon(Icons.check_circle, color: core.kOnlineGreen),
                title: Text('Driver',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Current portal'),
              )
            else if (hasDriver)
              ListTile(
                leading: const Icon(Icons.drive_eta_outlined),
                title: const Text('Switch to Driver'),
                onTap: () => _switch(context, ref, 'driver', '/driver'),
              )
            else
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Become a Driver'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/become-driver');
                },
              ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push(isDriver ? '/driver/profile' : '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push(isDriver ? '/driver/settings' : '/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: core.kError),
              title: const Text('Sign Out',
                  style: TextStyle(color: core.kError)),
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
      BuildContext context, WidgetRef ref, String role, String home) async {
    // Edge case: warn if a ride is being driven (GPS streaming) before leaving.
    if (ref.read(gpsStreamProvider)) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Active ride in progress'),
          content: const Text(
              'You are currently driving a ride. Switching portals will keep '
              'the ride active in the background. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Switch')),
          ],
        ),
      );
      if (leave != true) return;
    }
    await ref.read(authProvider.notifier).switchActiveRole(role);
    if (context.mounted) {
      Navigator.pop(context);
      context.go(home);
    }
  }
}
