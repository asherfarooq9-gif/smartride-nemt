import 'dart:async';

import 'endpoints.dart';
import '../storage/secure_storage.dart';

/// Proactively refreshes the access token before its server-side expiry
/// (60 minutes). The backend's `/refresh` only accepts a still-valid token —
/// it rotates by blocklisting the old jti — so refreshing must happen ahead
/// of expiry. Reacting to a 401 is already too late and forces a logout.
class TokenRefreshScheduler {
  TokenRefreshScheduler._();
  static final TokenRefreshScheduler instance = TokenRefreshScheduler._();

  static const _refreshInterval = Duration(minutes: 50);

  Timer? _timer;

  /// Start (or restart) the periodic refresh. Call after login/register/role
  /// switch and on app start when a token is already stored.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  /// Stop refreshing. Call on logout.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh() async {
    try {
      final token = await refreshToken();
      await SecureStorage.instance.saveToken(token);
    } on Exception catch (_) {
      // Best-effort: if this fails, the existing token stays valid until its
      // original expiry, and the next tick tries again.
    }
  }
}
