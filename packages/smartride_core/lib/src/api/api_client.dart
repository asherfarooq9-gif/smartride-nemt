import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../storage/secure_storage.dart';
import 'api_error.dart';

class ApiClient {
  ApiClient._() {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
    assert(
      !kReleaseMode || baseUrl.startsWith('https://') || baseUrl.startsWith('http://127.') || baseUrl.startsWith('http://10.0.2.2'),
      'API_BASE_URL must use HTTPS in release builds. Got: $baseUrl',
    );
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor());
  }

  static final ApiClient instance = ApiClient._();

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
      return AppError(detail ?? 'Conflict — this action could not be completed.',
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

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.instance.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      SecureStorage.instance.clear();
    }
    handler.next(err);
  }
}
