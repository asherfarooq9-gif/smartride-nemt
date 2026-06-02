import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyToken = 'smartride_jwt';
const _keyUserId = 'smartride_user_id';
const _keyRole = 'smartride_role';        // active role
const _keyRoles = 'smartride_roles';      // CSV of all held roles

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
    List<String> roles = const [],
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyUserId, value: userId),
      _storage.write(key: _keyRole, value: role),
      _storage.write(key: _keyRoles, value: roles.join(',')),
    ]);
  }

  /// Persist only the active role (used on portal switch).
  Future<void> saveActiveRole(String role) =>
      _storage.write(key: _keyRole, value: role);

  Future<String?> readToken() => _storage.read(key: _keyToken);
  Future<String?> readUserId() => _storage.read(key: _keyUserId);
  Future<String?> readRole() => _storage.read(key: _keyRole);

  Future<List<String>> readRoles() async {
    final raw = await _storage.read(key: _keyRoles);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyRole),
      _storage.delete(key: _keyRoles),
    ]);
  }
}
