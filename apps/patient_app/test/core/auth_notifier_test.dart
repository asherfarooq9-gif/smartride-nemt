import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Future<AsyncValue<String?>> _settled(ProviderContainer c) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (c.read(authProvider) is AsyncLoading) {
    if (DateTime.now().isAfter(deadline)) fail('auth stayed loading');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return c.read(authProvider);
}

class _Always401 implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({'detail': 'Invalid or expired token'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Throws what the web plugin throws when it cannot decrypt a saved value.
class _UndecryptablePlatform extends FlutterSecureStoragePlatform {
  bool wasWiped = false;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      throw 'OperationError'; // not an Exception, like a JS DOMException

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      wasWiped = true;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      true;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a keystore failure at startup means signed out, not loading forever',
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final auth = await _settled(container);

    expect(auth.hasError, isFalse);
    expect(auth.valueOrNull, isNull);
    expect(calls, contains('deleteAll'), reason: 'broken store is wiped');
  });

  test(
      'a saved session the browser cannot decrypt means signed out, '
      'not a login button that spins forever', () async {
    // On web a failed WebCrypto decrypt rejects with a bare JS DOMException
    // (OperationError). It is neither a PlatformException nor a Dart
    // Exception, so it used to escape and leave auth loading for good.
    final platform = _UndecryptablePlatform();
    FlutterSecureStoragePlatform.instance = platform;
    addTearDown(() => FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage());
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final auth = await _settled(container);

    expect(auth.hasError, isFalse);
    expect(auth.valueOrNull, isNull);
    expect(platform.wasWiped, isTrue, reason: 'broken store is wiped');
  });

  test('a stored session is restored with its roles', () async {
    FlutterSecureStorage.setMockInitialValues({
      'smartride_jwt': 'tok',
      'smartride_role': 'driver',
      'smartride_roles': 'patient,driver',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final auth = await _settled(container);

    expect(auth.valueOrNull, 'tok');
    expect(container.read(rolesProvider), ['patient', 'driver']);
    expect(container.read(activeRoleProvider), 'driver');
  });

  test('a 401 ends the session and clears credentials but not preferences',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'smartride_jwt': 'tok',
      'smartride_roles': 'patient',
      'app_theme_mode': 'dark',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect((await _settled(container)).valueOrNull, 'tok');

    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = _Always401()
      ..interceptors.add(core.AuthInterceptor());
    await expectLater(
        dio.get<dynamic>('/rides/mine'), throwsA(isA<DioException>()));

    expect(container.read(authProvider).valueOrNull, isNull);
    expect(container.read(rolesProvider), isEmpty);
    expect(await core.SecureStorage.instance.readToken(), isNull);
    expect(
        await core.SecureStorage.instance.readValue('app_theme_mode'), 'dark');
  });
}
