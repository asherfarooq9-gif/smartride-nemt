import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../auth/auth_notifier.dart';

final _driverProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return await ApiClient.get('/api/v1/drivers/me') as Map<String, dynamic>;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_driverProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.red))),
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF00695C),
                child: Text(
                  ((profile['full_name'] as String?) ?? '').isNotEmpty
                      ? (profile['full_name'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile['full_name'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                profile['phone'] as String? ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              // Verification badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (profile['is_verified'] as bool? ?? false)
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (profile['is_verified'] as bool? ?? false)
                      ? 'Verified Driver'
                      : 'Pending Verification',
                  style: TextStyle(
                    color: (profile['is_verified'] as bool? ?? false)
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Vehicle info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Info',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF00695C)),
                      ),
                      const Divider(height: 16),
                      _InfoRow(
                          'License', profile['license_no'] as String? ?? 'N/A'),
                      _InfoRow(
                          'Plate',
                          profile['vehicle_plate'] as String? ?? 'N/A'),
                      _InfoRow(
                          'Vehicle',
                          profile['vehicle_type'] as String? ?? 'N/A'),
                      _InfoRow(
                          'Status',
                          profile['status'] as String? ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Sign out button
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content:
                          const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(authNotifierProvider.notifier)
                        .logout();
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label:
                    const Text('Sign Out', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
                width: 80,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
      );
}
