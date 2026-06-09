import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/notifications.dart';

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

// ── Theme mode ─────────────────────────────────────────────────────────────────

const _kThemeModeKey = 'app_theme_mode';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final val =
        await core.SecureStorage.instance.readValue(_kThemeModeKey);
    if (val == 'dark') state = ThemeMode.dark;
    if (val == 'light') state = ThemeMode.light;
  }

  Future<void> setDark(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    await core.SecureStorage.instance
        .saveValue(_kThemeModeKey, isDark ? 'dark' : 'light');
  }
}

// ── City (driver portal) ───────────────────────────────────────────────────────

final cityProvider = StateProvider<String>((ref) => 'Islamabad');

// ── Notifications ──────────────────────────────────────────────────────────────

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool isRead;

  AppNotification withRead() => AppNotification(
        id: id, title: title, body: body,
        time: time, icon: icon, isRead: true);
}

const _patientSeed = [
  AppNotification(id: 'p1', title: 'Ride Confirmed', body: 'Your ride to Pakistan Institute of Medical Sciences has been confirmed.', time: '2 min ago', icon: Icons.check_circle_outline),
  AppNotification(id: 'p2', title: 'Driver On The Way', body: 'Ahmed Khan is heading to your pickup location. ETA 8 minutes.', time: '10 min ago', icon: Icons.directions_car_outlined),
  AppNotification(id: 'p3', title: 'Payment Received', body: 'PKR 350 payment processed successfully for your last ride.', time: '1 hr ago', icon: Icons.payment_outlined, isRead: true),
  AppNotification(id: 'p4', title: 'Ride Completed', body: 'Your ride has been completed. Thank you for using SmartRide.', time: '3 hr ago', icon: Icons.flag_outlined, isRead: true),
  AppNotification(id: 'p5', title: 'Rate Your Driver', body: 'How was your experience with Muhammad Ali? Tap to leave a review.', time: 'Yesterday', icon: Icons.star_outline, isRead: true),
];

const _driverSeed = [
  AppNotification(id: 'd1', title: 'New Ride Request', body: 'Patient pickup at G-10 Markaz. 3.2 km away. Tap to accept.', time: '1 min ago', icon: Icons.notifications_active_outlined),
  AppNotification(id: 'd2', title: 'Earnings Credited', body: 'PKR 420 has been credited to your wallet for 3 completed rides.', time: '30 min ago', icon: Icons.account_balance_wallet_outlined),
  AppNotification(id: 'd3', title: 'Commission Deducted', body: 'PKR 45 platform commission deducted for ride #SR-4821.', time: '2 hr ago', icon: Icons.receipt_long_outlined, isRead: true),
  AppNotification(id: 'd4', title: 'Verification Approved', body: 'Your driver profile has been verified. You can now go online.', time: 'Yesterday', icon: Icons.verified_outlined, isRead: true),
];

final notificationsProvider = StateNotifierProvider.family<
    NotificationsNotifier, List<AppNotification>, String>(
  (ref, portal) => NotificationsNotifier(portal),
);

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(String portal)
      : super(portal == 'driver'
            ? List<AppNotification>.from(_driverSeed)
            : List<AppNotification>.from(_patientSeed)) {
    _sub = incomingMessageStream.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      final item = AppNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        title: n.title ?? 'Notification',
        body: n.body ?? '',
        time: 'Just now',
        icon: Icons.notifications_active_outlined,
      );
      state = [item, ...state];
    });
  }

  StreamSubscription<dynamic>? _sub;

  void markRead(String id) {
    state = [for (final n in state) n.id == id ? n.withRead() : n];
  }

  void markAllRead() {
    state = [for (final n in state) n.withRead()];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
