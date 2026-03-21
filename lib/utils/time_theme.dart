// lib/utils/time_theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// Time-aware colour palette
// Day    05–18  → vivid sky blue
// Night  19–04  → deep navy / midnight
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

enum _Period { day, night }

_Period _period([int? hour]) {
  final h = hour ?? DateTime.now().hour;
  if (h >= 5 && h < 19) return _Period.day;
  return _Period.night;
}

class TimeTheme {
  final List<Color> bgGradient;
  final Color       accent;
  final Color       cardBg;
  final Color       statusBar;
  final Color       appBarBg;
  final Color       sheetGrad1;
  final Color       sheetGrad2;
  final Color       divider;

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
    appBarBg   : Color(0xB37ACCF2),
    sheetGrad1 : Color(0xFF2AAFF2),
    sheetGrad2 : Color(0xFF1278C8),
    divider    : Color(0x33FFFFFF),
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
      case _Period.night: return _night;
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

  /// Label shown in UI
  String get periodLabel {
    switch (_period()) {
      case _Period.night: return 'Night';
      default:            return 'Day';
    }
  }
}