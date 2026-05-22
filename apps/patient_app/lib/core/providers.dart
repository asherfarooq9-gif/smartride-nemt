import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

final dioProvider = Provider<Dio>((ref) => createDio());

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
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      loading: loading ?? this.loading,
      error: error,
    );
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

  Future<bool> register(String phone, String password, String fullName) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.post('/api/v1/auth/register', data: {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'role': 'patient',
      });
      final token = res.data['access_token'] as String;
      final userId = res.data['user_id'] as String;
      await saveToken(token);
      state = state.copyWith(token: token, userId: userId, loading: false);
      return true;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Registration failed';
      state = state.copyWith(loading: false, error: msg.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await clearToken();
    state = const AuthState();
  }
}

final ridesProvider = StateNotifierProvider<RidesNotifier, RidesState>((ref) {
  return RidesNotifier(ref.read(dioProvider));
});

class RidesState {
  final List<Map<String, dynamic>> rides;
  final bool loading;
  final String? error;
  final Map<String, dynamic>? activeRide;

  const RidesState({this.rides = const [], this.loading = false, this.error, this.activeRide});

  RidesState copyWith({List<Map<String, dynamic>>? rides, bool? loading, String? error, Map<String, dynamic>? activeRide}) {
    return RidesState(
      rides: rides ?? this.rides,
      loading: loading ?? this.loading,
      error: error,
      activeRide: activeRide ?? this.activeRide,
    );
  }
}

class RidesNotifier extends StateNotifier<RidesState> {
  final Dio _dio;

  RidesNotifier(this._dio) : super(const RidesState());

  Future<Map<String, dynamic>?> requestEmergency({
    required double lat,
    required double lng,
    String? address,
    required String symptomText,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.post('/api/v1/rides/emergency', data: {
        'pickup_lat': lat,
        'pickup_lng': lng,
        if (address != null) 'pickup_address': address,
        'symptom_text': symptomText,
      });
      final ride = res.data as Map<String, dynamic>;
      state = state.copyWith(loading: false, activeRide: ride);
      return ride;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Request failed';
      state = state.copyWith(loading: false, error: msg.toString());
      return null;
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.get('/api/v1/rides/mine');
      final items = (res.data['items'] as List).cast<Map<String, dynamic>>();
      state = state.copyWith(rides: items, loading: false);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? e.message ?? 'Failed to load rides';
      state = state.copyWith(loading: false, error: msg.toString());
    }
  }

  Future<Map<String, dynamic>?> pollRide(String rideId) async {
    try {
      final res = await _dio.get('/api/v1/rides/$rideId');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
