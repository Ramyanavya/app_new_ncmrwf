// lib/widgets/weather_widget.dart
// Saves directly to FlutterSharedPreferences — bypasses home_widget storage
// so the Kotlin widget can read it directly.
//
// ✅ KEY FIX: temperature and feels_like now use wp.liveTemperatureC and
// wp.liveFeelsLikeC (diurnal model) instead of cw.temperatureC (raw API).
// This makes the home screen widget match the forecast screen exactly.
//
// ✅ THEME: 'hour' is now sent so the Kotlin widget can pick the correct
// condition + time-of-day gradient drawable without any extra logic.

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../providers/weather_provider.dart';

class WeatherWidgetUpdater {
  static const _channel = MethodChannel('com.example.new_ncmrwf_app/widget');

  static Future<void> update(WeatherProvider wp) async {
    if (wp.currentWeather == null) {
      debugPrint('Widget update skipped: no data');
      return;
    }

    try {
      final cw = wp.currentWeather!;

      // ✅ Use liveTemperatureC (diurnal model) — this is what the app screen shows.
      // cw.temperatureC is the raw NCMRWF API value which can be wrong in the morning.
      // liveTemperatureC applies the tMin/tMax diurnal curve so it matches the UI.
      final displayTemp   = wp.liveTemperatureC.toStringAsFixed(0);
      final displayFeels  = wp.liveFeelsLikeC.toStringAsFixed(1);
      final displayCond   = wp.liveCondition;
      final displayHum    = wp.liveHumidityPercent.toStringAsFixed(0);
      final displayWind   = wp.liveWindSpeedKmh.toStringAsFixed(1);

      debugPrint('[WeatherWidget] Sending to widget:');
      debugPrint('  temp = $displayTemp°C (diurnal) vs ${cw.temperatureC.toStringAsFixed(0)}°C (raw API)');
      debugPrint('  feels = $displayFeels°C');
      debugPrint('  condition = $displayCond');

      await _channel.invokeMethod('updateWidget', {
        // ── Current conditions ────────────────────────────────────────────
        'location':    wp.placeName,

        // ✅ FIXED: was cw.temperatureC (raw), now liveTemperatureC (diurnal)
        'temperature': displayTemp,

        // ✅ FIXED: was cw.condition, now liveCondition (from nearest hourly slot)
        'condition':   displayCond,

        // ✅ FIXED: was cw.feelsLikeC (raw), now liveFeelsLikeC (diurnal - 1)
        'feels_like':  displayFeels,

        // ✅ FIXED: was cw.humidityPercent (raw), now liveHumidityPercent (nearest hourly)
        'humidity':    displayHum,

        // ✅ FIXED: was cw.windSpeedKmh (raw), now liveWindSpeedKmh (nearest hourly)
        'wind':        displayWind,

        // These don't have diurnal equivalents — raw API values are fine here
        'wind_dir':    cw.windDirection,
        'pressure':    cw.pressureMb.toString(),
        'rain':        cw.rainMm.toStringAsFixed(1),
        'uv_index':    cw.uvIndex.toStringAsFixed(1),
        'data_time':   cw.dataTime ?? '',

        // ✅ THEME: current device hour so Kotlin picks the right time-of-day
        // gradient (dawn/day/dusk/night) without needing any extra calculation.
        'hour':        DateTime.now().hour.toString(),

        // ── 4-day forecast ────────────────────────────────────────────────────
        // These correctly use tempMax/tempMin from the daily forecast (unchanged)
        'fc_day_0':  wp.forecast.length > 0 ? _dayShort(wp.forecast[0].day) : '---',
        'fc_temp_0': wp.forecast.length > 0 ? wp.forecast[0].tempMax.toStringAsFixed(0) : '--',
        'fc_tmin_0': wp.forecast.length > 0 ? wp.forecast[0].tempMin.toStringAsFixed(0) : '--',
        'fc_cond_0': wp.forecast.length > 0 ? wp.forecast[0].condition : '',

        'fc_day_1':  wp.forecast.length > 1 ? _dayShort(wp.forecast[1].day) : '---',
        'fc_temp_1': wp.forecast.length > 1 ? wp.forecast[1].tempMax.toStringAsFixed(0) : '--',
        'fc_tmin_1': wp.forecast.length > 1 ? wp.forecast[1].tempMin.toStringAsFixed(0) : '--',
        'fc_cond_1': wp.forecast.length > 1 ? wp.forecast[1].condition : '',

        'fc_day_2':  wp.forecast.length > 2 ? _dayShort(wp.forecast[2].day) : '---',
        'fc_temp_2': wp.forecast.length > 2 ? wp.forecast[2].tempMax.toStringAsFixed(0) : '--',
        'fc_tmin_2': wp.forecast.length > 2 ? wp.forecast[2].tempMin.toStringAsFixed(0) : '--',
        'fc_cond_2': wp.forecast.length > 2 ? wp.forecast[2].condition : '',

        'fc_day_3':  wp.forecast.length > 3 ? _dayShort(wp.forecast[3].day) : '---',
        'fc_temp_3': wp.forecast.length > 3 ? wp.forecast[3].tempMax.toStringAsFixed(0) : '--',
        'fc_tmin_3': wp.forecast.length > 3 ? wp.forecast[3].tempMin.toStringAsFixed(0) : '--',
        'fc_cond_3': wp.forecast.length > 3 ? wp.forecast[3].condition : '',
      });

      debugPrint('✅ Widget updated via MethodChannel — showing $displayTemp°C');
    } catch (e) {
      debugPrint('⚠️ Widget update failed: $e');
    }
  }

  static String _dayShort(String day) =>
      day.length >= 3 ? day.substring(0, 3) : day;
}