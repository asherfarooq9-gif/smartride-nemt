import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyToken = 'smartride_jwt';
const _keyUserId = 'smartride_user_id';
const _keyRole = 'smartride_role';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveAuth({
    required String token,
    required String userId,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyRole, value: role),
    ]);
  }

  Future<String?> readToken() => _storage.read(key: _keyToken);
  Future<String?> readUserId() => _storage.read(key: _keyUserId);
  Future<String?> readRole() => _storage.read(key: _keyRole);

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyRole),
    ]);
  }
}
