import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// ---------------------------------------------------------------------------
// Fake notifier that accepts a configurable fetch function
// ---------------------------------------------------------------------------

class _FakeRidesNotifier extends RidesNotifier {
  _FakeRidesNotifier(this._fetch);
  final Future<core.RideListResponse> Function() _fetch;

  @override
  Future<core.RideListResponse> build() => _fetch();

  @override
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

core.RideListResponse _makeList(List<core.RideResponse> items) =>
    core.RideListResponse(
      items: items,
      total: items.length,
      page: 1,
      pageSize: 10,
    );

core.RideResponse _makeRide({
  String id = '1',
  core.RideStatus status = core.RideStatus.pending,
  core.RideType rideType = core.RideType.scheduled,
  String pickupAddress = 'Test Address',
}) =>
    core.RideResponse(
      id: id,
      status: status,
      rideType: rideType,
      pickupAddress: pickupAddress,
    );

ProviderContainer _makeContainer({
  required Future<core.RideListResponse> Function() fetch,
}) =>
    ProviderContainer(
      overrides: [ridesProvider.overrideWith(() => _FakeRidesNotifier(fetch))],
    );

void main() {
  group('RidesNotifier', () {
    test('starts in loading then transitions to data', () async {
      final container = _makeContainer(
        fetch: () async => _makeList([_makeRide()]),
      );
      addTearDown(container.dispose);

      // Initially loading
      expect(container.read(ridesProvider), const AsyncValue<core.RideListResponse>.loading());

      final result = await container.read(ridesProvider.future);
      expect(result.items, hasLength(1));
      expect(result.items.first.id, '1');
    });

    test('transitions to error when fetch throws', () async {
      final container = _makeContainer(
        fetch: () async => throw Exception('server down'),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(ridesProvider.future),
        throwsA(isA<Exception>()),
      );

      final state = container.read(ridesProvider);
      expect(state.hasError, isTrue);
    });

    test('refresh resets to loading then re-fetches', () async {
      var callCount = 0;
      final container = _makeContainer(
        fetch: () async {
          callCount++;
          return _makeList([_makeRide(id: callCount.toString())]);
        },
      );
      addTearDown(container.dispose);

      await container.read(ridesProvider.future); // initial load
      expect(callCount, 1);

      await container.read(ridesProvider.notifier).refresh();
      expect(callCount, 2);

      final state = container.read(ridesProvider);
      expect(state.value?.items.first.id, '2');
    });

    test('refresh transitions through loading state', () async {
      final container = _makeContainer(
        fetch: () async => _makeList([_makeRide()]),
      );
      addTearDown(container.dispose);

      await container.read(ridesProvider.future);

      // Start refresh without awaiting — capture loading state
      final refreshFuture = container.read(ridesProvider.notifier).refresh();
      expect(container.read(ridesProvider).isLoading, isTrue);

      await refreshFuture;
      expect(container.read(ridesProvider).hasValue, isTrue);
    });
  });

  group('activeRideProvider', () {
    test('returns null when all rides are completed or cancelled', () async {
      final container = _makeContainer(
        fetch: () async => _makeList([
          _makeRide(status: core.RideStatus.completed),
          _makeRide(id: '2', status: core.RideStatus.cancelled),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(ridesProvider.future);
      expect(container.read(activeRideProvider), isNull);
    });

    test('returns the first active ride', () async {
      final container = _makeContainer(
        fetch: () async => _makeList([
          _makeRide(id: '1', status: core.RideStatus.completed),
          _makeRide(id: '2', status: core.RideStatus.pending),
          _makeRide(id: '3', status: core.RideStatus.driverEnRoute),
        ]),
      );
      addTearDown(container.dispose);

      await container.read(ridesProvider.future);
      final active = container.read(activeRideProvider);
      expect(active?.id, '2');
    });

    test('returns null while rides are still loading', () {
      final completer = Completer<core.RideListResponse>();
      final container = _makeContainer(fetch: () => completer.future);
      addTearDown(container.dispose);

      expect(container.read(activeRideProvider), isNull);
    });
  });
}
