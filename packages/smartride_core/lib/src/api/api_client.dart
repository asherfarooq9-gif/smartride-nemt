import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../storage/secure_storage.dart';
import 'api_error.dart';

class ApiClient {
  ApiClient._() {
    // Read the env value safely — dotenv may not be initialised on web.
    String? envUrl;
    try {
      envUrl = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    } catch (_) {
      envUrl = null;
    }
    // Platform-correct default: 10.0.2.2 is the Android-emulator alias for the
    // host and is UNREACHABLE from a desktop browser, so web must use localhost.
    const defaultUrl =
        kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
    final baseUrl = (envUrl != null && envUrl.isNotEmpty) ? envUrl : defaultUrl;
    if (kReleaseMode &&
        !kIsWeb &&
        !baseUrl.startsWith('https://') &&
        !baseUrl.startsWith('http://127.') &&
        !baseUrl.startsWith('http://10.0.2.2')) {
      throw StateError(
          'API_BASE_URL must use HTTPS in release builds. Got: $baseUrl');
    }
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
  }) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: queryParams);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<dynamic>(path, data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<dynamic>(path, data: body);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppError _mapError(DioException e) {
    if (e.response?.statusCode == 401) {
      // Read the backend detail first — login failures return "Invalid credentials"
      // which should NOT be shown as "Session expired".
      final detail = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      if (detail != null &&
          !detail.toLowerCase().contains('expired') &&
          !detail.toLowerCase().contains('invalid or expired')) {
        return AppError(detail, statusCode: 401);
      }
      return const AuthExpiredError();
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppError(
          'Could not reach the server. Please check your internet connection and try again.',
          statusCode: null,
        );
      case DioExceptionType.connectionError:
        return const AppError(
          'Unable to connect to server. Make sure the backend is running.',
          statusCode: null,
        );
      case DioExceptionType.badCertificate:
        return const AppError(
          'Secure connection failed. Please contact support.',
          statusCode: null,
        );
      default:
        break;
    }

    if (e.response?.statusCode == 409) {
      final detail = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      return AppError(
          detail ?? 'Conflict — this action could not be completed.',
          statusCode: 409);
    }

    if (e.response?.statusCode == 403) {
      final detail = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      return AppError(detail ?? 'You do not have permission to do this.',
          statusCode: 403);
    }

    final msg = (e.response?.data is Map)
        ? (e.response!.data as Map)['detail']?.toString() ??
            e.message ??
            'Something went wrong. Please try again.'
        : e.message ?? 'Something went wrong. Please try again.';
    return AppError(msg, statusCode: e.response?.statusCode);
  }
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
    } on DioException {
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
    final carriedToken =
        err.requestOptions.headers.containsKey('Authorization');
    if (err.response?.statusCode == 401 && carriedToken) {
      await SecureStorage.instance.clear();
      ApiClient.onUnauthorized?.call();
    }
    handler.next(err);
  }
}
