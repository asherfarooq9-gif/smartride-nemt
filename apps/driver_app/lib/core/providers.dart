import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

final dioProvider = Provider<Dio>((ref) => createDio());

// ── Auth ──────────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(dioProvider));
});

class AuthState {
  final String? token;
  final String? userId;
  final bool loading;
  final String? error;

  const AuthState({this.token, this.userId, this.loading = false, this.error});

  bool get isLoggedIn => token != null;

  AuthState copyWith({String? token, String? userId, bool? loading, String? error}) {
    return AuthState(token: token ?? this.token, userId: userId ?? this.userId, loading: loading ?? this.loading, error: error);
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;

  AuthNotifier(this._dio) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final token = await loadToken();
    if (token != null) state = state.copyWith(token: token);
  }

  Future<bool> login(String phone, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.post('/api/v1/auth/login', data: {'phone': phone, 'password': password});
      if (res.data['role'] != 'driver') {
        state = state.copyWith(loading: false, error: 'Not a driver account');
        return false;
      }
      final token = res.data['access_token'] as String;
      final userId = res.data['user_id'] as String;
      await saveToken(token);
      state = state.copyWith(token: token, userId: userId, loading: false);
      return true;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Login failed';
      state = state.copyWith(loading: false, error: msg.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await clearToken();
    state = const AuthState();
  }
}

// ── Driver Profile ────────────────────────────────────────────────────────────

final driverProfileProvider = StateNotifierProvider<DriverProfileNotifier, DriverProfileState>((ref) {
  return DriverProfileNotifier(ref.read(dioProvider));
});

class DriverProfileState {
  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;

  const DriverProfileState({this.data, this.loading = false, this.error});

  DriverProfileState copyWith({Map<String, dynamic>? data, bool? loading, String? error}) {
    return DriverProfileState(data: data ?? this.data, loading: loading ?? this.loading, error: error);
  }
}

class DriverProfileNotifier extends StateNotifier<DriverProfileState> {
  final Dio _dio;

  DriverProfileNotifier(this._dio) : super(const DriverProfileState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.get('/api/v1/drivers/me');
      state = state.copyWith(data: res.data as Map<String, dynamic>, loading: false);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Failed';
      state = state.copyWith(loading: false, error: msg.toString());
    }
  }

  Future<bool> update(Map<String, dynamic> body) async {
    try {
      final res = await _dio.patch('/api/v1/drivers/me', data: body);
      state = state.copyWith(data: res.data as Map<String, dynamic>);
      return true;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Update failed';
      state = state.copyWith(error: msg.toString());
      return false;
    }
  }
}

// ── Ride History ──────────────────────────────────────────────────────────────

final rideHistoryProvider = StateNotifierProvider<RideHistoryNotifier, RideHistoryState>((ref) {
  return RideHistoryNotifier(ref.read(dioProvider));
});

class RideHistoryState {
  final List<Map<String, dynamic>> rides;
  final bool loading;
  final String? error;

  const RideHistoryState({this.rides = const [], this.loading = false, this.error});

  RideHistoryState copyWith({List<Map<String, dynamic>>? rides, bool? loading, String? error}) {
    return RideHistoryState(rides: rides ?? this.rides, loading: loading ?? this.loading, error: error);
  }

  double get totalEarnings => rides
      .where((r) => r['final_fare_pkr'] != null)
      .fold(0.0, (sum, r) => sum + (r['final_fare_pkr'] as num).toDouble());

  int get completedCount => rides.where((r) => r['status'] == 'completed').length;
  int get emergencyCount => rides.where((r) => r['ride_type'] == 'emergency').length;
}

class RideHistoryNotifier extends StateNotifier<RideHistoryState> {
  final Dio _dio;

  RideHistoryNotifier(this._dio) : super(const RideHistoryState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.get('/api/v1/rides/mine?page_size=100');
      final items = (res.data['items'] as List).cast<Map<String, dynamic>>();
      state = state.copyWith(rides: items, loading: false);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Failed';
      state = state.copyWith(loading: false, error: msg.toString());
    }
  }
}

// ── Driver status ─────────────────────────────────────────────────────────────

final driverStatusProvider = StateNotifierProvider<DriverStatusNotifier, DriverStatus>((ref) {
  return DriverStatusNotifier(ref.read(dioProvider));
});

enum DriverStatus { offline, available, onRide }

class DriverStatusNotifier extends StateNotifier<DriverStatus> {
  final Dio _dio;

  DriverStatusNotifier(this._dio) : super(DriverStatus.offline);

  Future<void> setAvailable(bool available) async {
    final newStatus = available ? 'available' : 'offline';
    try {
      await _dio.patch('/api/v1/drivers/status', data: {'status': newStatus});
      state = available ? DriverStatus.available : DriverStatus.offline;
    } catch (_) {}
  }
}

// ── Active ride ───────────────────────────────────────────────────────────────

final activeRideProvider = StateNotifierProvider<ActiveRideNotifier, Map<String, dynamic>?>((ref) {
  return ActiveRideNotifier(ref.read(dioProvider));
});

class ActiveRideNotifier extends StateNotifier<Map<String, dynamic>?> {
  final Dio _dio;
  Timer? _pollTimer;

  ActiveRideNotifier(this._dio) : super(null) {
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final res = await _dio.get('/api/v1/rides/mine');
      final items = (res.data['items'] as List).cast<Map<String, dynamic>>();
      final active = items.where((r) {
        final s = r['status'] as String;
        return s == 'driver_assigned' || s == 'driver_en_route' || s == 'patient_picked_up' || s == 'arrived_at_hospital';
      }).toList();
      state = active.isNotEmpty ? active.first : null;
    } catch (_) {}
  }

  Future<void> updateStatus(String rideId, String newStatus) async {
    try {
      final res = await _dio.patch('/api/v1/rides/$rideId/status', data: {'status': newStatus});
      state = res.data as Map<String, dynamic>;
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ── GPS streaming via WebSocket ───────────────────────────────────────────────

final gpsStreamProvider = StateNotifierProvider<GpsStreamNotifier, bool>((ref) {
  return GpsStreamNotifier(ref.read(dioProvider));
});

class GpsStreamNotifier extends StateNotifier<bool> {
  final Dio _dio;
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _gpsSub;

  GpsStreamNotifier(this._dio) : super(false);

  static const _wsBase = String.fromEnvironment('WS_URL', defaultValue: 'ws://10.0.2.2:8000');

  Future<void> startStreaming(String rideId, String token) async {
    if (state) return;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return;

    _channel = WebSocketChannel.connect(Uri.parse('$_wsBase/ws/driver/$rideId?token=$token'));

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      _channel?.sink.add('{"lat":${pos.latitude},"lng":${pos.longitude}}');
      _dio.post('/api/v1/drivers/location', data: {'lat': pos.latitude, 'lng': pos.longitude})
          .catchError((_) => Response(requestOptions: RequestOptions()));
    });

    state = true;
  }

  Future<void> stopStreaming() async {
    await _gpsSub?.cancel();
    await _channel?.sink.close();
    _gpsSub = null;
    _channel = null;
    state = false;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
