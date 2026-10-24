import 'dart:developer' as developer;

typedef ErrorSink = void Function(
  String context,
  Object error,
  StackTrace? stackTrace,
);

/// Single place where handled-but-unexpected errors are recorded.
///
/// Always logs locally; the app installs [sink] at startup to forward to
/// Crashlytics. Reporting never throws, so it is safe inside catch blocks.
class ErrorReporter {
  ErrorReporter._();

  static ErrorSink? sink;

  static void report(String context, Object error, [StackTrace? stackTrace]) {
    developer.log(
      context,
      name: 'smartride.error',
      error: error,
      stackTrace: stackTrace,
    );
    try {
      sink?.call(context, error, stackTrace);
    } on Object catch (sinkError, sinkStack) {
      developer.log(
        'Error sink failed',
        name: 'smartride.error',
        error: sinkError,
        stackTrace: sinkStack,
      );
    }
  }
}
