import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// ── Auth ──────────────────────────────────────────────────────────────────────

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<String?>>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final token = await core.SecureStorage.instance.readToken();
    state = AsyncValue.data(token);
  }

  Future<void> signIn(String phone, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await core.login(phone, password);
      if (res.role != 'driver') {
        await core.SecureStorage.instance.clear();
        state = AsyncValue.error(
          const core.AppError('This account is not a driver account.'),
          StackTrace.current,
        );
        return;
      }
      await core.SecureStorage.instance.saveAuth(
        token: res.accessToken,
        userId: res.userId,
        role: res.role,
      );
      state = AsyncValue.data(res.accessToken);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await core.logout();
    } catch (_) {}
    await core.SecureStorage.instance.clear();
    state = const AsyncValue.data(null);
  }
}

// ── GPS Stream ────────────────────────────────────────────────────────────────

final gpsStreamProvider =
    StateNotifierProvider<GpsStreamNotifier, bool>(
  (ref) => GpsStreamNotifier(ref),
);

class GpsStreamNotifier extends StateNotifier<bool> {
  GpsStreamNotifier(Ref ref) : super(false);
  StreamSubscription<Position>? _posSub;
  core.WsClient? _ws;

  Future<void> startStreaming(String rideId) async {
    if (state) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final token = await core.SecureStorage.instance.readToken();
    if (token == null) return;

    final baseWs = core.ApiClient.instance.wsBaseUrl;
    final uri = Uri.parse('$baseWs/ws/driver/$rideId');

    _ws = core.WsClient(onMessage: (_) {});
    await _ws!.connect(uri, token);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    DateTime? lastRest;

    _posSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((pos) {
      _ws?.send({'lat': pos.latitude, 'lng': pos.longitude});

      final now = DateTime.now();
      if (lastRest == null ||
          now.difference(lastRest!) >= const Duration(seconds: 5)) {
        lastRest = now;
        core.updateDriverLocation(pos.latitude, pos.longitude)
            .catchError((_) {});
      }
    });

    state = true;
  }

  Future<void> stopStreaming() async {
    await _posSub?.cancel();
    await _ws?.disconnect();
    _posSub = null;
    _ws = null;
    state = false;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ws?.disconnect();
    super.dispose();
  }
}
