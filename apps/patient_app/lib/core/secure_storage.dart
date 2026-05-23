import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single access point for JWT token persistence.
/// All other files must use this class — never import flutter_secure_storage directly.
class SecureStorage {
  // Encrypted storage per platform; web uses localStorage via WebOptions
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    webOptions: WebOptions(dbName: 'smartride_patient', publicKey: 'smartride'),
  );

  static const _tokenKey = 'auth_token';

  static Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() =>
      _storage.read(key: _tokenKey);

  static Future<void> deleteToken() =>
      _storage.delete(key: _tokenKey);
}
