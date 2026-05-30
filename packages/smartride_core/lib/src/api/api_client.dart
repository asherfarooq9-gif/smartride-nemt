import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../storage/secure_storage.dart';
import 'api_error.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000',
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
    if (e.response?.statusCode == 401) return const AuthExpiredError();
    final msg = (e.response?.data is Map)
        ? (e.response!.data as Map)['detail']?.toString() ??
            e.message ??
            'Unknown error'
        : e.message ?? 'Unknown error';
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
