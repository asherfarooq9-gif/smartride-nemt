import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class AuthUser {
  final String token;
  final String role;
  const AuthUser({required this.token, required this.role});
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    // Restore session from secure storage on app start
    final token = await SecureStorage.readToken();
    if (token == null) return null;
    return AuthUser(token: token, role: 'patient');
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    try {
      // Clear any stale token before sending login request
      await SecureStorage.deleteToken();
      final data = await ApiClient.post('/api/v1/auth/login', body: {
        'phone': phone.trim(),
        'password': password,
      }) as Map<String, dynamic>;

      final token = data['access_token'] as String;
      final role = data['role'] as String? ?? 'patient';

      // Persist token in secure storage before updating state
      await SecureStorage.writeToken(token);
      state = AsyncData(AuthUser(token: token, role: role));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    } catch (e) {
      state = AsyncError(
        const ApiException('An unexpected error occurred'),
        StackTrace.current,
      );
    }
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);
