import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideListResponse _list(String id) => core.RideListResponse(
      items: [
        core.RideResponse(
          id: id,
          status: core.RideStatus.pending,
          rideType: core.RideType.emergency,
          pickupAddress: 'Here',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 10,
    );

/// Uses the real [RidesNotifier.refresh]; only the network call is scripted.
class _ScriptedRides extends RidesNotifier {
  _ScriptedRides(this.script);
  final List<Future<core.RideListResponse> Function()> script;
  int calls = 0;

  @override
  Future<core.RideListResponse> fetchRides() => script[calls++]();
}

void main() {
  late _ScriptedRides notifier;

  ProviderContainer container(
    List<Future<core.RideListResponse> Function()> script,
  ) {
    notifier = _ScriptedRides(script);
    final c = ProviderContainer(overrides: [
      sessionTokenProvider.overrideWith((_) => 'tok'),
      ridesProvider.overrideWith(() => notifier),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('refresh keeps showing the old rides while the new ones load', () async {
    final slow = Completer<core.RideListResponse>();
    final c = container([
      () async => _list('old'),
      () => slow.future,
    ]);
    await c.read(ridesProvider.future);

    final refreshing = notifier.refresh();
    final during = c.read(ridesProvider);
    expect(during.isLoading, isTrue);
    expect(during.valueOrNull?.items.single.id, 'old');

    slow.complete(_list('new'));
    await refreshing;
    expect(c.read(ridesProvider).valueOrNull?.items.single.id, 'new');
  });

  test('a failed refresh keeps the previous rides', () async {
    final c = container([
      () async => _list('old'),
      () async => throw const core.AppError('offline'),
    ]);
    await c.read(ridesProvider.future);

    await notifier.refresh();

    final after = c.read(ridesProvider);
    expect(after.hasError, isTrue);
    expect(after.valueOrNull?.items.single.id, 'old');
  });
}
