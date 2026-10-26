import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

void main() {
  test('a 409 says another driver took it, in the server words', () {
    final outcome = acceptOutcomeForError(
      const core.AppError('Ride already taken by another driver', statusCode: 409),
    );
    expect(outcome.result, AcceptResult.alreadyTaken);
    expect(outcome.message, 'Ride already taken by another driver');
  });

  test('a 403 means the ride is not near this driver, not "taken"', () {
    final outcome = acceptOutcomeForError(
      const core.AppError('This ride is too far from you', statusCode: 403),
    );
    expect(outcome.result, AcceptResult.notNearby);
    expect(outcome.message, 'This ride is too far from you');
  });

  test('any other failure is an error that still carries its message', () {
    final outcome = acceptOutcomeForError(
      const core.AppError('Server unavailable', statusCode: 503),
    );
    expect(outcome.result, AcceptResult.error);
    expect(outcome.message, 'Server unavailable');
  });

  test('a failure with no status code is still shown', () {
    final outcome = acceptOutcomeForError(const core.AppError('No connection'));
    expect(outcome.result, AcceptResult.error);
    expect(outcome.message, 'No connection');
  });

  test('every outcome has a message to show, so nothing fails silently', () {
    for (final code in [null, 400, 401, 403, 404, 409, 429, 500]) {
      final outcome = acceptOutcomeForError(core.AppError('x', statusCode: code));
      expect(outcome.message, isNotEmpty, reason: 'status $code');
    }
  });
}
