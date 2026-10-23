import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/notifications.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const _noWait = [Duration.zero, Duration.zero, Duration.zero];

void main() {
  test('retries transient failures until the token is registered', () async {
    var attempts = 0;
    await registerTokenWithRetry(
      'fcm',
      delays: _noWait,
      register: (_) async {
        attempts++;
        if (attempts < 3) throw const core.AppError('offline');
      },
    );
    expect(attempts, 3);
  });

  test('gives up and reports after the retries are used up', () async {
    var attempts = 0;
    final reported = <String>[];
    core.ErrorReporter.sink = (context, _, __) => reported.add(context);
    addTearDown(() => core.ErrorReporter.sink = null);

    await registerTokenWithRetry(
      'fcm',
      delays: _noWait,
      register: (_) async {
        attempts++;
        throw const core.AppError('down', statusCode: 503);
      },
    );

    expect(attempts, 4); // first try + 3 retries
    expect(reported, ['Push token registration failed']);
  });

  test('does not retry a permanent rejection', () async {
    var attempts = 0;
    await registerTokenWithRetry(
      'fcm',
      delays: _noWait,
      register: (_) async {
        attempts++;
        throw const core.AppError('bad token', statusCode: 422);
      },
    );
    expect(attempts, 1);
  });

  test('a signed-out device (401) stops quietly', () async {
    var attempts = 0;
    final reported = <String>[];
    core.ErrorReporter.sink = (context, _, __) => reported.add(context);
    addTearDown(() => core.ErrorReporter.sink = null);

    await registerTokenWithRetry(
      'fcm',
      delays: _noWait,
      register: (_) async {
        attempts++;
        throw const core.AuthExpiredError();
      },
    );

    expect(attempts, 1);
    expect(reported, isEmpty);
  });
}
