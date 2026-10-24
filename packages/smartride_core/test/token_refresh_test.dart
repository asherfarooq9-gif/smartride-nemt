import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

String _jwtExpiringIn(Duration d) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(d).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
}

/// Fake API: records calls, refresh hands out [refreshedToken] (or [refreshStatus]).
class _FakeApi implements HttpClientAdapter {
  _FakeApi({this.refreshStatus = 200});
  final int refreshStatus;
  static const refreshedToken = 'refreshed-token';
  final seenAuth = <String?>[];
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _json(
        refreshStatus == 200
            ? {'access_token': refreshedToken}
            : {'detail': 'Invalid or expired token'},
        refreshStatus,
      );
    }
    final auth = options.headers['Authorization'] as String?;
    seenAuth.add(auth);
    final stale = auth != null &&
        auth != 'Bearer $refreshedToken' &&
        refreshStatus != 200;
    return _json({'ok': true}, stale ? 401 : 200);
  }

  ResponseBody _json(Map<String, Object> body, int status) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

Dio _client(_FakeApi api) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = api;
  dio.interceptors.add(AuthInterceptor(
    refreshClient: (baseUrl) =>
        Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = api,
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ApiClient.onUnauthorized = null);

  test('jwtExpiry reads the exp claim and tolerates garbage', () {
    final inTenMinutes = DateTime.now().add(const Duration(minutes: 10));
    final parsed = jwtExpiry(_jwtExpiringIn(const Duration(minutes: 10)))!;
    expect(parsed.difference(inTenMinutes).inSeconds.abs(), lessThan(2));
    expect(jwtExpiry('not-a-jwt'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
  });

  test('a token about to expire is refreshed before the request is sent',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'smartride_jwt': _jwtExpiringIn(const Duration(minutes: 2))});
    final api = _FakeApi();

    await _client(api).get<dynamic>('/rides/mine');

    expect(api.refreshCalls, 1);
    expect(api.seenAuth.single, 'Bearer ${_FakeApi.refreshedToken}');
    expect(await SecureStorage.instance.readToken(), _FakeApi.refreshedToken);
  });

  test('a token with plenty of life left is used as is', () async {
    final fresh = _jwtExpiringIn(const Duration(minutes: 45));
    FlutterSecureStorage.setMockInitialValues({'smartride_jwt': fresh});
    final api = _FakeApi();

    await _client(api).get<dynamic>('/rides/mine');

    expect(api.refreshCalls, 0);
    expect(api.seenAuth.single, 'Bearer $fresh');
  });

  test('concurrent requests share one refresh', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'smartride_jwt': _jwtExpiringIn(const Duration(minutes: 1))});
    final api = _FakeApi();
    final dio = _client(api);

    await Future.wait([
      dio.get<dynamic>('/rides/mine'),
      dio.get<dynamic>('/drivers/me'),
      dio.get<dynamic>('/drivers/wallet'),
    ]);

    expect(api.refreshCalls, 1);
    expect(api.seenAuth.toSet(), {'Bearer ${_FakeApi.refreshedToken}'});
  });

  test(
      'when refresh is refused the request still goes out and ends the session',
      () async {
    final old = _jwtExpiringIn(const Duration(minutes: 1));
    FlutterSecureStorage.setMockInitialValues({'smartride_jwt': old});
    final api = _FakeApi(refreshStatus: 401);
    var sessionEnded = 0;
    ApiClient.onUnauthorized = () => sessionEnded++;

    await expectLater(
      _client(api).get<dynamic>('/rides/mine'),
      throwsA(isA<DioException>()),
    );

    expect(api.seenAuth.single, 'Bearer $old');
    expect(sessionEnded, 1);
  });

  test('requests made without a token never trigger a refresh', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = _FakeApi();

    await _client(api).post<dynamic>('/api/v1/auth/login');

    expect(api.refreshCalls, 0);
    expect(api.seenAuth.single, isNull);
  });
}
