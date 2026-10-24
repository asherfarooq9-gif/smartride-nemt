import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../diagnostics/error_reporter.dart';

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

  /// Replace only the access token (used by token refresh).
  Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  /// Persist only the active role (used on portal switch).
  Future<void> saveActiveRole(String role) =>
      _storage.write(key: _keyRole, value: role);

  /// Auth reads treat an unreadable keystore (corrupted after a backup restore
  /// or OS upgrade) as "signed out": the broken store is wiped so the user can
  /// log in again instead of the app waiting on it forever.
  Future<String?> readToken() => _readAuth(_keyToken);
  Future<String?> readUserId() => _readAuth(_keyUserId);
  Future<String?> readRole() => _readAuth(_keyRole);

  Future<List<String>> readRoles() async {
    final raw = await _readAuth(_keyRoles);
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((s) => s.isNotEmpty).toList();
  }

  Future<String?> _readAuth(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e, st) {
      ErrorReporter.report('Secure storage unreadable; signing out', e, st);
      await clear();
      return null;
    }
  }

  Future<String?> readValue(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e, st) {
      ErrorReporter.report('Secure storage value unreadable: $key', e, st);
      return null;
    }
  }

  Future<void> saveValue(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Removes only the credentials, keeping preferences and saved places.
  Future<void> clearAuth() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyToken),
        _storage.delete(key: _keyUserId),
        _storage.delete(key: _keyRole),
        _storage.delete(key: _keyRoles),
      ]);
    } on PlatformException catch (e, st) {
      ErrorReporter.report('Could not clear auth from secure storage', e, st);
    }
  }

  /// Wipes everything (explicit sign-out, or a corrupted store).
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } on PlatformException catch (e, st) {
      ErrorReporter.report('Could not wipe secure storage', e, st);
    }
  }
}
