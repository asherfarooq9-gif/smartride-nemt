import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/call/call_controller.dart';
import 'package:patient_app/features/call/incoming_call_listener.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import 'fakes.dart';

Future<FakeCallSignaling> _pump(WidgetTester tester) async {
  final signaling = FakeCallSignaling();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const IncomingCallListener(
          rideId: 'ride-1',
          callPath: '/call/ride-1',
          child: Scaffold(body: Text('ride screen')),
        ),
      ),
      GoRoute(
        path: '/call/:id',
        builder: (_, __) => const Scaffold(body: Text('call page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        callSettingsProvider.overrideWithValue(
          CallSettings(
            createSignaling: () => signaling,
            createMedia: FakeCallMedia.new,
            fetchIceServers: (_) async =>
                const core.IceServers(servers: [], ttl: Duration(hours: 1)),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return signaling;
}

void main() {
  testWidgets('shows its child and listens for calls', (tester) async {
    final signaling = await _pump(tester);

    expect(find.text('ride screen'), findsOneWidget);
    expect(signaling.connectCalls, 1);
  });

  testWidgets('an incoming call opens the call page', (tester) async {
    final signaling = await _pump(tester);

    signaling.receive({'type': 'invite', 'from': 'driver'});
    await tester.pumpAndSettle();

    expect(find.text('call page'), findsOneWidget);
  });

  testWidgets('a second invite does not open a second call page',
      (tester) async {
    final signaling = await _pump(tester);

    signaling.receive({'type': 'invite', 'from': 'driver'});
    await tester.pumpAndSettle();
    signaling.receive({'type': 'invite', 'from': 'driver'});
    await tester.pumpAndSettle();

    expect(find.text('call page'), findsOneWidget);
    expect(signaling.sentTypes, ['decline']); // the second one was turned away
  });

  testWidgets('leaving the ride screen closes the call socket', (tester) async {
    final signaling = await _pump(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(signaling.closeCalls, 1);
  });
}
