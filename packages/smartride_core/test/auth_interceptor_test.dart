import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

/// Answers every request with the given status code.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({'detail': 'Invalid or expired token'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(int status) => Dio(BaseOptions(baseUrl: 'http://test'))
  ..httpClientAdapter = _StatusAdapter(status)
  ..interceptors.add(AuthInterceptor());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'smartride_jwt': 'old-token',
      'smartride_role': 'patient',
    });
  });

  tearDown(() => ApiClient.onUnauthorized = null);

  test('401 on an authenticated request ends the session', () async {
    var sessionEnded = 0;
    ApiClient.onUnauthorized = () => sessionEnded++;

    await expectLater(
      _dioReturning(401).get<dynamic>('/rides/mine'),
      throwsA(isA<DioException>()),
    );

    expect(sessionEnded, 1);
    expect(await SecureStorage.instance.readToken(), isNull);
  });

  test('401 on a request without a token (failed login) does not end a session',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    var sessionEnded = 0;
    ApiClient.onUnauthorized = () => sessionEnded++;

    await expectLater(
      _dioReturning(401).post<dynamic>('/auth/login'),
      throwsA(isA<DioException>()),
    );

    expect(sessionEnded, 0);
  });

  test('other errors keep the session', () async {
    var sessionEnded = 0;
    ApiClient.onUnauthorized = () => sessionEnded++;

    await expectLater(
      _dioReturning(500).get<dynamic>('/rides/mine'),
      throwsA(isA<DioException>()),
    );

    expect(sessionEnded, 0);
    expect(await SecureStorage.instance.readToken(), 'old-token');
  });

  test('requests carry the stored bearer token', () async {
    final dio = _dioReturning(200);
    await dio.get<dynamic>('/health');
    final adapter = dio.httpClientAdapter as _StatusAdapter;
    expect(adapter.lastRequest!.headers['Authorization'], 'Bearer old-token');
  });
}
