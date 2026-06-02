import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// ── Role state (drives which portal is shown) ──────────────────────────────────

/// All roles the logged-in account holds (e.g. ['patient','driver']).
final rolesProvider = StateProvider<List<String>>((ref) => const []);

/// The currently active portal: 'patient' or 'driver'.
final activeRoleProvider = StateProvider<String>((ref) => 'patient');

// ── Auth ───────────────────────────────────────────────────────────────────────

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<String?>>(
  (ref) => AuthNotifier(ref),
);

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final token = await core.SecureStorage.instance.readToken();
    if (token != null) {
      final roles = await core.SecureStorage.instance.readRoles();
      final active = await core.SecureStorage.instance.readRole();
      if (roles.isNotEmpty) _ref.read(rolesProvider.notifier).state = roles;
      if (active != null && active.isNotEmpty) {
        _ref.read(activeRoleProvider.notifier).state = active;
      }
    }
    state = AsyncValue.data(token);
  }

  Future<void> _persist(core.TokenResponse res) async {
    await core.SecureStorage.instance.saveAuth(
      token: res.accessToken,
      userId: res.userId,
      role: res.activeRole,
      roles: res.roles,
    );
    _ref.read(rolesProvider.notifier).state = res.roles;
    _ref.read(activeRoleProvider.notifier).state = res.activeRole;
  }

  Future<void> signIn(String phone, String password, {String? activeRole}) async {
    state = const AsyncValue.loading();
    try {
      final res = await core.login(phone, password, activeRole: activeRole);
      await _persist(res);
      state = AsyncValue.data(res.accessToken);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> registerAccount(core.RegisterRequest req) async {
    state = const AsyncValue.loading();
    try {
      final res = await core.register(req);
      await _persist(res);
      state = AsyncValue.data(res.accessToken);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Flip the active portal. Account must already hold the target role.
  Future<void> switchActiveRole(String role) async {
    try {
      final res = await core.switchRole(role);
      await _persist(res);
    } catch (_) {
      // optimistic local fallback so the UI still flips
      await core.SecureStorage.instance.saveActiveRole(role);
      _ref.read(activeRoleProvider.notifier).state = role;
    }
  }

  /// "Become a driver/patient" — add a role, then switch into it.
  Future<void> addRole(core.AddRoleRequest req) async {
    final res = await core.addRole(req);
    await _persist(res);
    await switchActiveRole(req.role);
  }

  Future<void> signOut() async {
    try {
      await core.logout();
    } catch (_) {}
    await core.SecureStorage.instance.clear();
    _ref.read(rolesProvider.notifier).state = const [];
    _ref.read(activeRoleProvider.notifier).state = 'patient';
    state = const AsyncValue.data(null);
  }
}

// ── GPS Stream (driver portal) ──────────────────────────────────────────────────

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
