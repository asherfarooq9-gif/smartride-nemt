import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/call/call_controller.dart';

/// Wrap a ride screen with this so the call channel stays open while the ride is
/// on screen, and an incoming call opens the call page by itself.
///
/// Version 1 rings only while the app is open; a closed or locked phone gets a
/// push notification instead (sent by the server).
class IncomingCallListener extends ConsumerWidget {
  const IncomingCallListener({
    super.key,
    required this.rideId,
    required this.callPath,
    required this.child,
  });

  final String rideId;

  /// The route of the call page for this person (patient or driver).
  final String callPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listening keeps the (auto-dispose) controller, and so its socket, alive.
    ref.listen(callControllerProvider(rideId), (previous, next) {
      final wasIdle = previous == null || previous.phase == CallPhase.idle;
      if (next.phase == CallPhase.incoming && wasIdle) {
        context.push(callPath);
      }
    });
    return child;
  }
}
