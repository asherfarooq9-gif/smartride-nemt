import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Features that silently do nothing when a platform declaration is missing:
/// calling the driver, texting the family, location, push, background tracking.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  group('Android manifest', () {
    test('declares the permissions the app relies on', () {
      for (final permission in [
        'INTERNET',
        'ACCESS_FINE_LOCATION',
        'ACCESS_COARSE_LOCATION',
        'POST_NOTIFICATIONS',
        'FOREGROUND_SERVICE',
        'FOREGROUND_SERVICE_LOCATION',
      ]) {
        expect(manifest, contains('android.permission.$permission'),
            reason: permission);
      }
    });

    test('lets the app see dialer and SMS apps (Android 11+ package visibility)',
        () {
      expect(manifest, contains('android:scheme="tel"'));
      expect(manifest, contains('android:scheme="sms"'));
    });

    test('keeps tokens out of device backups and blocks cleartext traffic', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
    });
  });

  group('iOS Info.plist', () {
    test('explains why location is needed', () {
      expect(plist, contains('NSLocationWhenInUseUsageDescription'));
      expect(plist, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
    });

    test('allows background location and push', () {
      expect(plist, contains('UIBackgroundModes'));
      expect(plist, contains('<string>location</string>'));
      expect(plist, contains('<string>remote-notification</string>'));
    });

    test('allows opening the dialer and messages apps', () {
      expect(plist, contains('LSApplicationQueriesSchemes'));
      expect(plist, contains('<string>tel</string>'));
      expect(plist, contains('<string>sms</string>'));
    });
  });
}
