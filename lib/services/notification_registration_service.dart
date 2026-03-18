// lib/services/notification_registration_service.dart
//
// Called after every successful weather fetch in WeatherProvider.
// Registers this device's OneSignal player ID + GPS location
// with the backend so it gets location-based background alerts.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationRegistrationService {

  // ── Your Render.com URL — update this after deploying ──────────────────
  // Format: https://YOUR-APP-NAME.onrender.com
  static const _backendUrl = 'https://ncmrwf-alerts.onrender.com';

  // ── Register this device with the backend ──────────────────────────────
  // Call this after every successful GPS location fetch in WeatherProvider
  static Future<void> register({
    required double lat,
    required double lon,
  }) async {
    try {
      final playerId = OneSignal.User.pushSubscription.id;

      if (playerId == null || playerId.isEmpty) {
        debugPrint('[NotifReg] Skipping — OneSignal player ID not ready yet');
        return;
      }

      final res = await http.post(
        Uri.parse('$_backendUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playerId': playerId,
          'lat'     : lat,
          'lon'     : lon,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint('[NotifReg] ✅ ${data['action']} — '
            'total users: ${data['userCount']}');
      } else {
        debugPrint('[NotifReg] ❌ Server error: ${res.statusCode}');
      }
    } catch (e) {
      // Non-fatal — app works fine without this
      debugPrint('[NotifReg] Registration failed (non-fatal): $e');
    }
  }

  // ── Unregister on logout ───────────────────────────────────────────────
  static Future<void> unregister() async {
    try {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) return;

      await http.post(
        Uri.parse('$_backendUrl/unregister'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'playerId': playerId}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[NotifReg] Unregistered from backend');
    } catch (e) {
      debugPrint('[NotifReg] Unregister failed (non-fatal): $e');
    }
  }
}