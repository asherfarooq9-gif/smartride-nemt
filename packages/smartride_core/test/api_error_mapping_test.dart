import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions options) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    last = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

({ApiClient client, _Adapter adapter}) _clientAnswering(
  Future<ResponseBody> Function(RequestOptions) respond,
) {
  final adapter = _Adapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return (client: ApiClient.withDio(dio), adapter: adapter);
}

Future<AppError> _errorFrom(
  Future<ResponseBody> Function(RequestOptions) respond,
) async {
  final api = _clientAnswering(respond).client;
  try {
    await api.get('/x');
  } on AppError catch (e) {
    return e;
  }
  fail('expected an AppError');
}

void main() {
  test('FastAPI 422 detail lists become one readable line', () async {
    final e = await _errorFrom((_) async => _json({
          'detail': [
            {
              'loc': ['body', 'pickup_lat'],
              'msg': 'Field required',
              'type': 'missing',
            },
            {
              'loc': ['body', 'phone'],
              'msg': 'Value error, Enter a valid phone number',
              'type': 'value_error',
            },
          ],
        }, 422));

    expect(e.statusCode, 422);
    expect(e.message,
        'Pickup lat: Field required. Phone: Enter a valid phone number');
  });

  test('string detail from a 4xx is shown as is', () async {
    final e = await _errorFrom((_) async => _json({'detail': 'No access'}, 403));
    expect(e.message, 'No access');
    expect(e.isPermanent, isTrue);
  });

  test('4xx without detail gets plain text, never a Dio dump', () async {
    final e = await _errorFrom((_) async => _json({'x': 1}, 404));
    expect(e.message, 'We could not find what you asked for.');
    expect(e.message, isNot(contains('DioException')));
  });

  test('5xx hides server detail behind a friendly message', () async {
    final e = await _errorFrom(
        (_) async => _json({'detail': 'psycopg2.OperationalError: boom'}, 500));
    expect(e.message, contains('having trouble'));
    expect(e.message, isNot(contains('psycopg2')));
    expect(e.isServerError, isTrue);
    expect(e.isPermanent, isFalse);
  });

  test('being offline reads as a connection problem without dev hints',
      () async {
    final e = await _errorFrom((options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ));
    expect(e.message, contains('internet'));
    expect(e.message.toLowerCase(), isNot(contains('backend')));
    expect(e.statusCode, isNull);
    expect(e.isPermanent, isFalse);
  });

  test('rate limiting is transient, not permanent', () async {
    final e = await _errorFrom((_) async => _json({}, 429));
    expect(e.isPermanent, isFalse);
  });

  test('a non-object body becomes an AppError instead of a TypeError',
      () async {
    final e = await _errorFrom((_) async => _json([1, 2, 3], 200));
    expect(e.message, contains('unexpected reply'));
  });

  test('post forwards extra headers such as Idempotency-Key', () async {
    final h = _clientAnswering((_) async => _json({'ok': true}, 200));
    await h.client.post('/rides', {}, headers: {'Idempotency-Key': 'abc'});
    expect(h.adapter.last!.headers['Idempotency-Key'], 'abc');
  });

  group('resolveApiBaseUrl', () {
    test('release builds require an https URL', () {
      expect(
        () => resolveApiBaseUrl(envUrl: null, isRelease: true, isWeb: false),
        throwsStateError,
      );
      expect(
        () => resolveApiBaseUrl(
            envUrl: 'http://10.0.2.2:8000', isRelease: true, isWeb: false),
        throwsStateError,
      );
      expect(
        resolveApiBaseUrl(
            envUrl: 'https://api.example.com', isRelease: true, isWeb: false),
        'https://api.example.com',
      );
    });

    test('debug builds fall back to the emulator host or localhost on web', () {
      expect(resolveApiBaseUrl(envUrl: '', isRelease: false, isWeb: false),
          'http://10.0.2.2:8000');
      expect(resolveApiBaseUrl(envUrl: null, isRelease: false, isWeb: true),
          'http://localhost:8000');
    });
  });
}
