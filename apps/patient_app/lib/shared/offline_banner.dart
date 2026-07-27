import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/connectivity.dart';

/// Thin red strip shown at the top of every screen while the device has no
/// network path. Absent (zero height) once connectivity returns.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (isOnline) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      label: 'No internet connection',
      child: Material(
        color: Colors.red.shade700,
        child: const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
