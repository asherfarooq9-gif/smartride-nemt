import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/features/call/call_media.dart';
import 'package:patient_app/features/call/call_signaling.dart';
import 'package:smartride_core/smartride_core.dart' as core;

enum CallPhase {
  /// No call.
  idle,

  /// This phone rang the other one and is waiting.
  calling,

  /// The other person is ringing this phone.
  incoming,

  /// Both agreed; the audio is being connected.
  connecting,

  /// Talking.
  active,

  /// Over; [CallState.end] says how.
  ended,
}

enum CallEnd {
  hungUp,
  remoteHungUp,
  declined,
  noAnswer,
  missed,
  unreachable,
  failed,
  rideEnded,
  permissionDenied,
}

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.end,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.activeSince,
  });

  final CallPhase phase;
  final CallEnd? end;
  final bool isMuted;
  final bool isSpeakerOn;

  /// When the audio connected, for the call timer.
  final DateTime? activeSince;

  bool get isInCall =>
      phase == CallPhase.calling ||
      phase == CallPhase.incoming ||
      phase == CallPhase.connecting ||
      phase == CallPhase.active;

  CallState copyWith({
    CallPhase? phase,
    CallEnd? end,
    bool? isMuted,
    bool? isSpeakerOn,
    DateTime? activeSince,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        end: end ?? this.end,
        isMuted: isMuted ?? this.isMuted,
        isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
        activeSince: activeSince ?? this.activeSince,
      );
}

/// What a call needs from outside, so tests can replace all of it.
class CallSettings {
  const CallSettings({
    required this.createSignaling,
    required this.createMedia,
    required this.fetchIceServers,
    this.ringTimeout = const Duration(seconds: 45),
  });

  final CallSignaling Function() createSignaling;
  final CallMedia Function() createMedia;
  final Future<core.IceServers> Function(String rideId) fetchIceServers;

  /// How long to ring before giving up (calling) or counting it missed (incoming).
  final Duration ringTimeout;
}

final callSettingsProvider = Provider<CallSettings>(
  (ref) => const CallSettings(
    createSignaling: WsCallSignaling.new,
    createMedia: WebRtcCallMedia.new,
    fetchIceServers: core.getCallIceServers,
  ),
);

/// One ride's call: ringing, answering, the audio, and hanging up.
///
/// The caller sends `invite`; once the other side sends `accept` the caller makes
/// the offer, the other side answers, and both exchange candidates until the audio
/// connects. Every path ends in [CallPhase.ended] with a reason, closing the audio
/// and cancelling the ring timer.
class CallController extends StateNotifier<CallState> {
  CallController(this._settings, this.rideId) : super(const CallState()) {
    _signaling = _settings.createSignaling();
    _socketReady = _signaling.connect(rideId, onFrame: _onFrame);
  }

  final CallSettings _settings;
  final String rideId;
  late final CallSignaling _signaling;
  late final Future<void> _socketReady;
  CallMedia? _media;
  Timer? _ringTimer;
  bool _isDisposed = false;
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _earlyCandidates = [];

  // ── What the person does ────────────────────────────────────────────────────

  Future<void> startCall() async {
    if (_isDisposed ||
        (state.phase != CallPhase.idle && state.phase != CallPhase.ended)) {
      return;
    }
    _resetCallParts();
    state = const CallState(phase: CallPhase.calling);
    await _socketReady;
    if (_isDisposed || state.phase != CallPhase.calling) return;
    if (!_signaling.send({'type': 'invite'})) {
      _finish(CallEnd.failed);
      return;
    }
    _ring(onTimeout: () {
      _signaling.send({'type': 'hangup'});
      _finish(CallEnd.noAnswer);
    });
  }

  Future<void> accept() async {
    if (_isDisposed || state.phase != CallPhase.incoming) return;
    _ringTimer?.cancel();
    state = state.copyWith(phase: CallPhase.connecting);
    // Make sure there is a microphone before saying yes.
    if (!await _openMedia()) {
      _signaling.send({'type': 'decline'});
      return;
    }
    if (!_signaling.send({'type': 'accept'})) _finish(CallEnd.failed);
  }

  Future<void> decline() async {
    if (_isDisposed || state.phase != CallPhase.incoming) return;
    _signaling.send({'type': 'decline'});
    _finish(CallEnd.declined);
  }

  Future<void> hangUp() async {
    if (_isDisposed || !state.isInCall) return;
    _signaling.send({'type': 'hangup'});
    _finish(CallEnd.hungUp);
  }

  void toggleMute() {
    if (_isDisposed) return;
    final muted = !state.isMuted;
    _media?.setMuted(muted);
    state = state.copyWith(isMuted: muted);
  }

  Future<void> toggleSpeaker() async {
    if (_isDisposed) return;
    final on = !state.isSpeakerOn;
    await _media?.setSpeaker(on);
    if (!_isDisposed) state = state.copyWith(isSpeakerOn: on);
  }

  /// Back to idle once the person has seen how the call ended.
  void dismiss() {
    if (_isDisposed || state.phase != CallPhase.ended) return;
    state = const CallState();
  }

  // ── What arrives ────────────────────────────────────────────────────────────

  void _onFrame(Map<String, dynamic> frame) {
    if (_isDisposed) return;
    switch (frame['event']) {
      case 'unreachable':
        if (state.phase == CallPhase.calling) _finish(CallEnd.unreachable);
        return;
      case 'call_closed':
        if (state.isInCall) _finish(CallEnd.rideEnded);
        return;
    }
    switch (frame['type']) {
      case 'invite':
        _onInvite();
      case 'accept':
        if (state.phase == CallPhase.calling) unawaited(_onAccepted());
      case 'decline':
        if (state.phase == CallPhase.calling) _finish(CallEnd.declined);
      case 'offer':
        final sdp = frame['sdp'];
        if (sdp is String) unawaited(_onOffer(sdp));
      case 'answer':
        final sdp = frame['sdp'];
        if (sdp is String) unawaited(_onAnswer(sdp));
      case 'ice':
        final candidate = frame['candidate'];
        if (candidate is Map<String, dynamic>) {
          unawaited(_onCandidate(candidate));
        }
      case 'hangup':
        _onRemoteHangup();
    }
  }

  void _onInvite() {
    if (state.phase == CallPhase.idle || state.phase == CallPhase.ended) {
      _resetCallParts();
      state = const CallState(phase: CallPhase.incoming);
      _ring(onTimeout: () => _finish(CallEnd.missed));
    } else {
      _signaling.send({'type': 'decline'}); // already busy
    }
  }

  Future<void> _onAccepted() async {
    _ringTimer?.cancel();
    state = state.copyWith(phase: CallPhase.connecting);
    if (!await _openMedia()) {
      _signaling.send({'type': 'hangup'});
      return;
    }
    final media = _media;
    if (media == null || _isDisposed) return;
    final offer = await media.createOffer();
    if (_isDisposed || state.phase != CallPhase.connecting) return;
    if (!_signaling.send({'type': 'offer', 'sdp': offer})) {
      _finish(CallEnd.failed);
    }
  }

  Future<void> _onOffer(String sdp) async {
    final media = _media;
    if (media == null || state.phase != CallPhase.connecting) return;
    final answer = await media.createAnswer(sdp);
    if (_isDisposed || state.phase != CallPhase.connecting) return;
    _signaling.send({'type': 'answer', 'sdp': answer});
    await _remoteDescriptionApplied();
  }

  Future<void> _onAnswer(String sdp) async {
    final media = _media;
    if (media == null || state.phase != CallPhase.connecting) return;
    await media.applyAnswer(sdp);
    await _remoteDescriptionApplied();
  }

  Future<void> _remoteDescriptionApplied() async {
    _remoteDescriptionSet = true;
    final held = List.of(_earlyCandidates);
    _earlyCandidates.clear();
    for (final candidate in held) {
      if (_isDisposed) return;
      await _media?.addCandidate(candidate);
    }
  }

  Future<void> _onCandidate(Map<String, dynamic> candidate) async {
    if (!state.isInCall) return;
    final media = _media;
    if (media == null || !_remoteDescriptionSet) {
      _earlyCandidates.add(candidate); // held until the offer or answer is in
      return;
    }
    await media.addCandidate(candidate);
  }

  void _onRemoteHangup() {
    if (state.phase == CallPhase.incoming) {
      _finish(CallEnd.missed);
    } else if (state.isInCall) {
      _finish(CallEnd.remoteHungUp);
    }
  }

  // ── The audio ───────────────────────────────────────────────────────────────

  /// Gets the relay login and opens the microphone. False (after ending the call)
  /// when either is not possible.
  Future<bool> _openMedia() async {
    try {
      final ice = await _settings.fetchIceServers(rideId);
      if (_isDisposed) return false;
      final media = _settings.createMedia();
      _media = media;
      await media.open(
        iceServers: ice.servers,
        onCandidate: (candidate) {
          if (!_isDisposed && state.isInCall) {
            _signaling.send({'type': 'ice', 'candidate': candidate});
          }
        },
        onConnected: _onConnected,
        onFailed: _onMediaFailed,
      );
      return !_isDisposed;
    } on CallPermissionDenied {
      _finish(CallEnd.permissionDenied);
    } on core.AppError {
      _finish(CallEnd.failed);
    } on Object {
      _finish(CallEnd.failed);
    }
    return false;
  }

  void _onConnected() {
    if (_isDisposed || state.phase != CallPhase.connecting) return;
    state = state.copyWith(
      phase: CallPhase.active,
      activeSince: DateTime.now(),
    );
  }

  void _onMediaFailed() {
    if (_isDisposed || !state.isInCall) return;
    _signaling.send({'type': 'hangup'});
    _finish(CallEnd.failed);
  }

  // ── Ending ──────────────────────────────────────────────────────────────────

  void _ring({required void Function() onTimeout}) {
    _ringTimer?.cancel();
    _ringTimer = Timer(_settings.ringTimeout, () {
      if (!_isDisposed) onTimeout();
    });
  }

  void _resetCallParts() {
    _remoteDescriptionSet = false;
    _earlyCandidates.clear();
    _media = null;
  }

  void _finish(CallEnd reason) {
    if (_isDisposed) return;
    _ringTimer?.cancel();
    final media = _media;
    _media = null;
    if (media != null) unawaited(media.close());
    _remoteDescriptionSet = false;
    _earlyCandidates.clear();
    state = CallState(phase: CallPhase.ended, end: reason);
  }

  @override
  void dispose() {
    if (!_isDisposed &&
        (state.phase == CallPhase.calling ||
            state.phase == CallPhase.connecting ||
            state.phase == CallPhase.active)) {
      _signaling
          .send({'type': 'hangup'}); // do not leave the other side ringing
    }
    _isDisposed = true;
    _ringTimer?.cancel();
    final media = _media;
    _media = null;
    if (media != null) unawaited(media.close());
    unawaited(_signaling.close());
    super.dispose();
  }
}

final callControllerProvider =
    StateNotifierProvider.autoDispose.family<CallController, CallState, String>(
  (ref, rideId) => CallController(ref.watch(callSettingsProvider), rideId),
);
