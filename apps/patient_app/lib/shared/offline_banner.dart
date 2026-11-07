import 'package:flutter/material.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Shows a slim bar above the app while the server cannot be reached, so the
/// user knows why nothing loads and that the app will keep trying.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: core.ApiClient.isReachable,
          builder: (context, isReachable, _) {
            if (isReachable) return const SizedBox.shrink();
            return Semantics(
              liveRegion: true,
              child: Material(
                color: core.kError,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: core.kSpaceLG,
                        vertical: core.kSpaceSM,
                      ),
                      child: Text(
                        context.l10n.offlineBanner,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}
