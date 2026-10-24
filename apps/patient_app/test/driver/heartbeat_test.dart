import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

void main() {
  test('posts the current position and reports sent', () async {
    final posted = <(double, double)>[];
    final result = await sendHeartbeat(
      readLocation: () async => _at(33.7, 73.0),
      post: (lat, lng) async => posted.add((lat, lng)),
    );
    expect(result, HeartbeatResult.sent);
    expect(posted, [(33.7, 73.0)]);
  });

  test('no location means nothing is posted and the caller is told', () async {
    var posts = 0;
    final result = await sendHeartbeat(
      readLocation: () async => null,
      post: (_, __) async => posts++,
    );
    expect(result, HeartbeatResult.noLocation);
    expect(posts, 0);
  });

  test('a server error is reported once per streak, never thrown', () async {
    final reported = <String>[];
    core.ErrorReporter.sink = (context, _, __) => reported.add(context);
    addTearDown(() => core.ErrorReporter.sink = null);

    Future<HeartbeatResult> beat({required bool report}) => sendHeartbeat(
          readLocation: () async => _at(0, 0),
          post: (_, __) async =>
              throw const core.AppError('down', statusCode: 503),
          reportErrors: report,
        );

    expect(await beat(report: true), HeartbeatResult.failed);
    expect(await beat(report: false), HeartbeatResult.failed);
    expect(reported, ['Driver heartbeat failed']);
  });

  test('beat interval stays well inside the 120s dispatch window', () {
    expect(driverHeartbeatInterval, lessThan(const Duration(seconds: 60)));
  });
}
