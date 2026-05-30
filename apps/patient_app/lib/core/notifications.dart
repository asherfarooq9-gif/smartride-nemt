import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

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

Future<void> initNotifications({required GoRouter router}) async {
  await Firebase.initializeApp();

  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(alert: true, badge: true, sound: true);

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

void _handleTap(String? rideId, GoRouter router) {
  if (rideId != null) router.push('/ride/$rideId');
}

void _route(Map<String, dynamic> data, GoRouter router) {
  final rideId = data['ride_id'] as String?;
  if (rideId != null) router.push('/ride/$rideId');
}
