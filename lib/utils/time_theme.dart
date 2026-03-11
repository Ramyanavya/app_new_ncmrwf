// lib/utils/time_theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// Time-aware colour palette
// Dawn   05–07  → warm pink-amber sunrise
// Day    08–17  → vivid sky blue (original look)
// Dusk   18–20  → orange-purple sunset
// Night  21–04  → deep navy / midnight
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

enum _Period { dawn, day, dusk, night }

_Period _period([int? hour]) {
  final h = hour ?? DateTime.now().hour;
  if (h >= 5  && h < 8)  return _Period.dawn;
  if (h >= 8  && h < 18) return _Period.day;
  if (h >= 18 && h < 21) return _Period.dusk;
  return _Period.night;
}

class TimeTheme {
  final List<Color> bgGradient;   // 3-stop background gradient
  final Color       accent;       // amber / golden highlight
  final Color       cardBg;       // frosted card fill (with opacity)
  final Color       statusBar;    // system-ui status bar tint
  final Color       appBarBg;     // app-bar blur base
  final Color       sheetGrad1;   // bottom-sheet top colour
  final Color       sheetGrad2;   // bottom-sheet bottom colour
  final Color       divider;      // divider / border hint

  const TimeTheme._({
    required this.bgGradient,
    required this.accent,
    required this.cardBg,
    required this.statusBar,
    required this.appBarBg,
    required this.sheetGrad1,
    required this.sheetGrad2,
    required this.divider,
  });

  // ── DAY ────────────────────────────────────────────────────────────────────
  static const _day = TimeTheme._(
    bgGradient : [Color(0xFF6DD0F7), Color(0xFF42B8F0), Color(0xFF2196E8)],
    accent     : Color(0xFFFFC107),
    cardBg     : Color(0x38FFFFFF),
    statusBar  : Colors.transparent,
    appBarBg   : Color(0xB342B8F0),
    sheetGrad1 : Color(0xFF2AAFF2),
    sheetGrad2 : Color(0xFF1278C8),
    divider    : Color(0x33FFFFFF),
  );

  // ── DAWN ───────────────────────────────────────────────────────────────────
  static const _dawn = TimeTheme._(
    bgGradient : [Color(0xFF2A1A4A), Color(0xFFB05068), Color(0xFFF08850)],
    accent     : Color(0xFFFFCC80),
    cardBg     : Color(0x35FFFFFF),
    statusBar  : Colors.transparent,
    appBarBg   : Color(0xAA2A1A4A),
    sheetGrad1 : Color(0xFF7A3050),
    sheetGrad2 : Color(0xFF3A1830),
    divider    : Color(0x40FFFFFF),
  );

  // ── DUSK ───────────────────────────────────────────────────────────────────
  static const _dusk = TimeTheme._(
    bgGradient : [Color(0xFF1A0A2E), Color(0xFF7A3040), Color(0xFFE07840)],
    accent     : Color(0xFFFFAB40),
    cardBg     : Color(0x35FFFFFF),
    statusBar  : Colors.transparent,
    appBarBg   : Color(0xAA1A0A2E),
    sheetGrad1 : Color(0xFF6A2840),
    sheetGrad2 : Color(0xFF2A1020),
    divider    : Color(0x40FFFFFF),
  );

  // ── NIGHT ──────────────────────────────────────────────────────────────────
  static const _night = TimeTheme._(
    bgGradient : [Color(0xFF020510), Color(0xFF050D20), Color(0xFF0A1535)],
    accent     : Color(0xFF90CAF9),
    cardBg     : Color(0x28FFFFFF),
    statusBar  : Colors.transparent,
    appBarBg   : Color(0xCC020510),
    sheetGrad1 : Color(0xFF0D1E40),
    sheetGrad2 : Color(0xFF040A18),
    divider    : Color(0x30FFFFFF),
  );

  /// Returns the correct palette for the current (or supplied) hour.
  static TimeTheme of([int? hour]) {
    switch (_period(hour)) {
      case _Period.dawn:  return _dawn;
      case _Period.dusk:  return _dusk;
      case _Period.night: return _night;
      case _Period.day:
      default:            return _day;
    }
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  /// 3-stop LinearGradient (top → bottom)
  LinearGradient get linearGradient => LinearGradient(
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
    colors: bgGradient,
    stops: const [0.0, 0.5, 1.0],
  );

  /// Label shown in UI (optional, for debugging / accessibility)
  String get periodLabel {
    switch (_period()) {
      case _Period.dawn:  return 'Dawn';
      case _Period.dusk:  return 'Dusk';
      case _Period.night: return 'Night';
      default:            return 'Day';
    }
  }
}