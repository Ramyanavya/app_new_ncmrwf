// lib/utils/weather_condition_theme.dart
// Logic is 100% unchanged — only added a re-export of TimeTheme so screens
// can import a single file for all theming needs.
import 'package:flutter/material.dart';
export 'time_theme.dart'; // convenient single-import for screens

class WeatherConditionTheme {
  final List<Color> skyGradient;
  final Color accentColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final String iconAssetHint;

  const WeatherConditionTheme({
    required this.skyGradient,
    required this.accentColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconAssetHint,
  });

  /// Returns a time-aware theme. Hour is used to compute light intensity:
  /// Dawn (5-7), Day (8-17), Dusk (18-20), Night (21-4)
  static WeatherConditionTheme of(String condition, {int? hour}) {
    final h = hour ?? DateTime.now().hour;
    final isDawn = h >= 5 && h < 8;
    final isDay = h >= 8 && h < 18;
    final isDusk = h >= 18 && h < 21;
    final isNight = h >= 21 || h < 5;

    switch (condition.toLowerCase()) {

    // ── SUNNY / HOT ────────────────────────────────────────────────────────
      case 'sunny':
      case 'hot':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF010408), Color(0xFF04080F), Color(0xFF080F1E), Color(0xFF0D1830)],
            accentColor: Color(0xFFB0C4DE),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'sunny',
          );
        }
        if (isDusk) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF1A0A2E), Color(0xFF6B2D3E), Color(0xFFBF5B3A), Color(0xFFE8833A)],
            accentColor: Color(0xFFFFAB40),
            cardColor: Color(0x33FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xDDFFFFFF),
            iconAssetHint: 'sunny',
          );
        }
        if (isDawn) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF1A1040), Color(0xFF5C3060), Color(0xFFD06070), Color(0xFFF4A460)],
            accentColor: Color(0xFFFFCC80),
            cardColor: Color(0x33FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xDDFFFFFF),
            iconAssetHint: 'sunny',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF64B5F6)],
          accentColor: Color(0xFFFFD54F),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'sunny',
        );

    // ── PARTLY CLOUDY ──────────────────────────────────────────────────────
      case 'partly cloudy':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF020508), Color(0xFF060D18), Color(0xFF0B1628), Color(0xFF101F38)],
            accentColor: Color(0xFFB0C4DE),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'partly_cloudy',
          );
        }
        if (isDusk || isDawn) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF1C1030), Color(0xFF4A2850), Color(0xFF8B5A6A), Color(0xFFB07A60)],
            accentColor: Color(0xFFFFB74D),
            cardColor: Color(0x33FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xDDFFFFFF),
            iconAssetHint: 'partly_cloudy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF2196F3), Color(0xFF64B5F6)],
          accentColor: Color(0xFFFFE082),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'partly_cloudy',
        );

    // ── HAZE / CLOUDY ──────────────────────────────────────────────────────
      case 'haze':
      case 'cloudy':
      case 'overcast':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF060A0F), Color(0xFF0B1420), Color(0xFF101C2E), Color(0xFF16263C)],
            accentColor: Color(0xFF7BA8C4),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'cloudy',
          );
        }
        if (isDusk || isDawn) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF1A1830), Color(0xFF3A3050), Color(0xFF6B5060), Color(0xFF8B7060)],
            accentColor: Color(0xFFB0A090),
            cardColor: Color(0x33FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xDDFFFFFF),
            iconAssetHint: 'cloudy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF4A6FA5), Color(0xFF6B92B8), Color(0xFF8BADD0), Color(0xFFAAC4DC)],
          accentColor: Color(0xFFD0E8F8),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'cloudy',
        );

    // ── DRIZZLE / RAIN ─────────────────────────────────────────────────────
      case 'drizzle':
      case 'rainy':
      case 'rain':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF020508), Color(0xFF04090F), Color(0xFF060E18), Color(0xFF0A1622)],
            accentColor: Color(0xFF4E9EC4),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'rainy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF1A2A40), Color(0xFF1E3A5C), Color(0xFF224A72), Color(0xFF2A5A8A)],
          accentColor: Color(0xFF64AADF),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'rainy',
        );

    // ── STORMY / THUNDERSTORM ──────────────────────────────────────────────
      case 'stormy':
      case 'thunderstorm':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF010204), Color(0xFF030608), Color(0xFF05090E), Color(0xFF080D16)],
            accentColor: Color(0xFFFFEE58),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'stormy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF0D0D14), Color(0xFF111620), Color(0xFF141C2E), Color(0xFF18223C)],
          accentColor: Color(0xFFFFEE58),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'stormy',
        );

    // ── SNOWY / COLD ───────────────────────────────────────────────────────
      case 'snowy':
      case 'cold':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF050A12), Color(0xFF0A1220), Color(0xFF0E1C30), Color(0xFF122440)],
            accentColor: Color(0xFFAAD4F5),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'snowy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF2C4A6E), Color(0xFF3A6090), Color(0xFF4A7EB8), Color(0xFF7AAAD8)],
          accentColor: Color(0xFFAAD4F5),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'snowy',
        );

    // ── WINDY ──────────────────────────────────────────────────────────────
      case 'windy':
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF040810), Color(0xFF081020), Color(0xFF0C1830), Color(0xFF102040)],
            accentColor: Color(0xFF70C4EC),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'windy',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF1A3A6A), Color(0xFF2050A0), Color(0xFF2E6EC0), Color(0xFF4A90D8)],
          accentColor: Color(0xFF70C4EC),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'windy',
        );

    // ── DEFAULT ────────────────────────────────────────────────────────────
      default:
        if (isNight) {
          return const WeatherConditionTheme(
            skyGradient: [Color(0xFF020408), Color(0xFF060C18), Color(0xFF0A1428), Color(0xFF0E1C38)],
            accentColor: Color(0xFFB0C4DE),
            cardColor: Color(0x30FFFFFF),
            textPrimary: Colors.white,
            textSecondary: Color(0xCCFFFFFF),
            iconAssetHint: 'sunny',
          );
        }
        return const WeatherConditionTheme(
          skyGradient: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFF7EC8F8)],
          accentColor: Color(0xFFFFD54F),
          cardColor: Color(0x33FFFFFF),
          textPrimary: Colors.white,
          textSecondary: Color(0xEEFFFFFF),
          iconAssetHint: 'sunny',
        );
    }
  }
}