import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Behaves like the web plugin: the encryption key is created lazily, after an
/// async gap, by whichever write finds none. Two writes that both find none
/// each make a key, and only the last one is kept, so values encrypted with
/// the other key can no longer be decrypted (the browser's OperationError).
class _WebLikePlatform extends FlutterSecureStoragePlatform {
  int? _storedKey;
  int _nextKey = 1;
  final _cipher = <String, ({int key, String value})>{};

  Future<int> _keyForWrite() async {
    if (_storedKey != null) return _storedKey!;
    final fresh = _nextKey++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _storedKey = fresh; // last writer wins
    return fresh;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final usedKey = await _keyForWrite();
    _cipher[key] = (key: usedKey, value: value);
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final entry = _cipher[key];
    if (entry == null) return null;
    if (entry.key != _storedKey) throw 'OperationError';
    return entry.value;
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _cipher.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      _cipher.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _cipher.clear();
    _storedKey = null;
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      {for (final e in _cipher.entries) e.key: e.value.value};
}

void main() {
  tearDown(() => FlutterSecureStoragePlatform.instance =
      MethodChannelFlutterSecureStorage());

  test('the first login on a fresh browser can read back everything it saved',
      () async {
    FlutterSecureStoragePlatform.instance = _WebLikePlatform();
    final storage = core.SecureStorage.instance;

    await storage.saveAuth(
      token: 'tok',
      userId: 'u1',
      role: 'patient',
      roles: const ['patient', 'driver'],
    );

    expect(await storage.readToken(), 'tok');
    expect(await storage.readUserId(), 'u1');
    expect(await storage.readRole(), 'patient');
    expect(await storage.readRoles(), ['patient', 'driver']);
  });
}
