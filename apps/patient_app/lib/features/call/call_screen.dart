import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/features/call/call_controller.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _kCallBackground = Color(0xFF0A1628);
const _kAnswerGreen = Color(0xFF34C759);
const _kEndRed = Color(0xFFFF3B30);

/// The call screen, in the style of a phone call: who it is, what is happening,
/// and big round buttons. While a call is going the back button is blocked, so the
/// audio is never left running behind a screen the person cannot see.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.rideId,
    required this.me,
    this.startCall = false,
  });

  final String rideId;

  /// Which side the person using this screen is on.
  final core.ChatSender me;

  /// Ring the other person as soon as the screen opens.
  final bool startCall;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.startCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(callControllerProvider(widget.rideId).notifier)
                .startCall(),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = callControllerProvider(widget.rideId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final other = widget.me == core.ChatSender.patient
        ? l10n.roleDriver
        : l10n.rolePatient;

    return PopScope(
      canPop: !state.isInCall,
      child: Scaffold(
        backgroundColor: _kCallBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(core.kSpaceXL),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: core.kSpaceXL),
                Text(
                  other,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: core.kSpaceSM),
                _Status(state: state),
                const Spacer(flex: 3),
                if (state.phase == CallPhase.ended)
                  _EndedControls(controller: controller)
                else if (state.phase == CallPhase.incoming)
                  _IncomingControls(controller: controller)
                else
                  _InCallControls(state: state, controller: controller),
                const SizedBox(height: core.kSpaceXL),
                Text(
                  l10n.callPrivacyNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the name: what the call is doing, the timer, or how it ended.
class _Status extends StatelessWidget {
  const _Status({required this.state});

  final CallState state;

  String _ended(AppLocalizations l10n) => switch (state.end) {
        CallEnd.hungUp || null => l10n.callEndedHungUp,
        CallEnd.remoteHungUp => l10n.callEndedRemote,
        CallEnd.declined => l10n.callEndedDeclined,
        CallEnd.noAnswer => l10n.callEndedNoAnswer,
        CallEnd.missed => l10n.callEndedMissed,
        CallEnd.unreachable => l10n.callEndedUnreachable,
        CallEnd.failed => l10n.callEndedFailed,
        CallEnd.rideEnded => l10n.callEndedRideEnded,
        CallEnd.permissionDenied => l10n.callPermissionDenied,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const style = TextStyle(color: Colors.white70, fontSize: 18);
    final since = state.activeSince;
    return switch (state.phase) {
      CallPhase.active when since != null => _Elapsed(since: since),
      CallPhase.calling => Text(l10n.callCalling, style: style),
      CallPhase.incoming => Text(l10n.callIncoming, style: style),
      CallPhase.connecting ||
      CallPhase.active =>
        Text(l10n.callConnecting, style: style),
      CallPhase.ended => Text(
          _ended(l10n),
          textAlign: TextAlign.center,
          style: style,
        ),
      CallPhase.idle => const SizedBox.shrink(),
    };
  }
}

/// mm:ss since the audio connected.
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since});

  final DateTime since;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now().difference(widget.since).inSeconds;
    final text = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 18,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background = const Color(0x2EFFFFFF),
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    // The label is part of the button, so tapping either one works.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: core.kSpaceSM),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.call_end,
          label: l10n.callDecline,
          background: _kEndRed,
          onPressed: controller.decline,
        ),
        _RoundButton(
          icon: Icons.call,
          label: l10n.callAnswer,
          background: _kAnswerGreen,
          onPressed: controller.accept,
        ),
      ],
    );
  }
}

class _InCallControls extends StatelessWidget {
  const _InCallControls({required this.state, required this.controller});

  final CallState state;
  final CallController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: state.isMuted ? Icons.mic_off : Icons.mic,
          label: state.isMuted ? l10n.callUnmute : l10n.callMute,
          background: state.isMuted ? Colors.white30 : const Color(0x2EFFFFFF),
          onPressed: controller.toggleMute,
        ),
        _RoundButton(
          icon: Icons.call_end,
          label: l10n.callEnd,
          background: _kEndRed,
          onPressed: controller.hangUp,
        ),
        _RoundButton(
          icon: state.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: l10n.callSpeaker,
          background:
              state.isSpeakerOn ? Colors.white30 : const Color(0x2EFFFFFF),
          onPressed: controller.toggleSpeaker,
        ),
      ],
    );
  }
}

class _EndedControls extends StatelessWidget {
  const _EndedControls({required this.controller});

  final CallController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _kCallBackground,
          minimumSize: const Size.fromHeight(core.kButtonHeight),
        ),
        onPressed: () {
          controller.dismiss();
          Navigator.of(context).maybePop();
        },
        child: Text(context.l10n.done),
      ),
    );
  }
}
