import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'secure_storage.dart';

/// Typed error thrown by all ApiClient methods.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const _envUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static final String _baseUrl = _envUrl.isNotEmpty
      ? _envUrl
      : kIsWeb
          ? 'http://localhost:8000'
          : 'http://10.0.2.2:8000';

  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    // Assert fires in debug; StateError fires in release — both crash fast rather than leak data
    final isAllowed = _baseUrl.startsWith('https://') ||
        _baseUrl.startsWith('http://10.0.2.2') ||
        _baseUrl.startsWith('http://localhost');
    assert(isAllowed, 'API_BASE_URL must use HTTPS in production. Got: $_baseUrl');
    if (!isAllowed) {
      throw StateError('API_BASE_URL must use HTTPS in production. Got: $_baseUrl');
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: kIsWeb ? null : const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> post(String path, {Object? body}) async {
    try {
      final res = await _dio.post(path, data: body);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final res = await _dio.patch(path, data: body);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static ApiException _mapError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    final detail = (data is Map) ? data['detail'] as String? : null;
    return ApiException(
      detail ?? e.message ?? 'Network error',
      statusCode: code,
    );
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Read token fresh from secure storage on every request — never cache in memory
    final token = await SecureStorage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Await deletion so token is gone before handler proceeds
      await SecureStorage.deleteToken();
    }
    return handler.next(err);
  }
}
