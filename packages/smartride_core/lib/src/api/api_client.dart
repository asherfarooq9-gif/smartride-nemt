import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode, kIsWeb, visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../diagnostics/error_reporter.dart';
import '../storage/secure_storage.dart';
import 'api_error.dart';

class ApiClient {
  ApiClient._() {
    // Read the env value safely — dotenv may not be initialised on web.
    String? envUrl;
    try {
      envUrl = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    } on Object {
      envUrl = null;
    }
    final baseUrl = resolveApiBaseUrl(
      envUrl: envUrl,
      isRelease: kReleaseMode,
      isWeb: kIsWeb,
    );
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(AuthInterceptor());
  }

  @visibleForTesting
  ApiClient.withDio(Dio dio) : _dio = dio;

  static final ApiClient instance = ApiClient._();

  /// Called when an authenticated request is rejected with 401 (expired or
  /// revoked token). The app registers a handler that signs the user out;
  /// without it the stored token is cleared but the UI still believes it is
  /// signed in and every later request silently fails.
  static void Function()? onUnauthorized;

  late final Dio _dio;

  String get wsBaseUrl {
    final base = _dio.options.baseUrl;
    return base.replaceFirst(RegExp(r'^http'), 'ws');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) =>
      _send(path, () => _dio.get<dynamic>(path, queryParameters: queryParams));

  /// [headers] are merged into the request (e.g. an `Idempotency-Key`).
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) =>
      _send(
        path,
        () => _dio.post<dynamic>(
          path,
          data: body,
          options: headers == null ? null : Options(headers: headers),
        ),
      );

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send(path, () => _dio.patch<dynamic>(path, data: body));

  Future<Map<String, dynamic>> _send(
    String path,
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return _asObject(path, await request());
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// The API only speaks JSON objects. Anything else is a server/proxy fault:
  /// report it with the path for diagnosis and show the patient a plain message.
  Map<String, dynamic> _asObject(String path, Response<dynamic> res) {
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data == null && res.statusCode == 204) return const {};
    ErrorReporter.report(
      'Unexpected response body from $path (${data.runtimeType})',
      StateError('Expected a JSON object, got ${data.runtimeType}'),
    );
    throw AppError(
      'We got an unexpected reply from the server. Please try again.',
      statusCode: res.statusCode,
    );
  }

  AppError _mapError(DioException e) {
    final status = e.response?.statusCode;
    final detail = _detailOf(e.response?.data);

    if (status == 401) {
      // Login failures return "Invalid credentials", which must NOT be shown
      // as "Session expired".
      final lower = detail?.toLowerCase() ?? '';
      if (detail != null &&
          !lower.contains('expired') &&
          !lower.contains('invalid or expired')) {
        return AppError(detail, statusCode: 401);
      }
      return const AuthExpiredError();
    }

    if (status == null) return _transportError(e.type);
    if (status >= 500) {
      return AppError(
        'Our service is having trouble right now. Please try again in a moment.',
        statusCode: status,
      );
    }
    return AppError(detail ?? _clientErrorText(status), statusCode: status);
  }

  AppError _transportError(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppError(
          'The server is taking too long to respond. Please check your '
          'connection and try again.',
        );
      case DioExceptionType.connectionError:
        return const AppError(
          'No internet connection. Please check your connection and try again.',
        );
      case DioExceptionType.badCertificate:
        return const AppError('Secure connection failed. Please contact support.');
      default:
        return const AppError('Something went wrong. Please try again.');
    }
  }

  String _clientErrorText(int status) => switch (status) {
        403 => 'You do not have permission to do this.',
        404 => 'We could not find what you asked for.',
        408 => 'The request timed out. Please try again.',
        409 => 'This action could not be completed. Please refresh and try again.',
        429 => 'Too many attempts. Please wait a moment and try again.',
        _ => 'Please check the details you entered and try again.',
      };

  /// Plain-text reason from a FastAPI error body. `detail` is a string for
  /// HTTPException and a list of `{loc, msg}` items for 422 validation errors.
  String? _detailOf(Object? body) {
    if (body is! Map) return null;
    final detail = body['detail'];
    if (detail is String) return detail.isEmpty ? null : detail;
    if (detail is List) {
      final lines = detail.map(_validationLine).whereType<String>().toSet();
      return lines.isEmpty ? null : lines.join('. ');
    }
    return null;
  }

  String? _validationLine(Object? item) {
    if (item is! Map) return null;
    final msg = item['msg'];
    if (msg is! String || msg.isEmpty) return null;
    final text = msg.replaceFirst(RegExp(r'^Value error, '), '');
    final loc = item['loc'];
    final lastLoc = loc is List && loc.isNotEmpty ? loc.last : null;
    final field =
        lastLoc is String && lastLoc.isNotEmpty ? lastLoc.replaceAll('_', ' ') : null;
    return field == null ? text : '${field[0].toUpperCase()}${field.substring(1)}: $text';
  }
}

/// Picks the API base URL. A release build must be configured with an https
/// URL: silently falling back to the emulator alias would ship an app that
/// cannot reach any server (or sends health data over cleartext).
String resolveApiBaseUrl({
  required String? envUrl,
  required bool isRelease,
  required bool isWeb,
}) {
  final configured = envUrl?.trim() ?? '';
  if (isRelease && !isWeb) {
    if (!configured.startsWith('https://')) {
      throw StateError(
        'API_BASE_URL must be set to an https:// URL in release builds.',
      );
    }
    return configured;
  }
  if (configured.isNotEmpty) return configured;
  // 10.0.2.2 is the Android-emulator alias for the host and is unreachable
  // from a desktop browser, so web must use localhost.
  return isWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
}

/// When a JWT expires, read from its (unverified) payload; null if unreadable.
DateTime? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    return exp is num
        ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
        : null;
  } on FormatException {
    return null;
  }
}

/// Attaches the stored bearer token (renewing it shortly before it expires) and
/// ends the session when the server rejects it.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({Dio Function(String baseUrl)? refreshClient})
      : _refreshClient =
            refreshClient ?? ((url) => Dio(BaseOptions(baseUrl: url)));

  /// The server only renews tokens that are still valid, so renew with margin.
  static const _renewWithin = Duration(minutes: 10);

  final Dio Function(String baseUrl) _refreshClient;
  Future<String?>? _renewing; // one renewal shared by concurrent requests

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var token = await SecureStorage.instance.readToken();
    if (token != null && _expiresSoon(token)) {
      token = await (_renewing ??= _renew(options.baseUrl, token)
              .whenComplete(() => _renewing = null)) ??
          token;
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  bool _expiresSoon(String token) {
    final expiry = jwtExpiry(token);
    return expiry != null && expiry.difference(DateTime.now()) < _renewWithin;
  }

  /// Returns the new token, or null when the server refused (the original
  /// request then goes out and its 401 ends the session).
  Future<String?> _renew(String baseUrl, String token) async {
    try {
      final res = await _refreshClient(baseUrl).post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final renewed = res.data?['access_token'] as String?;
      if (renewed != null) await SecureStorage.instance.saveToken(renewed);
      return renewed;
    } on DioException catch (e, st) {
      // Not fatal: the original request goes out and decides the session's
      // fate, but a failing renewal is worth knowing about.
      ErrorReporter.report('Token renewal failed', e, st);
      return null;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only a request that carried a token can mean "session expired"; a 401
    // from /auth/login just means wrong credentials.
    final sentHeader = err.requestOptions.headers['Authorization'];
    if (err.response?.statusCode == 401 && sentHeader is String) {
      // A slow request that was sent before the user signed out and back in
      // must not end the new session: only act if the token it carried is
      // still the one stored.
      final current = await SecureStorage.instance.readToken();
      if (current != null && sentHeader == 'Bearer $current') {
        await SecureStorage.instance.clearAuth();
        ApiClient.onUnauthorized?.call();
      }
    }
    handler.next(err);
  }
}
