import 'dart:async';
import 'dart:convert';
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
      core.TokenRefreshScheduler.instance.start();
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
    core.TokenRefreshScheduler.instance.start();
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
    final res = await core.switchRole(role);
    await _persist(res);
  }

  /// "Become a driver/patient" — add a role, then switch into it.
  Future<void> addRole(core.AddRoleRequest req) async {
    final res = await core.addRole(req);
    await _persist(res);
    await switchActiveRole(req.role);
  }

  Future<void> signOut() async {
    core.TokenRefreshScheduler.instance.stop();
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

// ── Saved Places ──────────────────────────────────────────────────────────────

const _kSavedPlacesKey = 'saved_places_v1';

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.iconType,
  });

  final String id;
  final String label;
  final String address;
  final String iconType; // home | work | hospital | place

  IconData get icon => switch (iconType) {
        'home' => Icons.home_outlined,
        'work' => Icons.work_outline,
        'hospital' => Icons.local_hospital_outlined,
        _ => Icons.place_outlined,
      };

  Map<String, String> toMap() =>
      {'id': id, 'label': label, 'address': address, 'iconType': iconType};

  factory SavedPlace.fromMap(Map<String, dynamic> m) => SavedPlace(
        id: m['id'] as String,
        label: m['label'] as String,
        address: m['address'] as String,
        iconType: m['iconType'] as String,
      );
}

final _defaultPlaces = [
  const SavedPlace(id: 'default_home', label: 'Home', address: 'H-13, Street 4, Islamabad', iconType: 'home'),
  const SavedPlace(id: 'default_work', label: 'Work', address: 'Blue Area, Jinnah Avenue, Islamabad', iconType: 'work'),
  const SavedPlace(id: 'default_hospital', label: 'Favourite Hospital', address: 'Pakistan Institute of Medical Sciences, G-8, Islamabad', iconType: 'hospital'),
];

final savedPlacesProvider =
    StateNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>(
  (ref) => SavedPlacesNotifier(),
);

class SavedPlacesNotifier extends StateNotifier<List<SavedPlace>> {
  SavedPlacesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final raw =
        await core.SecureStorage.instance.readValue(_kSavedPlacesKey);
    if (raw == null || raw.isEmpty) {
      state = List.from(_defaultPlaces);
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((m) => SavedPlace.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = List.from(_defaultPlaces);
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(state.map((p) => p.toMap()).toList());
    await core.SecureStorage.instance.saveValue(_kSavedPlacesKey, encoded);
  }

  Future<void> add(SavedPlace place) async {
    state = [...state, place];
    await _persist();
  }

  Future<void> update(SavedPlace place) async {
    state = [for (final p in state) p.id == place.id ? place : p];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }
}

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

final notificationsProvider = StateNotifierProvider.family<
    NotificationsNotifier, List<AppNotification>, String>(
  (ref, portal) => NotificationsNotifier(portal),
);

/// Maps the raw FCM message stream into displayable [AppNotification]s.
/// Kept separate so the notifier can be driven by a fake stream in tests.
Stream<AppNotification> mapIncomingNotifications() =>
    incomingMessageStream.where((m) => m.notification != null).map((m) {
      final n = m.notification!;
      return AppNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        title: n.title ?? 'Notification',
        body: n.body ?? '',
        time: 'Just now',
        icon: Icons.notifications_active_outlined,
      );
    });

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  // Starts empty — real notifications arrive via the injected stream
  // (FCM in production, a fake stream under test).
  NotificationsNotifier(String portal, {Stream<AppNotification>? incoming})
      : super(const []) {
    _sub = (incoming ?? mapIncomingNotifications()).listen((item) {
      state = [item, ...state];
    });
  }

  StreamSubscription<AppNotification>? _sub;

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

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final token = await core.SecureStorage.instance.readToken();
    if (token == null) return;

    final baseWs = core.ApiClient.instance.wsBaseUrl;
    final uri = Uri.parse('$baseWs/ws/driver/$rideId');

    _ws = core.WsClient(
      onMessage: (json) {
        final error = core.WsErrorMessage.tryParse(json);
        if (error != null) {
          debugPrint('GPS stream rejected a location update: ${error.error}');
        }
      },
    );
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
