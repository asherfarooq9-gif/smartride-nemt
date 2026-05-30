import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

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
