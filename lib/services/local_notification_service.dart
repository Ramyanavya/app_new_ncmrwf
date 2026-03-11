import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// initialize notification plugin
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await notificationsPlugin.initialize(initSettings);
  }

  /// show weather alert
  static Future<void> showWeatherAlert(String message) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'weather_channel',
      'Weather Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      0,
      "Weather Alert",
      message,
      details,
    );
  }
}