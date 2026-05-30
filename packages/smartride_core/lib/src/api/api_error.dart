class AppError implements Exception {
  const AppError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'AppError($statusCode): $message';
}

class AuthExpiredError extends AppError {
  const AuthExpiredError()
      : super('Session expired. Please log in again.', statusCode: 401);
}

class NetworkError extends AppError {
  const NetworkError([String? msg])
      : super(msg ?? 'Network error. Check your connection.');
}
