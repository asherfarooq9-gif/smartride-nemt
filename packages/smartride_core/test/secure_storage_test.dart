import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a keystore failure reads as signed out and wipes the broken store',
      () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      if (call.method == 'read') {
        throw PlatformException(code: 'keystore', message: 'BadPadding');
      }
      return null;
    });

    expect(await SecureStorage.instance.readToken(), isNull);
    expect(await SecureStorage.instance.readRoles(), isEmpty);
    expect(calls, contains('deleteAll'));
  });

  test('clearAuth removes credentials but keeps preferences', () async {
    final store = <String, String>{
      'smartride_jwt': 't',
      'smartride_user_id': 'u',
      'smartride_role': 'patient',
      'smartride_roles': 'patient',
      'app_theme_mode': 'dark',
      'saved_places_v1': '[]',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      if (call.method == 'delete') store.remove(args['key']);
      return null;
    });

    await SecureStorage.instance.clearAuth();

    expect(store.keys, unorderedEquals(['app_theme_mode', 'saved_places_v1']));
  });
}
