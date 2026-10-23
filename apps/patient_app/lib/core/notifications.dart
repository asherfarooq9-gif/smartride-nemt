import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _msgController = StreamController<RemoteMessage>.broadcast();
Stream<RemoteMessage> get incomingMessageStream => _msgController.stream;

final _localNotifications = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  'smartride_rides',
  'Ride Updates',
  description: 'Notifications about your ride status',
  importance: Importance.high,
);

// Top-level handler required by firebase_messaging for background messages
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showLocal(message);
}

const _registerRetryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// Tell the backend which device to push to. Call after signing in; does
/// nothing when Firebase is not configured (local builds, web).
Future<void> registerPushToken() async {
  String? token;
  try {
    token = await FirebaseMessaging.instance.getToken();
  } on Object catch (e, st) {
    // Firebase unavailable: the app works, just without push.
    core.ErrorReporter.report('Push token unavailable', e, st);
    return;
  }
  if (token != null) await registerTokenWithRetry(token);
}

/// Registers [token] with the backend, retrying transient failures (offline,
/// 5xx) a few times. A token the server never receives means silent missed
/// ride notifications, so a final failure is reported rather than dropped.
@visibleForTesting
Future<void> registerTokenWithRetry(
  String token, {
  Future<void> Function(String) register = core.registerFcmToken,
  List<Duration> delays = _registerRetryDelays,
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      await register(token);
      return;
    } on core.AppError catch (e, st) {
      if (e.statusCode == 401) return; // signed out: nothing to register for
      if (e.isPermanent || attempt >= delays.length) {
        core.ErrorReporter.report('Push token registration failed', e, st);
        return;
      }
      await Future<void>.delayed(delays[attempt]);
    }
  }
}

/// Invalidate this device's token on sign-out so the next person to sign in
/// here cannot receive the previous account's ride notifications.
Future<void> forgetPushToken() async {
  try {
    await FirebaseMessaging.instance.deleteToken();
  } on Object catch (e, st) {
    // Firebase unavailable: nothing to forget.
    core.ErrorReporter.report('Push token could not be deleted', e, st);
  }
}

Future<void> initNotifications({required GoRouter router}) async {
  await Firebase.initializeApp();

  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);
  messaging.onTokenRefresh.listen((token) => registerTokenWithRetry(token));

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (details) =>
        _handleTap(details.payload, router),
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);

  // Foreground messages
  FirebaseMessaging.onMessage.listen((msg) => _showLocal(msg));

  // Background tap
  FirebaseMessaging.onMessageOpenedApp.listen(
    (msg) => _route(msg.data, router),
  );

  // App launched from terminated via notification
  final initial = await messaging.getInitialMessage();
  if (initial != null) _route(initial.data, router);

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
}

void _showLocal(RemoteMessage msg) {
  final notification = msg.notification;
  if (notification == null) return;
  _msgController.add(msg);
  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: _androidChannel.importance,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: msg.data['ride_id'] as String?,
  );
}

// Ride ids are UUIDs — reject anything else before it reaches the router so a
// malformed or malicious payload can't navigate to an arbitrary location.
final _rideIdPattern = RegExp(r'^[0-9a-fA-F-]{8,40}$');

void _openRide(String? rideId, GoRouter router) {
  if (rideId == null || !_rideIdPattern.hasMatch(rideId)) return;
  // Defer until after the first frame so the router's auth redirect has
  // resolved — a stale notification tapped while logged out must land on
  // /welcome, not push a detail screen over it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    router.push('/ride/$rideId');
  });
}

void _handleTap(String? rideId, GoRouter router) => _openRide(rideId, router);

void _route(Map<String, dynamic> data, GoRouter router) =>
    _openRide(data['ride_id'] as String?, router);
