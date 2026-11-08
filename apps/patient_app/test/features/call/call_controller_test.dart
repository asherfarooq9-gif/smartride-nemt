import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/call/call_controller.dart';
import 'package:patient_app/features/call/call_media.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import 'fakes.dart';

const _ice = [
  {
    'urls': ['turn:relay:3478'],
    'username': 'u',
    'credential': 'c',
  },
];

class _Setup {
  _Setup(
      {Object? mediaOpenError, this.ringTimeout = const Duration(seconds: 30)})
      : media = FakeCallMedia(openError: mediaOpenError);

  final FakeCallSignaling signaling = FakeCallSignaling();
  final FakeCallMedia media;
  final Duration ringTimeout;
  Object? iceError;
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      callSettingsProvider.overrideWithValue(
        CallSettings(
          createSignaling: () => signaling,
          createMedia: () => media,
          fetchIceServers: (_) async {
            final error = iceError;
            if (error != null) throw error;
            return const core.IceServers(
              servers: _ice,
              ttl: Duration(hours: 1),
            );
          },
          ringTimeout: ringTimeout,
        ),
      ),
    ],
  );

  CallController get controller =>
      container.read(callControllerProvider('ride-1').notifier);
  CallState get state => container.read(callControllerProvider('ride-1'));

  /// Opens the controller and lets it connect the socket.
  Future<void> start() async {
    container.listen(callControllerProvider('ride-1'), (_, __) {});
    await pump();
  }

  Future<void> pump() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void dispose() => container.dispose();
}

Future<_Setup> _ready({
  Object? mediaOpenError,
  Duration ringTimeout = const Duration(seconds: 30),
}) async {
  final s = _Setup(mediaOpenError: mediaOpenError, ringTimeout: ringTimeout);
  addTearDown(s.dispose);
  await s.start();
  return s;
}

void main() {
  test('connects the call socket and starts idle', () async {
    final s = await _ready();

    expect(s.signaling.connectCalls, 1);
    expect(s.state.phase, CallPhase.idle);
  });

  group('calling out', () {
    test('invite, then offer after accept, then answer, then connected',
        () async {
      final s = await _ready();

      await s.controller.startCall();
      expect(s.state.phase, CallPhase.calling);
      expect(s.signaling.sentTypes, ['invite']);

      s.signaling.receive({'type': 'accept', 'from': 'driver'});
      await s.pump();
      expect(s.state.phase, CallPhase.connecting);
      expect(s.media.openedWith, _ice);
      expect(s.signaling.sent.last, {'type': 'offer', 'sdp': 'offer-sdp'});

      s.signaling
          .receive({'type': 'answer', 'sdp': 'answer-sdp', 'from': 'driver'});
      await s.pump();
      expect(s.media.appliedAnswer, 'answer-sdp');

      s.media.emitConnected();
      await s.pump();
      expect(s.state.phase, CallPhase.active);
    });

    test('a second startCall while one is running does nothing', () async {
      final s = await _ready();
      await s.controller.startCall();

      await s.controller.startCall();

      expect(s.signaling.sentTypes, ['invite']);
    });

    test('nobody listening ends it as unreachable', () async {
      final s = await _ready();
      await s.controller.startCall();

      s.signaling.receive({'event': 'unreachable'});
      await s.pump();

      expect(s.state.phase, CallPhase.ended);
      expect(s.state.end, CallEnd.unreachable);
    });

    test('no answer in time hangs up', () async {
      final s = await _ready(ringTimeout: const Duration(milliseconds: 30));
      await s.controller.startCall();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(s.state.end, CallEnd.noAnswer);
      expect(s.signaling.sentTypes, ['invite', 'hangup']);
    });

    test('the other side declining ends it as declined', () async {
      final s = await _ready();
      await s.controller.startCall();

      s.signaling.receive({'type': 'decline', 'from': 'driver'});
      await s.pump();

      expect(s.state.end, CallEnd.declined);
    });

    test('a failed signal send ends it as failed', () async {
      final s = await _ready();
      s.signaling.sendWorks = false;

      await s.controller.startCall();

      expect(s.state.end, CallEnd.failed);
    });

    test('a relay login that cannot be fetched ends it as failed', () async {
      final s = await _ready();
      await s.controller.startCall();
      s.iceError = const core.NetworkError();

      s.signaling.receive({'type': 'accept', 'from': 'driver'});
      await s.pump();

      expect(s.state.end, CallEnd.failed);
      expect(s.signaling.sentTypes, contains('hangup'));
    });
  });

  group('being called', () {
    test('invite, accept, offer, answer, connected', () async {
      final s = await _ready();

      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();
      expect(s.state.phase, CallPhase.incoming);

      await s.controller.accept();
      expect(s.state.phase, CallPhase.connecting);
      expect(s.signaling.sentTypes, ['accept']);
      expect(s.media.openedWith, _ice);

      s.signaling
          .receive({'type': 'offer', 'sdp': 'offer-sdp', 'from': 'driver'});
      await s.pump();
      expect(s.media.answeredOffer, 'offer-sdp');
      expect(s.signaling.sent.last, {'type': 'answer', 'sdp': 'answer-sdp'});

      s.media.emitConnected();
      await s.pump();
      expect(s.state.phase, CallPhase.active);
    });

    test('declining tells the caller and ends it', () async {
      final s = await _ready();
      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();

      await s.controller.decline();

      expect(s.signaling.sentTypes, ['decline']);
      expect(s.state.end, CallEnd.declined);
    });

    test('an unanswered ring becomes a missed call', () async {
      final s = await _ready(ringTimeout: const Duration(milliseconds: 30));
      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(s.state.end, CallEnd.missed);
      expect(s.signaling.sent, isEmpty);
    });

    test('an invite during a call is turned away as busy', () async {
      final s = await _ready();
      await s.controller.startCall();

      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();

      expect(s.signaling.sentTypes, ['invite', 'decline']);
      expect(s.state.phase, CallPhase.calling);
    });

    test('no microphone permission turns the call down without accepting it',
        () async {
      final s = await _ready(mediaOpenError: const CallPermissionDenied());
      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();

      await s.controller.accept();

      expect(s.state.end, CallEnd.permissionDenied);
      expect(s.signaling.sentTypes, ['decline']);
    });
  });

  group('during the call', () {
    Future<_Setup> active() async {
      final s = await _ready();
      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();
      await s.controller.accept();
      s.signaling
          .receive({'type': 'offer', 'sdp': 'offer-sdp', 'from': 'driver'});
      await s.pump();
      s.media.emitConnected();
      await s.pump();
      return s;
    }

    test('hanging up tells the other side and closes the audio', () async {
      final s = await active();

      await s.controller.hangUp();

      expect(s.signaling.sentTypes.last, 'hangup');
      expect(s.state.end, CallEnd.hungUp);
      expect(s.media.closed, isTrue);
    });

    test('the other side hanging up ends it and closes the audio', () async {
      final s = await active();

      s.signaling.receive({'type': 'hangup', 'from': 'driver'});
      await s.pump();

      expect(s.state.end, CallEnd.remoteHungUp);
      expect(s.media.closed, isTrue);
    });

    test('the audio failing ends it as failed and tells the other side',
        () async {
      final s = await active();

      s.media.emitFailed();
      await s.pump();

      expect(s.state.end, CallEnd.failed);
      expect(s.signaling.sentTypes.last, 'hangup');
    });

    test('the ride ending ends the call', () async {
      final s = await active();

      s.signaling.receive({'event': 'call_closed'});
      await s.pump();

      expect(s.state.end, CallEnd.rideEnded);
      expect(s.media.closed, isTrue);
    });

    test('mute and speaker reach the audio and show in the state', () async {
      final s = await active();

      s.controller.toggleMute();
      await s.controller.toggleSpeaker();

      expect(s.media.muted, isTrue);
      expect(s.media.speaker, isTrue);
      expect(s.state.isMuted, isTrue);
      expect(s.state.isSpeakerOn, isTrue);
    });

    test('candidates that arrive early are held until the offer is applied',
        () async {
      final s = await _ready();
      s.signaling.receive({'type': 'invite', 'from': 'driver'});
      await s.pump();
      await s.controller.accept();
      final candidate = {'candidate': 'c1', 'sdpMid': '0', 'sdpMLineIndex': 0};

      s.signaling
          .receive({'type': 'ice', 'candidate': candidate, 'from': 'driver'});
      await s.pump();
      expect(s.media.candidatesAdded, isEmpty);

      s.signaling
          .receive({'type': 'offer', 'sdp': 'offer-sdp', 'from': 'driver'});
      await s.pump();

      expect(s.media.candidatesAdded, [candidate]);
      expect(
        s.media.events.indexOf('createAnswer'),
        lessThan(s.media.events.indexOf('addCandidate')),
      );
    });

    test('this phone\'s own candidates are sent to the other side', () async {
      final s = await active();

      s.media.emitCandidate(
          {'candidate': 'mine', 'sdpMid': '0', 'sdpMLineIndex': 0});
      await s.pump();

      expect(s.signaling.sent.last['type'], 'ice');
      expect((s.signaling.sent.last['candidate'] as Map)['candidate'], 'mine');
    });
  });

  test('dismiss after a call goes back to idle', () async {
    final s = await _ready();
    s.signaling.receive({'type': 'invite', 'from': 'driver'});
    await s.pump();
    await s.controller.decline();

    s.controller.dismiss();

    expect(s.state.phase, CallPhase.idle);
    expect(s.state.end, isNull);
  });

  test('leaving the screen closes the socket and any audio', () async {
    final s = await _ready();
    await s.controller.startCall();
    s.signaling.receive({'type': 'accept', 'from': 'driver'});
    await s.pump();

    s.container.dispose();
    await s.pump();

    expect(s.signaling.closeCalls, 1);
    expect(s.media.closed, isTrue);
  });

  test('nothing is sent after the controller is gone', () async {
    final s = await _ready();
    final controller = s.controller;
    s.container.dispose();

    await controller.startCall();

    expect(s.signaling.sent, isEmpty);
  });

  test('a signal with an unknown type is ignored', () async {
    final s = await _ready();

    s.signaling.receive({'type': 'shout', 'from': 'driver'});
    s.signaling.receive({'nothing': true});
    await s.pump();

    expect(s.state.phase, CallPhase.idle);
  });

  test('timers are cancelled when a call ends', () async {
    final s = await _ready(ringTimeout: const Duration(milliseconds: 40));
    await s.controller.startCall();
    s.signaling.receive({'type': 'decline', 'from': 'driver'});
    await s.pump();

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(s.signaling.sentTypes, ['invite']); // no late "hangup"
    unawaited(Future<void>.value());
  });
}
