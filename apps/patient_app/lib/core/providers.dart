import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/location.dart';
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

/// Token of the signed-in session, or null when signed out.
///
/// User-scoped providers (rides, dashboard, notifications, saved places, GPS)
/// watch this so they are rebuilt, and drop the previous account's data,
/// whenever the account changes.
final sessionTokenProvider =
    Provider<String?>((ref) => ref.watch(authProvider).valueOrNull);

class AuthNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    core.ApiClient.onUnauthorized = _onSessionExpired;
    _init();
  }

  final Ref _ref;

  @override
  void dispose() {
    if (core.ApiClient.onUnauthorized == _onSessionExpired) {
      core.ApiClient.onUnauthorized = null;
    }
    super.dispose();
  }

  /// An authenticated request was rejected (token expired or revoked): the
  /// interceptor already cleared storage, so end the session in the UI too and
  /// let the router send the user back to the welcome screen.
  void _onSessionExpired() {
    if (state.valueOrNull == null) return; // signed out, or mid sign-in
    _resetSession();
  }

  void _resetSession() {
    _ref.read(rolesProvider.notifier).state = const [];
    _ref.read(activeRoleProvider.notifier).state = 'patient';
    state = const AsyncValue.data(null);
  }

  Future<void> _init() async {
    final token = await _restoreSession();
    state = AsyncValue.data(token);
    if (token != null) unawaited(registerPushToken());
  }

  /// A storage failure must never leave the app on the loading screen: treat
  /// it as signed out so the user can log in again.
  Future<String?> _restoreSession() async {
    final storage = core.SecureStorage.instance;
    try {
      final token = await storage.readToken();
      if (token == null) return null;
      final roles = await storage.readRoles();
      final active = await storage.readRole();
      if (roles.isNotEmpty) _ref.read(rolesProvider.notifier).state = roles;
      if (active != null && active.isNotEmpty) {
        _ref.read(activeRoleProvider.notifier).state = active;
      }
      return token;
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Could not restore the saved session', e, st);
      await storage.clear();
      return null;
    }
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
    unawaited(registerPushToken());
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

  /// Clears local state first so sign-out is instant and works offline, then
  /// tells the server in the background (using the token read beforehand).
  Future<void> signOut() async {
    final storage = core.SecureStorage.instance;
    final token = await storage.readToken();
    await storage.clear();
    unawaited(forgetPushToken());
    _resetSession();
    if (token != null) unawaited(_logoutOnServer(token));
  }

  Future<void> _logoutOnServer(String token) async {
    try {
      await core.logout(token: token);
    } on core.AppError catch (e, st) {
      core.ErrorReporter.report('Server logout failed', e, st);
    }
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

final savedPlacesProvider =
    StateNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>((ref) {
  ref.watch(sessionTokenProvider);
  return SavedPlacesNotifier();
});

class SavedPlacesNotifier extends StateNotifier<List<SavedPlace>> {
  SavedPlacesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final raw =
        await core.SecureStorage.instance.readValue(_kSavedPlacesKey);
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((m) => SavedPlace.fromMap(m as Map<String, dynamic>))
          .toList();
    } on Object catch (e, st) {
      // Malformed JSON or a wrong shape (TypeError): leave the stored value
      // untouched, it may still be recoverable.
      core.ErrorReporter.report('Saved places are unreadable', e, st);
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
    NotificationsNotifier, List<AppNotification>, String>((ref, portal) {
  ref.watch(sessionTokenProvider);
  return NotificationsNotifier(portal);
});

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

enum GpsStreamStatus {
  /// Not sharing location.
  idle,

  /// Starting up, or connecting for the first time.
  starting,

  /// Location is reaching the server.
  live,

  /// Sharing was started but the connection or GPS signal is interrupted.
  degraded,
}

extension GpsStreamStatusX on GpsStreamStatus {
  bool get isActive => this != GpsStreamStatus.idle;
}

enum GpsStartResult { started, alreadyStreaming, permissionDenied, notSignedIn, cancelled }

final gpsStreamProvider =
    StateNotifierProvider<GpsStreamNotifier, GpsStreamStatus>((ref) {
  ref.watch(sessionTokenProvider);
  return GpsStreamNotifier();
});

class GpsStreamNotifier extends StateNotifier<GpsStreamStatus> {
  GpsStreamNotifier() : super(GpsStreamStatus.idle);

  static const _restInterval = Duration(seconds: 5);

  StreamSubscription<Position>? _posSub;
  core.WsClient? _ws;
  DateTime? _lastRest;
  bool _isRestFailing = false;

  Future<GpsStartResult> startStreaming(String rideId) async {
    if (state.isActive) return GpsStartResult.alreadyStreaming;
    state = GpsStreamStatus.starting; // before any await: blocks a second call

    if (!await _hasLocationPermission()) {
      _setIfActive(GpsStreamStatus.idle);
      return GpsStartResult.permissionDenied;
    }
    final token = await core.SecureStorage.instance.readToken();
    if (token == null) {
      _setIfActive(GpsStreamStatus.idle);
      return GpsStartResult.notSignedIn;
    }
    if (state != GpsStreamStatus.starting) return GpsStartResult.cancelled;

    final uri = Uri.parse('${core.ApiClient.instance.wsBaseUrl}/ws/driver/$rideId');
    final ws = core.WsClient(
      onMessage: (_) {},
      onConnected: () => _setIfActive(GpsStreamStatus.live),
      onDisconnected: () => _setIfActive(GpsStreamStatus.degraded),
      onError: _onSocketError,
    );
    _ws = ws;
    _posSub = Geolocator.getPositionStream(
      locationSettings: driverTrackingSettings(),
    ).listen(_onPosition, onError: _onPositionError);
    await ws.connect(uri, token);
    return GpsStartResult.started;
  }

  Future<bool> _hasLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  void _setIfActive(GpsStreamStatus next) {
    if (mounted && state.isActive) state = next;
  }

  void _onSocketError(Object error) {
    if (error is FormatException) return; // bad frame; the link itself is fine
    if (state == GpsStreamStatus.starting) _setIfActive(GpsStreamStatus.degraded);
  }

  void _onPositionError(Object error, StackTrace stack) {
    core.ErrorReporter.report('Driver position stream failed', error, stack);
    _setIfActive(GpsStreamStatus.degraded);
  }

  void _onPosition(Position pos) {
    _ws?.send({'lat': pos.latitude, 'lng': pos.longitude});

    final now = DateTime.now();
    final last = _lastRest;
    if (last != null && now.difference(last) < _restInterval) return;
    _lastRest = now;
    unawaited(_postLocation(pos));
  }

  /// REST fallback so the backend keeps a fresh location even if the socket
  /// is down. Reports only the first failure of a streak, not every 5 seconds.
  Future<void> _postLocation(Position pos) async {
    try {
      await core.updateDriverLocation(pos.latitude, pos.longitude);
      _isRestFailing = false;
    } on core.AppError catch (e, st) {
      if (!_isRestFailing) {
        core.ErrorReporter.report('Driver location update failed', e, st);
      }
      _isRestFailing = true;
    }
  }

  Future<void> stopStreaming() async {
    if (mounted) state = GpsStreamStatus.idle;
    final sub = _posSub;
    final ws = _ws;
    _posSub = null;
    _ws = null;
    _lastRest = null;
    _isRestFailing = false;
    await sub?.cancel();
    await ws?.disconnect();
  }

  @override
  void dispose() {
    unawaited(_posSub?.cancel());
    unawaited(_ws?.disconnect());
    super.dispose();
  }
}
