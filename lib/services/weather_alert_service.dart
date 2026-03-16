// lib/services/weather_alert_service.dart

import 'package:flutter/foundation.dart';
import '../models/weather_model.dart';
import 'local_notification_service.dart';

class WeatherAlertService {

  // ── Called by WeatherProvider on every fetch ─────────────────────────────
  // Uses liveTemp/liveWind/liveRain from WeatherProvider (diurnal model)
  // so the temperature matches exactly what the app displays on screen.
  static Future<void> checkAndSendLive({
    required CurrentWeather weather,
    required double liveTemp, // WeatherProvider.liveTemperatureC — matches app display
    required double liveWind, // WeatherProvider.liveWindSpeedKmh
    required double liveRain, // WeatherProvider.liveRainMm
  }) async {
    debugPrint('[Alert] ════ checkAndSend called ════');
    debugPrint('[Alert] condition="${weather.condition}"');
    debugPrint('[Alert] liveTemp=$liveTemp°C');
    debugPrint('[Alert] liveWind=$liveWind km/h');
    debugPrint('[Alert] liveRain=$liveRain mm');

    final alert = _buildAlert(
      condition: weather.condition,
      temp:      liveTemp,
      wind:      liveWind,
      rain:      liveRain,
    );

    debugPrint('[Alert] result: ${alert?['title'] ?? '⚠️ NO ALERT — condition not met'}');

    if (alert == null) return;

    try {
      await LocalNotificationService.showWeatherAlert(
        alert['title']!,
        alert['body']!,
      );
      debugPrint('[Alert] ✅ Notification shown: ${alert['title']}');
    } catch (e) {
      debugPrint('[Alert] ❌ Failed to show notification: $e');
    }
  }

  // ── Condition logic ───────────────────────────────────────────────────────
  static Map<String, String>? _buildAlert({
    required String condition,
    required double temp,
    required double wind,
    required double rain,
  }) {
    final c = condition.toLowerCase();

    // Severe conditions first
    if (c.contains('thunder') || c.contains('storm')) {
      return {
        'title': '⛈ Thunderstorm Warning',
        'body':  'A thunderstorm is approaching your area. Stay indoors.',
      };
    }
    if (c.contains('snow') || c.contains('sleet') || c.contains('blizzard')) {
      return {
        'title': '❄️ Snow Alert',
        'body':  'Snowfall expected. Drive carefully and stay warm.',
      };
    }
    if (wind > 30) {
      return {
        'title': '💨 Windy Conditions',
        'body':  'Winds at ${wind.toStringAsFixed(0)} km/h today. Secure loose objects.',
      };
    }
    if (rain > 10) {
      return {
        'title': '🌧 Heavy Rainfall Alert',
        'body':  'Expecting ${rain.toStringAsFixed(0)}mm of rain. Carry an umbrella.',
      };
    }
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower')) {
      return {
        'title': '🌧 Rain Expected',
        'body':  'Rainy conditions today. Don\'t forget your umbrella.',
      };
    }
    if (c.contains('fog') || c.contains('mist') || c.contains('haze')) {
      return {
        'title': '🌫 Fog Advisory',
        'body':  'Low visibility conditions. Drive carefully today.',
      };
    }
    if (temp >= 35) {
      return {
        'title': '☀️ Heat Advisory',
        'body':  'Hot day at ${temp.toStringAsFixed(0)}°C. Stay hydrated and avoid direct sun.',
      };
    }
    if (temp <= 15) {
      return {
        'title': '🧥 Cold Weather Alert',
        'body':  'Temperature at ${temp.toStringAsFixed(0)}°C. Dress warmly today.',
      };
    }

    // ── Remove this block once you confirm notifications show correct temp ─
    return {
      'title': '🌤 Weather Update',
      'body':  '$condition, ${temp.toStringAsFixed(0)}°C — Have a great day!',
    };
  }
}