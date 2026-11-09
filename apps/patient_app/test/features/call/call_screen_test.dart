import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/call/call_controller.dart';
import 'package:patient_app/features/call/call_media.dart';
import 'package:patient_app/features/call/call_screen.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import 'fakes.dart';

class _Harness {
  _Harness({Object? mediaOpenError})
      : media = FakeCallMedia(openError: mediaOpenError);

  final FakeCallSignaling signaling = FakeCallSignaling();
  final FakeCallMedia media;

  Future<void> pump(
    WidgetTester tester, {
    bool startCall = false,
    core.ChatSender me = core.ChatSender.patient,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callSettingsProvider.overrideWithValue(
            CallSettings(
              createSignaling: () => signaling,
              createMedia: () => media,
              fetchIceServers: (_) async =>
                  const core.IceServers(servers: [], ttl: Duration(hours: 1)),
            ),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CallScreen(
                        rideId: 'ride-1',
                        me: me,
                        startCall: startCall,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> receive(WidgetTester tester, Map<String, dynamic> frame) async {
    signaling.receive(frame);
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets('placing a call shows who is being called and how to stop',
      (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true);

    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Calling…'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);
    expect(find.text('Free internet call. Your number is not shown.'),
        findsOneWidget);
    expect(h.signaling.sentTypes, ['invite']);
  });

  testWidgets('a driver placing a call sees "Patient"', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true, me: core.ChatSender.driver);

    expect(find.text('Patient'), findsOneWidget);
  });

  testWidgets('an incoming call offers Answer and Decline', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await h.receive(tester, {'type': 'invite', 'from': 'driver'});

    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    expect(h.signaling.sentTypes, ['accept']);
    expect(find.text('Connecting…'), findsOneWidget);
  });

  testWidgets('declining sends decline and shows it ended', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.receive(tester, {'type': 'invite', 'from': 'driver'});

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(h.signaling.sentTypes, ['decline']);
    expect(find.text('Call declined'), findsOneWidget);
  });

  testWidgets('an active call shows a timer, mute and speaker', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await h.receive(tester, {'type': 'invite', 'from': 'driver'});
    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    await h.receive(tester, {'type': 'offer', 'sdp': 'o', 'from': 'driver'});
    h.media.emitConnected();
    await tester.pump();
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);

    await tester.tap(find.text('Mute'));
    await tester.pump();
    expect(h.media.muted, isTrue);
    expect(find.text('Unmute'), findsOneWidget);
  });

  testWidgets('back does not leave a call in progress', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true);

    await tester.binding.handlePopRoute(); // the Android back button
    await tester.pumpAndSettle();

    expect(find.text('Calling…'), findsOneWidget);
  });

  testWidgets('End call hangs up and shows how it ended', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true);

    await tester.tap(find.text('End call'));
    await tester.pumpAndSettle();

    expect(h.signaling.sentTypes, ['invite', 'hangup']);
    expect(find.text('Call ended'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('an unreachable person points to chat', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true);

    await h.receive(tester, {'event': 'unreachable'});

    expect(find.text('Not reachable right now. Try a message instead.'),
        findsOneWidget);
  });

  testWidgets('a refused microphone says how to fix it', (tester) async {
    final h = _Harness(mediaOpenError: const CallPermissionDenied());
    await h.pump(tester);
    await h.receive(tester, {'type': 'invite', 'from': 'driver'});

    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();

    expect(find.text('Allow the microphone in Settings to make calls.'),
        findsOneWidget);
  });

  testWidgets('Done after a call closes the screen', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true);
    await tester.tap(find.text('End call'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(CallScreen), findsNothing);
  });

  testWidgets('works in Urdu without overflow', (tester) async {
    final h = _Harness();
    await h.pump(tester, startCall: true, locale: const Locale('ur'));

    expect(find.text('کال کی جا رہی ہے…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
