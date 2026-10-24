import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _token = StateProvider<String?>((ref) => 'alice-token');

/// Serves a different ride list per signed-in account, and counts fetches.
class _PerAccountRides extends RidesNotifier {
  static int fetches = 0;

  @override
  Future<core.RideListResponse> fetchRides() async {
    fetches++;
    final account = ref.read(_token) ?? 'nobody';
    return core.RideListResponse(
      items: [
        core.RideResponse.fromJson({
          'id': account,
          'patient_id': account,
          'ride_type': 'emergency',
          'status': 'pending',
          'pickup_lat': 33.7,
          'pickup_lng': 73.0,
          'requested_at': '2026-10-19T10:00:00Z',
        }),
      ],
      total: 1,
      page: 1,
      pageSize: 10,
    );
  }
}

ProviderContainer _container() => ProviderContainer(overrides: [
      sessionTokenProvider.overrideWith((ref) => ref.watch(_token)),
      ridesProvider.overrideWith(_PerAccountRides.new),
    ]);

void main() {
  setUp(() => _PerAccountRides.fetches = 0);

  test('a new session never sees the previous account\'s rides', () async {
    final c = _container();
    addTearDown(c.dispose);

    final first = await c.read(ridesProvider.future);
    expect(first.items.single.id, 'alice-token');

    c.read(_token.notifier).state = null; // sign out
    c.read(_token.notifier).state = 'bob-token'; // someone else signs in

    final second = await c.read(ridesProvider.future);
    expect(second.items.single.id, 'bob-token');
    expect(_PerAccountRides.fetches, 2);
  });
}
