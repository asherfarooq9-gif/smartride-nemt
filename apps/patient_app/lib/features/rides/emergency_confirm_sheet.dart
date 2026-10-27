import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/patient_location.dart';

/// Opens the emergency confirmation sheet: it shows where the ambulance would
/// be sent and lets the patient continue to the symptom form, which sends the
/// real request. It never claims that help is on the way.
///
/// [onCall] replaces the phone dialler (tests inject their own).
Future<void> showEmergencyConfirm(
  BuildContext context, {
  VoidCallback? onCall,
}) {
  // The router context outlives the sheet, so Continue can navigate after it.
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EmergencyConfirmSheet(
      onContinue: () => router.push('/symptoms'),
      onCall: onCall,
    ),
  );
}

class EmergencyConfirmSheet extends ConsumerStatefulWidget {
  const EmergencyConfirmSheet({
    super.key,
    required this.onContinue,
    this.onCall,
  });

  final VoidCallback onContinue;
  final VoidCallback? onCall;

  @override
  ConsumerState<EmergencyConfirmSheet> createState() =>
      _EmergencyConfirmSheetState();
}

class _EmergencyConfirmSheetState extends ConsumerState<EmergencyConfirmSheet> {
  @override
  void initState() {
    super.initState();
    // Opening this sheet is a deliberate emergency tap, so asking for the
    // location permission here is expected.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(patientLocationProvider.notifier).prompt();
    });
  }

  Future<void> _dial() async {
    final uri = Uri.parse('tel:1122');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(patientLocationProvider);
    final scheme = Theme.of(context).colorScheme;
    final isReady = location.status == LocationStatus.granted;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          kSpaceXL,
          0,
          kSpaceXL,
          kSpaceXL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: kEmergencyRed),
                const SizedBox(width: kSpaceSM),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Request emergency help?',
                      style: TextStyle(
                        fontSize: kFontHeading,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceSM),
            Text(
              'Check your pickup location, then tell us what is wrong.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: kSpaceLG),
            _LocationCard(
              location: location,
              onAsk: () => ref.read(patientLocationProvider.notifier).request(),
            ),
            const SizedBox(height: kSpaceXL),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmergencyRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: scheme.surfaceContainerLow,
              ),
              onPressed: isReady
                  ? () {
                      Navigator.of(context).pop();
                      widget.onContinue();
                    }
                  : null,
              child: const Text('Continue'),
            ),
            const SizedBox(height: kSpaceSM),
            OutlinedButton.icon(
              onPressed: widget.onCall ?? _dial,
              icon: const Icon(Icons.phone_in_talk_outlined),
              label: const Text('Call 1122'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onAsk});

  final PatientLocation location;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final position = location.position;

    final (IconData icon, String title, String? detail, String? action) =
        switch (location.status) {
      LocationStatus.loading => (
          Icons.my_location_rounded,
          'Finding your location…',
          null,
          null,
        ),
      LocationStatus.granted => (
          Icons.my_location_rounded,
          'Using your current location',
          position == null
              ? null
              : 'Accurate to about ${position.accuracy.round()} m\n'
                  '${position.latitude.toStringAsFixed(4)}, '
                  '${position.longitude.toStringAsFixed(4)}',
          null,
        ),
      LocationStatus.noFix => (
          Icons.location_searching_rounded,
          'We cannot find you yet',
          'Move to an open area, or call 1122 now.',
          'Try again',
        ),
      LocationStatus.denied => (
          Icons.location_off_outlined,
          'Location is needed to send help',
          'Allow location so the nearest ambulance knows where you are.',
          'Turn on location',
        ),
      LocationStatus.deniedForever => (
          Icons.location_off_outlined,
          'Location is blocked',
          'Open settings and allow location for SmartRide.',
          'Open settings',
        ),
      LocationStatus.serviceOff => (
          Icons.location_off_outlined,
          'Location is switched off',
          'Turn on location in your phone settings, then try again.',
          'Try again',
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLG),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            location.status == LocationStatus.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(
                    icon,
                    color: location.status == LocationStatus.granted
                        ? kBlueIos
                        : scheme.onSurfaceVariant,
                  ),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: kFontSmall,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action != null)
                    TextButton(
                      onPressed: onAsk,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(action),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
