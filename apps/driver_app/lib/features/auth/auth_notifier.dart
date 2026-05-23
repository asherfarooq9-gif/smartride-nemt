import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

class AuthDriver {
  final String token;
  const AuthDriver({required this.token});
}

class AuthNotifier extends AsyncNotifier<AuthDriver?> {
  @override
  Future<AuthDriver?> build() async {
    final token = await SecureStorage.readToken();
    if (token == null) return null;
    return AuthDriver(token: token);
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    try {
      // Clear stale token before login request
      await SecureStorage.deleteToken();
      final data = await ApiClient.post('/api/v1/auth/login', body: {
        'phone': phone.trim(),
        'password': password,
      }) as Map<String, dynamic>;

      final role = data['role'] as String? ?? '';
      if (role != 'driver') {
        throw const ApiException('This account is not a driver account');
      }

      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException('Server returned invalid response');
      }

      // Persist token in secure storage before updating state
      await SecureStorage.writeToken(token);
      state = AsyncData(AuthDriver(token: token));
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
    AsyncNotifierProvider<AuthNotifier, AuthDriver?>(AuthNotifier.new);
