// lib/services/local_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Optional: wire this up to navigate on tap
  static Function(String? payload)? onNotificationTap;

  // ── Initialize ────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[LocalNotif] Tapped: ${details.payload}');
        onNotificationTap?.call(details.payload);
      },
    );

    // Create the notification channel on Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'weather_channel',
      'Weather Alerts',
      description: 'Real-time severe weather condition alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('[LocalNotif] Initialized ✅');
  }

  // ── Show a weather alert notification ─────────────────────────────────────
  static Future<void> showWeatherAlert(
      String title,
      String body, {
        String? payload,
      }) async {
    debugPrint('[LocalNotif] Showing: "$title" | "$body"');

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'weather_channel',
      'Weather Alerts',
      channelDescription: 'Real-time severe weather condition alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Shows notification even when app is in foreground
      visibility: NotificationVisibility.public,
      fullScreenIntent: false,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    try {
      await notificationsPlugin.show(
        0,
        title,
        body,
        details,
        payload: payload ?? 'forecast',
      );
      debugPrint('[LocalNotif] ✅ show() called successfully');
    } catch (e) {
      debugPrint('[LocalNotif] ❌ show() failed: $e');
    }
  }
}