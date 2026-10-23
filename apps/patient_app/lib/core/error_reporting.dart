import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Forwards provider failures to the shared error reporter. Expected request
/// failures (offline, 4xx) are skipped: they are shown to the user, and would
/// only drown out real faults.
base class ErrorReportingObserver extends ProviderObserver {
  const ErrorReportingObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    if (error is core.AppError && !error.isServerError) return;
    core.ErrorReporter.report(
      'Provider ${provider.name ?? provider.runtimeType} failed',
      error,
      stackTrace,
    );
  }
}

/// Replaces the grey/blank release-mode error box with something a patient
/// can act on. It runs outside the app's theme, so it styles itself.
Widget friendlyErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Semantics(
      container: true,
      liveRegion: true,
      child: const ColoredBox(
        color: Color(0xFFFFFFFF),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong on this screen.\n'
              'Please go back and try again.\n\n'
              'If this is an emergency, call 1122.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF152626),
                fontSize: 18,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Debug builds keep Flutter's red error box so developers still see the cause.
void installFriendlyErrorWidget() {
  if (kDebugMode) return;
  ErrorWidget.builder = friendlyErrorWidget;
}
