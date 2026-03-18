// lib/screens/forecast_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../providers/weather_provider.dart';
import '../providers/app_providers.dart';
import '../models/weather_model.dart';
import '../services/translator_service.dart';
import '../utils/app_strings.dart';
import '../utils/translated_text.dart';
import '../utils/weather_condition_theme.dart';
import '../utils/weather_icon_painter.dart';
import '../widgets/location_search.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Time helpers  — always derive IST from UTC so it's correct on any device
// ─────────────────────────────────────────────────────────────────────────────
enum _TimeOfDay { dawn, day, dusk, night }

_TimeOfDay _timeOfDay(int hour) {
  if (hour >= 5  && hour < 8)  return _TimeOfDay.dawn;
  if (hour >= 8  && hour < 17) return _TimeOfDay.day;
  if (hour >= 17 && hour < 19) return _TimeOfDay.dusk;
  return _TimeOfDay.night;
}

DateTime _nowIST() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

bool _isNightIST() {
  final h = _nowIST().hour;
  return h >= 19 || h < 5;
}

bool _slotIsNight(String utcIso) {
  final dt = DateTime.tryParse(utcIso);
  if (dt == null) return false;
  final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  return ist.hour >= 19 || ist.hour < 5;
}

// ─────────────────────────────────────────────────────────────────────────────
// Condition helpers
// ─────────────────────────────────────────────────────────────────────────────
enum _ConditionType { sunny, partlyCloudy, cloudy, rainy, stormy, snowy, windy }

_ConditionType _conditionType(String c) {
  final s = c.toLowerCase();
  if (s.contains('thunder') || s.contains('storm'))                           return _ConditionType.stormy;
  if (s.contains('snow')    || s.contains('cold'))                             return _ConditionType.snowy;
  if (s.contains('rain')    || s.contains('drizzle') || s.contains('shower')) return _ConditionType.rainy;
  if (s.contains('wind'))                                                       return _ConditionType.windy;
  if (s.contains('partly')  || s.contains('partial'))                          return _ConditionType.partlyCloudy;
  if (s.contains('cloud')   || s.contains('overcast') ||
      s.contains('haze')    || s.contains('mist')     || s.contains('fog'))   return _ConditionType.cloudy;
  if (s.contains('sun')     || s.contains('clear')    || s.contains('hot') ||
      s.contains('warm')    || s.contains('fair'))                             return _ConditionType.sunny;
  return _ConditionType.partlyCloudy;
}

// ─────────────────────────────────────────────────────────────────────────────
// Background helpers
// ─────────────────────────────────────────────────────────────────────────────
String _bgAsset(_ConditionType ct, _TimeOfDay tod) {
  switch (ct) {
    case _ConditionType.sunny:
      switch (tod) {
        case _TimeOfDay.dawn:  return 'assets/backgrounds/sunny_dawn.jpg';
        case _TimeOfDay.dusk:  return 'assets/backgrounds/sunny_dusk.jpg';
        case _TimeOfDay.night: return 'assets/backgrounds/sunny_night.jpg';
        default:               return 'assets/backgrounds/sunny_day.jpg';
      }
    case _ConditionType.partlyCloudy:
    case _ConditionType.cloudy:
      return tod == _TimeOfDay.night ? 'assets/backgrounds/cloudy_night.jpg'
          : 'assets/backgrounds/cloudy_day.jpg';
    case _ConditionType.rainy:
      return tod == _TimeOfDay.night ? 'assets/backgrounds/rainy_night.jpg'
          : 'assets/backgrounds/rainy_day.jpg';
    case _ConditionType.stormy:
      return tod == _TimeOfDay.night ? 'assets/backgrounds/stormy_night.jpg'
          : 'assets/backgrounds/stormy_day.jpg';
    case _ConditionType.snowy:
      return tod == _TimeOfDay.night ? 'assets/backgrounds/snowy_night.jpg'
          : 'assets/backgrounds/snowy_day.jpg';
    case _ConditionType.windy:
      return 'assets/backgrounds/windy_day.jpg';
  }
}

List<Color> _bgOverlay(_ConditionType ct, _TimeOfDay tod) {
  if (tod == _TimeOfDay.night)
    return [Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.75)];
  switch (ct) {
    case _ConditionType.sunny:
      return [Colors.black.withOpacity(0.08), Colors.black.withOpacity(0.18), Colors.black.withOpacity(0.55)];
    case _ConditionType.rainy:
      return [Colors.black.withOpacity(0.30), Colors.black.withOpacity(0.40), Colors.black.withOpacity(0.65)];
    case _ConditionType.stormy:
      return [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.75)];
    default:
      return [Colors.black.withOpacity(0.12), Colors.black.withOpacity(0.25), Colors.black.withOpacity(0.60)];
  }
}

List<Color> _fallbackGradient(_ConditionType ct, _TimeOfDay tod) {
  if (tod == _TimeOfDay.night)
    return const [Color(0xFF020408), Color(0xFF060C18), Color(0xFF0A1428)];
  switch (ct) {
    case _ConditionType.sunny:
      return tod == _TimeOfDay.dusk
          ? const [Color(0xFF1A0A2E), Color(0xFF6B2D3E), Color(0xFFE8833A)]
          : const [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF64B5F6)];
    case _ConditionType.rainy:  return const [Color(0xFF1A2A40), Color(0xFF1E3A5C), Color(0xFF2A5A8A)];
    case _ConditionType.stormy: return const [Color(0xFF0D0D14), Color(0xFF141C2E), Color(0xFF18223C)];
    case _ConditionType.snowy:  return const [Color(0xFF2C4A6E), Color(0xFF3A6090), Color(0xFF7AAAD8)];
    case _ConditionType.cloudy: return const [Color(0xFF3A5060), Color(0xFF4A6880), Color(0xFF6A8A9A)];
    default:                    return const [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted-glass card
// ─────────────────────────────────────────────────────────────────────────────
class _FrostCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius, blurSigma, bgOpacity;
  final Color? tint;
  const _FrostCard({required this.child, this.padding = const EdgeInsets.all(18),
    this.radius = 22, this.blurSigma = 18, this.bgOpacity = 0.18, this.tint});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: (tint ?? Colors.white).withOpacity(bgOpacity + 0.06),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
        ),
        child: child,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Temperature trend painter
// ─────────────────────────────────────────────────────────────────────────────
class _TempPainter extends CustomPainter {
  final List<TrendPoint> trend;
  final double mn, mx, range;
  final int sel;
  final Color accent;
  _TempPainter({required this.trend, required this.mn, required this.mx,
    required this.range, required this.sel, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty || range == 0) return;
    const pH = 24.0, pV = 20.0;
    final gW = size.width - pH * 2;
    final gH = size.height - pV * 2 - 20;
    final pts = <Offset>[];
    for (int i = 0; i < trend.length; i++) {
      pts.add(Offset(pH + (i / (trend.length - 1)) * gW,
          pV + (1 - (trend[i].temperatureC - mn) / range) * gH));
    }
    final fill = Path()..moveTo(pts.first.dx, size.height - 20);
    for (var p in pts) fill.lineTo(p.dx, p.dy);
    fill.lineTo(pts.last.dx, size.height - 20);
    fill.close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [accent.withOpacity(.30), Colors.transparent])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final c1 = Offset((pts[i-1].dx+pts[i].dx)/2, pts[i-1].dy);
      final c2 = Offset((pts[i-1].dx+pts[i].dx)/2, pts[i].dy);
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()..color = accent..strokeWidth = 2.2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    for (int i = 0; i < pts.length; i++) {
      final isSel = i == sel;
      if (isSel) {
        canvas.drawLine(Offset(pts[i].dx, 0), Offset(pts[i].dx, gH + pV),
            Paint()..color = accent.withOpacity(.25)..strokeWidth = 1);
        canvas.drawCircle(pts[i], 9, Paint()..color = accent.withOpacity(.20));
        canvas.drawCircle(pts[i], 5, Paint()..color = accent);
        canvas.drawCircle(pts[i], 2.5, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(pts[i], 3.5, Paint()..color = accent.withOpacity(.55));
        canvas.drawCircle(pts[i], 2, Paint()..color = Colors.white.withOpacity(.7));
      }
      final tp = TextPainter(
          text: TextSpan(text: "${trend[i].temperatureC.toStringAsFixed(0)}\u00b0",
              style: TextStyle(color: isSel ? accent : Colors.white60,
                  fontSize: isSel ? 11 : 9, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width/2, pts[i].dy - 17));
      final dp = TextPainter(
          text: TextSpan(text: trend[i].day,
              style: TextStyle(color: isSel ? accent : Colors.white30,
                  fontSize: 9, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400)),
          textDirection: TextDirection.ltr)..layout();
      dp.paint(canvas, Offset(pts[i].dx - dp.width/2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant _TempPainter o) => o.sel != sel || o.trend != trend;
}

// ─────────────────────────────────────────────────────────────────────────────
// Temperature bar painter
// ─────────────────────────────────────────────────────────────────────────────
class _TempBarPainter extends CustomPainter {
  final List<double> positions;
  final Color accent;
  const _TempBarPainter({required this.positions, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final itemW = size.width / positions.length;
    final pts = <Offset>[];
    for (int i = 0; i < positions.length; i++) {
      pts.add(Offset(itemW * i + itemW / 2,
          size.height * 0.5 - (positions[i] - 0.5) * (size.height * 0.7)));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final c1 = Offset((pts[i-1].dx+pts[i].dx)/2, pts[i-1].dy);
      final c2 = Offset((pts[i-1].dx+pts[i].dx)/2, pts[i].dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
          colors: [const Color(0xFF64B5F6), accent, const Color(0xFFFF7043)],
          stops: const [0.0, 0.5, 1.0])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, Paint()..color = accent.withOpacity(0.8));
      canvas.drawCircle(p, 2,   Paint()..color = Colors.white.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _TempBarPainter o) => o.positions != positions;
}

// ─────────────────────────────────────────────────────────────────────────────
// Compass painter
// ─────────────────────────────────────────────────────────────────────────────
class _CompassPainter extends CustomPainter {
  final double windDeg;
  final Color accent;
  _CompassPainter({required this.windDeg, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 4;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white.withOpacity(0.08));
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white.withOpacity(0.22)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(cx, cy), r * 0.72,
        Paint()..color = Colors.white.withOpacity(0.05));
    canvas.drawCircle(Offset(cx, cy), r * 0.72,
        Paint()..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke..strokeWidth = 1);

    for (int i = 0; i < 72; i++) {
      final angle  = i * math.pi / 36;
      final isMain = i % 18 == 0;
      final isMed  = i % 9  == 0;
      final inner  = r * (isMain ? 0.80 : isMed ? 0.84 : 0.88);
      final cos = math.cos(angle - math.pi / 2);
      final sin = math.sin(angle - math.pi / 2);
      canvas.drawLine(
          Offset(cx + inner * cos, cy + inner * sin),
          Offset(cx + r * 0.96 * cos, cy + r * 0.96 * sin),
          Paint()
            ..color = Colors.white.withOpacity(isMain ? 0.7 : isMed ? 0.4 : 0.18)
            ..strokeWidth = isMain ? 1.5 : isMed ? 1.0 : 0.6);
    }

    final cardFontSize = (r * 0.16).clamp(8.0, 14.0);
    final cardials = {0.0: 'N', math.pi / 2: 'E', math.pi: 'S', 3 * math.pi / 2: 'W'};
    for (final e in cardials.entries) {
      final a = e.key - math.pi / 2;
      final tp = TextPainter(
          text: TextSpan(text: e.value, style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: cardFontSize, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(
          cx + r * 0.60 * math.cos(a) - tp.width / 2,
          cy + r * 0.60 * math.sin(a) - tp.height / 2));
    }

    final interFontSize = (r * 0.10).clamp(6.0, 11.0);
    final inter = {45.0: 'NE', 135.0: 'SE', 225.0: 'SW', 315.0: 'NW'};
    for (final e in inter.entries) {
      final a = e.key * math.pi / 180 - math.pi / 2;
      final tp = TextPainter(
          text: TextSpan(text: e.value, style: GoogleFonts.dmSans(
              color: Colors.white54, fontSize: interFontSize, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(
          cx + r * 0.60 * math.cos(a) - tp.width / 2,
          cy + r * 0.60 * math.sin(a) - tp.height / 2));
    }

    final arrowAngle = windDeg * math.pi / 180 - math.pi / 2;
    final arrowLen   = r * 0.44;
    final tipX = cx + arrowLen * math.cos(arrowAngle);
    final tipY = cy + arrowLen * math.sin(arrowAngle);
    final tailX = cx - arrowLen * 0.55 * math.cos(arrowAngle);
    final tailY = cy - arrowLen * 0.55 * math.sin(arrowAngle);

    canvas.drawLine(Offset(tailX, tailY), Offset(tipX, tipY),
        Paint()..color = Colors.white..strokeWidth = 2.5..strokeCap = StrokeCap.round);

    final headLen = (r * 0.22).clamp(8.0, 18.0);
    const ha = 0.42;
    final head = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(tipX - headLen * math.cos(arrowAngle - ha), tipY - headLen * math.sin(arrowAngle - ha))
      ..lineTo(tipX - headLen * math.cos(arrowAngle + ha), tipY - headLen * math.sin(arrowAngle + ha))
      ..close();
    canvas.drawPath(head, Paint()
      ..shader = LinearGradient(colors: [accent, Colors.white])
          .createShader(Rect.fromLTWH(tipX - headLen, tipY - headLen, headLen * 2, headLen * 2)));

    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), 4,
        Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter o) => o.windDeg != windDeg;
}

// ─────────────────────────────────────────────────────────────────────────────
// Precipitation bar painter
// ─────────────────────────────────────────────────────────────────────────────
class _PrecipBarPainter extends CustomPainter {
  final List<HourlyWeather> hrs;
  final double maxR;
  final double slotW;
  const _PrecipBarPainter({required this.hrs, required this.maxR, required this.slotW});

  @override
  void paint(Canvas canvas, Size size) {
    if (hrs.isEmpty) return;
    const lineColor = Color(0xFF5B9BD5);
    const dotColor  = Color(0xFF4A90D9);
    const lineY     = 9.0;
    const dotR      = 5.0;

    final firstX = slotW / 2;
    final lastX  = slotW * (hrs.length - 1) + slotW / 2;
    canvas.drawLine(
      Offset(firstX, lineY),
      Offset(lastX,  lineY),
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    for (int i = 0; i < hrs.length; i++) {
      final cx = slotW * i + slotW / 2;
      canvas.drawCircle(Offset(cx, lineY), dotR + 1.5,
          Paint()..color = Colors.white.withOpacity(0.15));
      canvas.drawCircle(Offset(cx, lineY), dotR,
          Paint()..color = dotColor);
      canvas.drawCircle(Offset(cx, lineY), 2.0,
          Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _PrecipBarPainter o) =>
      o.hrs != hrs || o.slotW != slotW;
}

// ─────────────────────────────────────────────────────────────────────────────
// Wind bar painter
// ─────────────────────────────────────────────────────────────────────────────
class _WindBarPainter extends CustomPainter {
  final List<HourlyWeather> hrs;
  final Color accent;
  const _WindBarPainter({required this.hrs, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (hrs.isEmpty) return;
    final maxS = hrs.map((h) => h.windSpeedKmh).fold(0.0, math.max).clamp(1.0, double.infinity);
    final bW   = size.width / hrs.length;
    for (int i = 0; i < hrs.length; i++) {
      final frac = (hrs[i].windSpeedKmh / maxS).clamp(0.1, 1.0);
      final barH = frac * (size.height - 10);
      final x = i * bW + bW * 0.25, y = size.height - barH;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, y, bW * 0.5, barH),
            topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [accent.withOpacity(0.5), accent])
            .createShader(Rect.fromLTWH(x, y, bW * 0.5, barH)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WindBarPainter o) => o.hrs != hrs;
}

// ─────────────────────────────────────────────────────────────────────────────
// Wind week fill painter
// ─────────────────────────────────────────────────────────────────────────────
class _WindWeekFillPainter extends CustomPainter {
  final List<double> speeds;
  final double minS, range;
  final Color accent;
  const _WindWeekFillPainter({
    required this.speeds,
    required this.minS,
    required this.range,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (speeds.isEmpty) return;
    const pV = 8.0;
    final itemW = size.width / speeds.length;
    final chartH = size.height - pV * 2 - 20;

    final pts = <Offset>[];
    for (int i = 0; i < speeds.length; i++) {
      final norm = range == 0 ? 0.5 : (speeds[i] - minS) / range;
      pts.add(Offset(itemW * i + itemW / 2, pV + (1 - norm) * chartH));
    }

    final fill = Path()..moveTo(pts.first.dx, size.height - 20);
    for (final p in pts) fill.lineTo(p.dx, p.dy);
    fill.lineTo(pts.last.dx, size.height - 20);
    fill.close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.28), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final c1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final c2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()
      ..color = accent.withOpacity(0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 3.0,
          Paint()..color = accent.withOpacity(i == 0 ? 1.0 : 0.6));
      canvas.drawCircle(pts[i], 1.5,
          Paint()..color = Colors.white.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _WindWeekFillPainter o) => o.speeds != speeds;
}

// ─────────────────────────────────────────────────────────────────────────────
// Active-day model
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveDay {
  final double temperatureC, feelsLikeC, windSpeedKmh, humidityPercent, pressureHpa;
  final double tempMin, tempMax, rainMm;
  final String windDirection, condition, dayLabel;
  const _ActiveDay({
    required this.temperatureC, required this.feelsLikeC, required this.windSpeedKmh,
    required this.windDirection, required this.humidityPercent, required this.pressureHpa,
    required this.condition, required this.dayLabel,
    this.tempMin = 0, this.tempMax = 0, this.rainMm = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab enum
// ─────────────────────────────────────────────────────────────────────────────
enum _MainTab { temperature, precipitation, wind }

// ─────────────────────────────────────────────────────────────────────────────
// AQI — CPCB live data via iit_rss_feed_with_coordinates
// ─────────────────────────────────────────────────────────────────────────────
class _AqiData {
  final int aqi;
  final String label, description, stationName, predominantParameter;
  _AqiData({
    required this.aqi,
    required this.label,
    required this.description,
    this.stationName = '',
    this.predominantParameter = '',
  });

  static String _aqiLabel(int v) {
    if (v <= 50)  return 'Good';
    if (v <= 100) return 'Satisfactory';
    if (v <= 200) return 'Moderate';
    if (v <= 300) return 'Poor';
    if (v <= 400) return 'Very Poor';
    return 'Severe';
  }

  static String _aqiDesc(int v) {
    if (v <= 50)  return 'Minimal impact. Air quality is good for all activities.';
    if (v <= 100) return 'Minor breathing discomfort for sensitive people.';
    if (v <= 200) return 'Breathing discomfort for asthma patients and heart disease.';
    if (v <= 300) return 'Breathing discomfort for most people on prolonged exposure.';
    if (v <= 400) return 'Respiratory illness on prolonged exposure. Avoid outdoor activity.';
    return 'Health emergency. Avoid all outdoor exposure.';
  }

  static Color aqiColor(int v) {
    if (v <= 50)  return const Color(0xFF00C853);
    if (v <= 100) return const Color(0xFF64DD17);
    if (v <= 200) return const Color(0xFFFFD600);
    if (v <= 300) return const Color(0xFFFF6D00);
    if (v <= 400) return const Color(0xFFD50000);
    return const Color(0xFF6A1B9A);
  }

  static _AqiData fromCpcbFeed(Map<String, dynamic> json, double lat, double lon) {
    final countries = json['country'] as List? ?? [];
    double bestDist = double.infinity;
    int bestAqi = 0;
    String bestStation = '';
    String bestPollutant = '';

    for (final state in countries) {
      final cities = (state['citiesInState'] as List?) ?? [];
      for (final city in cities) {
        final stations = (city['stationsInCity'] as List?) ?? [];
        for (final station in stations) {
          final aqiRaw = station['airQualityIndexValue'];
          if (aqiRaw == null || aqiRaw == 'NA') continue;
          final aqiVal = (aqiRaw as num?)?.toInt() ?? 0;
          if (aqiVal <= 0) continue;

          final sLat = double.tryParse(station['latitude']?.toString() ?? '');
          final sLon = double.tryParse(station['longitude']?.toString() ?? '');
          if (sLat == null || sLon == null) continue;

          final dist = _haversineKm(lat, lon, sLat, sLon);
          if (dist < bestDist) {
            bestDist = dist;
            bestAqi = aqiVal;
            bestStation = station['stationName']?.toString() ?? '';
            bestPollutant = station['predominantParameter']?.toString() ?? '';
          }
        }
      }
    }

    if (bestAqi == 0) {
      return _AqiData(aqi: 0, label: '--', description: 'No nearby CPCB station data');
    }

    return _AqiData(
      aqi: bestAqi,
      label: _aqiLabel(bestAqi),
      description: _aqiDesc(bestAqi),
      stationName: bestStation,
      predominantParameter: bestPollutant,
    );
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

// ─────────────────────────────────────────────────────────────────────────────
// Temperature range bar
// ─────────────────────────────────────────────────────────────────────────────
class _TempRangeBar extends StatelessWidget {
  final double min, max, globalMin, globalMax;
  const _TempRangeBar({required this.min, required this.max,
    required this.globalMin, required this.globalMax});
  @override
  Widget build(BuildContext context) {
    final range = (globalMax - globalMin).clamp(1.0, double.infinity);
    final s = ((min - globalMin) / range).clamp(0.0, 1.0);
    final e = ((max - globalMin) / range).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return Stack(children: [
        Container(height: 6, decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(3))),
        Positioned(left: w * s, width: w * (e - s), top: 0,
            child: Container(height: 6, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                    colors: [Color(0xFF64B5F6), Color(0xFFFFB300)])))),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> with TickerProviderStateMixin {
  int _selDay = 0, _todayIndex = 0;
  bool _entryAnimationPlayed = false;
  String _pincode = '';
  bool _pincodeLoading = false;
  double? _lastPinLat, _lastPinLon;
  DateTime? _lastKnownDate;

  String? _aiDescription;
  bool _aiLoading = false;
  String? _lastAiKey;

  // ── Condition insight state (AI-generated) ─────────────────────────────────
  String? _conditionTitle;
  String? _conditionBody;
  String? _conditionExtra;
  bool    _conditionLoading = false;
  String? _lastConditionKey;

  // ── AQI state ──────────────────────────────────────────────────────────────
  _AqiData? _aqiData;
  bool _aqiLoading = false;
  double? _lastAqiLat, _lastAqiLon;

  _MainTab _mainTab = _MainTab.temperature;

  AnimationController? _entryFadeC, _entrySlideC, _daySwitchC;
  Animation<double>?   _entryFadeA, _daySwitchA;
  Animation<Offset>?   _entrySlideA;

  Animation<double> get entryFade  => _entryFadeA!;
  Animation<Offset> get entrySlide => _entrySlideA!;
  Animation<double> get daySwitch  => _daySwitchA!;

  @override
  void initState() {
    super.initState();
    _entryFadeC  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFadeA  = CurvedAnimation(parent: _entryFadeC!, curve: Curves.easeIn);
    _entrySlideC = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _entrySlideA = Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entrySlideC!, curve: Curves.easeOut));
    _daySwitchC  = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _daySwitchA  = CurvedAnimation(parent: _daySwitchC!, curve: Curves.easeInOut);
    _daySwitchC!.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wp = context.read<WeatherProvider>();
      _lastKnownDate = DateTime.now();
      if (wp.status == WeatherStatus.loaded) {
        _alignToToday(wp);
        _playEntry();
        _fetchPincodeFromProvider(wp);
        _fetchAqi(wp.latitude, wp.longitude);
        _triggerConditionInsight(wp);
      } else if (wp.status == WeatherStatus.initial) {
        wp.fetchWeatherForCurrentLocation();
      }
      wp.addListener(_onWeatherChanged);
      _scheduleMidnightCheck();
    });
  }

  void _scheduleMidnightCheck() {
    Future.delayed(const Duration(minutes: 1), () {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastKnownDate != null && _ds(now) != _ds(_lastKnownDate!)) {
        _lastKnownDate = now;
        final wp = context.read<WeatherProvider>();
        _alignToToday(wp);
        wp.refresh();
      } else {
        _lastKnownDate = now;
      }
      _scheduleMidnightCheck();
    });
  }

  void _onWeatherChanged() {
    if (!mounted) return;
    final wp = context.read<WeatherProvider>();
    if (wp.status == WeatherStatus.loaded) {
      _alignToToday(wp);
      _playEntry();
      _fetchPincodeFromProvider(wp);
      _fetchAqi(wp.latitude, wp.longitude);
      _triggerConditionInsight(wp);
    }
  }

  @override
  void dispose() {
    try { context.read<WeatherProvider>().removeListener(_onWeatherChanged); } catch (_) {}
    _entryFadeC?.dispose();
    _entrySlideC?.dispose();
    _daySwitchC?.dispose();
    super.dispose();
  }

  // ── CPCB AQI fetch ─────────────────────────────────────────────────────────
  Future<void> _fetchAqi(double lat, double lon) async {
    if (_lastAqiLat == lat && _lastAqiLon == lon && _aqiData != null) return;
    _lastAqiLat = lat;
    _lastAqiLon = lon;
    if (!mounted) return;
    setState(() { _aqiLoading = true; });

    try {
      final res = await http.get(
        Uri.parse('https://airquality.cpcb.gov.in/caaqms/iit_rss_feed_with_coordinates'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final aqi = _AqiData.fromCpcbFeed(data, lat, lon);
        if (mounted) setState(() { _aqiData = aqi; _aqiLoading = false; });
      } else {
        debugPrint('[CPCB AQI] ${res.statusCode}');
        if (mounted) setState(() => _aqiLoading = false);
      }
    } catch (e) {
      debugPrint('[CPCB AQI] $e');
      if (mounted) setState(() => _aqiLoading = false);
    }
  }

  // ── Claude (Anthropic) weather description ────────────────────────────────
  Future<void> _fetchAiDescription({
    required String location,
    required String condition,
    required double tempC,
    required double humidity,
    required double windKmh,
    required String windDir,
    required double feelsLikeC,
  }) async {
    final cacheKey = '$location|$condition|${tempC.toStringAsFixed(0)}';
    if (_lastAiKey == cacheKey && _aiDescription != null) return;
    _lastAiKey = cacheKey;
    if (!mounted) return;
    setState(() { _aiLoading = true; _aiDescription = null; });

    const anthropicKey = 'YOUR_ANTHROPIC_API_KEY';

    final prompt =
        'You are a friendly local weather assistant. '
        'Give a concise, natural 2-sentence description of the current weather '
        'for $location. '
        'Conditions: $condition, ${tempC.toStringAsFixed(0)}°C, '
        'feels like ${feelsLikeC.toStringAsFixed(0)}°C, '
        'humidity ${humidity.toStringAsFixed(0)}%, '
        'wind $windDir at ${windKmh.toStringAsFixed(0)} km/h. '
        'Include a brief practical tip for residents. Keep it under 50 words. '
        'Reply with only the description — no headings, no bullet points.';

    try {
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 150,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final contentList = data['content'] as List? ?? [];
        final text = contentList
            .whereType<Map<String, dynamic>>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String? ?? '')
            .join(' ')
            .trim();
        if (mounted) setState(() { _aiDescription = text; _aiLoading = false; });
      } else {
        debugPrint('[Claude] ${res.statusCode}: ${res.body}');
        if (mounted) setState(() => _aiLoading = false);
      }
    } catch (e) {
      debugPrint('[Claude] $e');
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  // ── Trigger condition insight safely (outside build) ─────────────────────
  void _triggerConditionInsight(WeatherProvider wp) {
    if (!mounted || wp.currentWeather == null) return;
    final day = _getActiveDay(wp);
    _fetchConditionInsight(
      condition:  day.condition,
      tempC:      day.temperatureC,
      feelsLikeC: day.feelsLikeC,
      windKmh:    day.windSpeedKmh,
      windDir:    day.windDirection,
      humidity:   day.humidityPercent,
      rainMm:     day.rainMm,
      location:   wp.placeName.isEmpty ? 'your location' : wp.placeName,
    );
  }

  // ── NEW: Condition insight from Claude (title + body + extra) ─────────────
  Future<void> _fetchConditionInsight({
    required String condition,
    required double tempC,
    required double feelsLikeC,
    required double windKmh,
    required String windDir,
    required double humidity,
    required double rainMm,
    required String location,
  }) async {
    final cacheKey =
        '$condition|${tempC.toStringAsFixed(0)}|${feelsLikeC.toStringAsFixed(0)}|'
        '${windKmh.toStringAsFixed(0)}|$windDir|${humidity.toStringAsFixed(0)}|'
        '${rainMm.toStringAsFixed(1)}';
    if (_lastConditionKey == cacheKey &&
        _conditionTitle != null &&
        _conditionBody  != null) return;
    _lastConditionKey = cacheKey;
    if (!mounted) return;
    setState(() {
      _conditionLoading = true;
      _conditionTitle   = null;
      _conditionBody    = null;
      _conditionExtra   = null;
    });

    const anthropicKey = 'YOUR_ANTHROPIC_API_KEY';

    final prompt =
        'You are a weather assistant embedded in a weather app. '
        'Given these current conditions for $location:\n'
        '  Condition: $condition\n'
        '  Temperature: ${tempC.toStringAsFixed(1)}°C\n'
        '  Feels like: ${feelsLikeC.toStringAsFixed(1)}°C\n'
        '  Humidity: ${humidity.toStringAsFixed(0)}%\n'
        '  Wind: $windDir at ${windKmh.toStringAsFixed(0)} km/h\n'
        '  Rainfall: ${rainMm.toStringAsFixed(1)} mm\n\n'
        'Respond ONLY with a valid JSON object (no markdown, no extra keys) like:\n'
        '{\n'
        '  "title": "<2-4 word condition label, e.g. Sunny and Warm>",\n'
        '  "body": "<1 sentence safety or comfort tip for residents, max 20 words>",\n'
        '  "extra": "<1 concise data point to highlight, max 10 words, or empty string>"\n'
        '}\n'
        'Keep the tone friendly and practical.';

    try {
      final res = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 150,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data        = json.decode(res.body) as Map<String, dynamic>;
        final contentList = data['content'] as List? ?? [];
        final rawText = contentList
            .whereType<Map<String, dynamic>>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String? ?? '')
            .join(' ')
            .trim();

        // Strip any accidental markdown fences
        final cleaned = rawText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = json.decode(cleaned) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _conditionTitle   = (parsed['title']  as String? ?? '').trim();
            _conditionBody    = (parsed['body']    as String? ?? '').trim();
            _conditionExtra   = (parsed['extra']   as String? ?? '').trim();
            _conditionLoading = false;
          });
        }
      } else {
        debugPrint('[ConditionInsight] ${res.statusCode}: ${res.body}');
        if (mounted) setState(() => _conditionLoading = false);
      }
    } catch (e) {
      debugPrint('[ConditionInsight] $e');
      if (mounted) setState(() => _conditionLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _alignToToday(WeatherProvider wp) {
    if (wp.forecast.isEmpty) return;
    final ts = _ds(DateTime.now());
    int idx = 0;
    for (int i = 0; i < wp.forecast.length; i++) {
      final s = wp.forecast[i].date;
      if ((s.length >= 10 ? s.substring(0, 10) : s) == ts) { idx = i; break; }
    }
    if (!mounted) return;
    setState(() { _todayIndex = idx; if (_selDay < idx) _selDay = idx; });
  }

  String _ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _playEntry() {
    if (_entryAnimationPlayed) return;
    _entryAnimationPlayed = true;
    _entryFadeC?.forward();
    _entrySlideC?.forward();
  }

  void _fetchPincodeFromProvider(WeatherProvider wp) =>
      _fetchPincode(wp.latitude, wp.longitude);

  Future<void> _fetchPincode(double lat, double lon) async {
    if (_lastPinLat == lat && _lastPinLon == lon) return;
    _lastPinLat = lat; _lastPinLon = lon;
    if (!mounted) return;
    setState(() { _pincodeLoading = true; _pincode = ''; });
    try {
      final pm = await placemarkFromCoordinates(lat, lon);
      final c  = pm.isNotEmpty ? pm.first.postalCode ?? '' : '';
      if (!mounted) return;
      setState(() { _pincode = c; _pincodeLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _pincode = ''; _pincodeLoading = false; });
    }
  }

  String _formatDate(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const dy = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${tl(dy[d.weekday-1])}, ${d.day} ${tl(mo[d.month-1])} ${d.year}';
  }

  DateTime _dateForSelDay(WeatherProvider wp) {
    if (wp.forecast.isNotEmpty && _selDay < wp.forecast.length) {
      final p = DateTime.tryParse(wp.forecast[_selDay].date);
      if (p != null) return p;
    }
    return DateTime.now().add(Duration(days: _selDay - _todayIndex));
  }

  void _openSearch() => showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const LocationSearchSheet());

  Future<void> _selectDay(int i) async {
    if (_selDay == i) return;
    await _daySwitchC?.reverse();
    if (!mounted) return;
    setState(() => _selDay = i);
    _daySwitchC?.forward();
    // Fetch new insight for the newly selected day
    final wp = context.read<WeatherProvider>();
    _triggerConditionInsight(wp);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _getActiveDay
  // ─────────────────────────────────────────────────────────────────────────
  _ActiveDay _getActiveDay(WeatherProvider wp) {
    final isToday = _selDay == _todayIndex;
    final cw = wp.currentWeather!;

    if (isToday) {
      return _ActiveDay(
        temperatureC:    wp.liveTemperatureC,
        feelsLikeC:      wp.liveFeelsLikeC,
        windSpeedKmh:    wp.liveWindSpeedKmh,
        windDirection:   cw.windDirection,
        humidityPercent: wp.liveHumidityPercent,
        pressureHpa:     cw.pressureMb.toDouble(),
        condition:       wp.liveCondition,
        dayLabel:        AppStrings.today,
        rainMm:          cw.rainMm,
        tempMin: wp.forecast.isNotEmpty && _todayIndex < wp.forecast.length
            ? wp.forecast[_todayIndex].tempMin : wp.liveTemperatureC,
        tempMax: wp.forecast.isNotEmpty && _todayIndex < wp.forecast.length
            ? wp.forecast[_todayIndex].tempMax : wp.liveTemperatureC,
      );
    }

    if (wp.forecast.isEmpty) {
      return _ActiveDay(
        temperatureC:    wp.liveTemperatureC,
        feelsLikeC:      wp.liveFeelsLikeC,
        windSpeedKmh:    wp.liveWindSpeedKmh,
        windDirection:   cw.windDirection,
        humidityPercent: wp.liveHumidityPercent,
        pressureHpa:     cw.pressureMb.toDouble(),
        condition:       wp.liveCondition,
        dayLabel:        AppStrings.today,
      );
    }

    final df        = wp.forecast[_selDay.clamp(0, wp.forecast.length - 1)];
    final selDate   = _dateForSelDay(wp);
    final dayHourly = wp.hourlyForDate(selDate);
    final src       = dayHourly.isNotEmpty ? dayHourly : wp.hourly;

    double avgWind = 0;
    double avgHum  = 0;
    String dominantWindDir = df.windDirection;

    if (src.isNotEmpty) {
      avgWind = src.map((h) => h.windSpeedKmh).reduce((a, b) => a + b) / src.length;
      avgHum  = src.map((h) => h.humidityPercent).reduce((a, b) => a + b) / src.length;

      final noonSlot = src.reduce((a, b) {
        final dtA = DateTime.tryParse(a.datetime)?.toLocal();
        final dtB = DateTime.tryParse(b.datetime)?.toLocal();
        if (dtA == null || dtB == null) return a;
        return (dtA.hour - 12).abs() < (dtB.hour - 12).abs() ? a : b;
      });
      dominantWindDir = noonSlot.windDirection;
    }

    return _ActiveDay(
      temperatureC:    df.temperatureC,
      feelsLikeC:      df.temperatureC - 1.0,
      windSpeedKmh:    avgWind,
      windDirection:   dominantWindDir,
      humidityPercent: avgHum,
      pressureHpa:     wp.currentWeather?.pressureMb.toDouble() ?? 1013,
      condition:       df.condition,
      dayLabel:        df.day,
      tempMin:         df.tempMin,
      tempMax:         df.tempMax,
      rainMm:          df.rainTotal,
    );
  }

  IconData _condIcon(String cond, {required bool isNight}) {
    final c = cond.toLowerCase();
    if (c.contains('thunder') || c.contains('storm')) return Icons.thunderstorm_rounded;
    if (c.contains('snow') || c.contains('cold'))     return Icons.ac_unit_rounded;
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower'))
      return Icons.water_drop_rounded;
    if (c.contains('wind'))   return Icons.air_rounded;
    if (c.contains('cloud') || c.contains('overcast') || c.contains('haze') ||
        c.contains('mist') || c.contains('fog'))      return Icons.cloud_rounded;
    if (c.contains('partly') || c.contains('partial'))
      return isNight ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
    return isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded;
  }

  IconData _iconNow(String cond)            => _condIcon(cond, isNight: _isNightIST());
  IconData _iconSlot(String cond, String u) => _condIcon(cond, isNight: _slotIsNight(u));

  double _dirDeg(String dir) {
    const m = <String, double>{
      'N': 0, 'NNE': 22.5, 'NE': 45, 'ENE': 67.5, 'E': 90, 'ESE': 112.5,
      'SE': 135, 'SSE': 157.5, 'S': 180, 'SSW': 202.5, 'SW': 225, 'WSW': 247.5,
      'W': 270, 'WNW': 292.5, 'NW': 315, 'NNW': 337.5,
    };
    return m[dir.toUpperCase()] ?? 0.0;
  }
  double _dirRad(String dir) => _dirDeg(dir) * math.pi / 180;

  String _slotLabel(String utcIso) {
    final dt = DateTime.tryParse(utcIso);
    if (dt == null) return '--';
    final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
    final h   = ist.hour;
    if (h == 0)  return '12${tl('AM')}';
    if (h == 12) return '12${tl('PM')}';
    return h < 12 ? '$h${tl('AM')}' : '${h - 12}${tl('PM')}';
  }

  List<HourlyWeather> _buildTodayHourlySlots(WeatherProvider wp) {
    final all = List<HourlyWeather>.from(wp.hourly);
    final now = DateTime.now();
    all.sort((a, b) {
      final dtA = DateTime.tryParse(a.datetime)?.toLocal() ?? now;
      final dtB = DateTime.tryParse(b.datetime)?.toLocal() ?? now;
      return dtA.compareTo(dtB);
    });
    final todayStr = _ds(now);
    DayForecast? todayFc;
    for (final df in wp.forecast) {
      final ds = df.date.length >= 10 ? df.date.substring(0, 10) : df.date;
      if (ds == todayStr) { todayFc = df; break; }
    }
    final tMin = todayFc?.tempMin ?? (wp.liveTemperatureC - 5);
    final tMax = todayFc?.tempMax ?? (wp.liveTemperatureC + 8);

    final nowSlot = _nearestH(all, now);
    final slots = <HourlyWeather>[
      HourlyWeather(
        datetime       : now.toUtc().toIso8601String(),
        temperatureC   : _diurnal(tMin, tMax, now.hour),
        feelsLikeC     : _diurnal(tMin, tMax, now.hour) - 1,
        windSpeedKmh   : nowSlot?.windSpeedKmh    ?? 5,
        windDirection  : nowSlot?.windDirection    ?? 'N',
        humidityPercent: nowSlot?.humidityPercent  ?? 40,
        condition      : nowSlot?.condition        ?? 'Clear',
        rainMm         : nowSlot?.rainMm           ?? 0,
        label          : 'Now',
      ),
    ];
    for (int i = 1; i <= 5; i++) {
      final h  = (now.hour + i) % 24;
      final st = DateTime(now.year, now.month, now.day, h);
      final c  = _nearestH(all, st);
      slots.add(HourlyWeather(
        datetime       : st.toUtc().toIso8601String(),
        temperatureC   : _diurnal(tMin, tMax, h),
        feelsLikeC     : _diurnal(tMin, tMax, h) - 1,
        windSpeedKmh   : c?.windSpeedKmh    ?? 5,
        windDirection  : c?.windDirection    ?? 'N',
        humidityPercent: c?.humidityPercent  ?? 40,
        condition      : c?.condition        ?? 'Clear',
        rainMm         : c?.rainMm           ?? 0,
        label          : '${h.toString().padLeft(2, '0')}:00',
      ));
    }
    return slots;
  }

  HourlyWeather? _nearestH(List<HourlyWeather> list, DateTime t) {
    HourlyWeather? best;
    Duration bd = const Duration(days: 999);
    for (final h in list) {
      final dt = DateTime.tryParse(h.datetime)?.toLocal();
      if (dt == null) continue;
      final d = dt.difference(t).abs();
      if (d < bd) { bd = d; best = h; }
    }
    return best;
  }

  double _diurnal(double tMin, double tMax, int hour) {
    final h = hour % 24;
    if (h >= 6 && h <= 14) return tMin + (tMax - tMin) * ((h - 6) / 8.0);
    if (h > 14 && h <= 22) return tMax - (tMax - tMin) * ((h - 14) / 8.0);
    return tMin;
  }

  List<HourlyWeather> _getSlotsForSelDay(WeatherProvider wp) {
    final isToday = _selDay == _todayIndex;
    if (isToday) return _buildTodayHourlySlots(wp);
    final sel = _dateForSelDay(wp);
    final dh  = wp.hourlyForDate(sel);
    if (dh.isEmpty) return [];
    if (dh.length <= 6) return dh;
    final r = <HourlyWeather>[];
    final step = (dh.length - 1) / 5;
    for (int i = 0; i < 6; i++) r.add(dh[(i * step).round().clamp(0, dh.length - 1)]);
    return r;
  }

  List<DayForecast> _visibleForecast(WeatherProvider wp) {
    final ts = _ds(DateTime.now());
    int si = 0;
    for (int i = 0; i < wp.forecast.length; i++) {
      final s = wp.forecast[i].date;
      final d = s.length >= 10 ? s.substring(0, 10) : s;
      if (d == ts) { si = i; break; }
      if (d.compareTo(ts) < 0) si = i + 1;
    }
    final end = (si + 10).clamp(0, wp.forecast.length);
    return wp.forecast.sublist(si, end);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_entryFadeA == null || _entrySlideA == null || _daySwitchA == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF1565C0),
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light));
    return Consumer<WeatherProvider>(builder: (ctx, wp, _) {
      String ac;
      if (wp.status == WeatherStatus.loaded && wp.currentWeather != null) {
        ac = _selDay == _todayIndex
            ? wp.liveCondition
            : (wp.forecast.isNotEmpty && _selDay < wp.forecast.length
            ? wp.forecast[_selDay].condition
            : wp.currentWeather?.condition ?? 'sunny');
      } else {
        ac = wp.currentWeather?.condition ?? 'sunny';
      }

      final ct        = _conditionType(ac);
      final tod       = _timeOfDay(_nowIST().hour);
      final condTheme = WeatherConditionTheme.of(ac, hour: _nowIST().hour);
      final bgKey     = ValueKey('${ct.name}_${tod.name}');

      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(children: [
          Positioned.fill(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: _buildBg(ct, tod, condTheme, key: bgKey))),
          SafeArea(bottom: false, child: _buildBody(wp, condTheme, ct, tod)),
        ]),
      );
    });
  }

  Widget _buildBg(_ConditionType ct, _TimeOfDay tod,
      WeatherConditionTheme ct2, {Key? key}) =>
      SizedBox.expand(key: key, child: Stack(fit: StackFit.expand, children: [
        _WeatherBackground(asset: _bgAsset(ct, tod), fallbackColors: _fallbackGradient(ct, tod)),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: _bgOverlay(ct, tod), stops: const [0.0, 0.45, 1.0]))),
      ]));

  Widget _buildBody(WeatherProvider wp, WeatherConditionTheme ct,
      _ConditionType ct2, _TimeOfDay tod) {
    if (wp.status == WeatherStatus.loading && wp.currentWeather == null) return _buildLoading();
    if (wp.status == WeatherStatus.error   && wp.currentWeather == null) return _buildError(wp);
    if (wp.currentWeather == null) return _buildLoading();

    final day      = _getActiveDay(wp);
    final dayCT    = _conditionType(day.condition);
    final dayTheme = WeatherConditionTheme.of(day.condition, hour: _nowIST().hour);

    return FadeTransition(opacity: entryFade, child: SlideTransition(position: entrySlide,
      child: Column(children: [
        _buildTopBar(wp, dayTheme, dayCT),
        if (wp.silentRefreshing) SizedBox(height: 2, child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(dayTheme.accentColor.withOpacity(0.7)))),
        Expanded(child: RefreshIndicator(
          onRefresh: wp.refresh,
          color: dayTheme.accentColor,
          displacement: 20,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
            child: Column(children: [
              FadeTransition(opacity: daySwitch,
                  child: _buildHero(wp, day, dayTheme, dayCT, tod)),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAqiCard()),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatRow(day, dayTheme, dayCT)),
              const SizedBox(height: 14),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTabBar(dayTheme)),
              const SizedBox(height: 14),
              FadeTransition(opacity: daySwitch,
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildTabContent(wp, day, dayTheme, dayCT))),
              const SizedBox(height: 16),
              _buildIMDLink(),
              const SizedBox(height: 8),
              _buildCpcbDisclaimer(),
              const SizedBox(height: 8),
              _buildAuthorizedDisclaimer(),
              const SizedBox(height: 8),
            ]),
          ),
        )),
      ]),
    ));
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(WeatherProvider wp, WeatherConditionTheme theme, _ConditionType ct) =>
      Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            Container(width: 58, height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
                    boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 8, spreadRadius: 1)]),
                child: ClipOval(child: Image.asset('assets/icon/cropped.jpeg',
                    width: 40, height: 40, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                        child: const Icon(Icons.thunderstorm_rounded, color: Colors.white, size: 24))))),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('NCMRWF', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w900, letterSpacing: 0.6, height: 1.1),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              TranslatedText('NWP Model Guidance', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11,
                  fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.2),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ])),
            const SizedBox(width: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _iconBtn(Icons.search_rounded, _openSearch),
              const SizedBox(width: 6),
              _iconBtn(Icons.my_location_rounded, wp.fetchWeatherForCurrentLocation),
              const SizedBox(width: 6),
              Consumer<FavoritesProvider>(builder: (_, fp, __) =>
                  _iconBtn(Icons.star_rounded, () => _showFavs(context, theme))),
            ]),
          ]));

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25))),
                  child: Icon(icon, color: Colors.white, size: 17)))));

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero(WeatherProvider wp, _ActiveDay day, WeatherConditionTheme theme,
      _ConditionType ct, _TimeOfDay tod) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Expanded(child: TranslatedText(
                  wp.placeName.isEmpty ? 'Fetching location…' : wp.placeName,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 8)]),
                  overflow: TextOverflow.ellipsis)),
            ]),
            if (_pincodeLoading || _pincode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.pin_drop_rounded, color: Colors.white54, size: 12),
                const SizedBox(width: 4),
                _pincodeLoading
                    ? TranslatedText('Loading…', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11))
                    : TranslatedText('PIN: $_pincode', style: GoogleFonts.dmSans(color: Colors.white60,
                    fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ],
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Builder(builder: (ctx) {
                final sw = MediaQuery.of(ctx).size.width;
                final tempFs  = (sw * 0.22).clamp(72.0, 108.0);
                final degFs   = (sw * 0.10).clamp(32.0, 48.0);
                final iconSz  = (sw * 0.26).clamp(90.0, 130.0);
                return Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(day.temperatureC.toStringAsFixed(0),
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: tempFs,
                          fontWeight: FontWeight.w100, height: 0.85,
                          shadows: [Shadow(color: Colors.black.withOpacity(0.25), blurRadius: 16)])),
                  Padding(padding: EdgeInsets.only(top: tempFs * 0.10),
                      child: Text('°', style: GoogleFonts.dmSans(color: Colors.white,
                          fontSize: degFs, fontWeight: FontWeight.w200))),
                  const Spacer(),
                  Padding(padding: EdgeInsets.only(top: 8),
                      child: _buildHeroIcon(day.condition, size: iconSz)),
                ]));
              }),
            ]),
            const SizedBox(height: 2),
            LayoutBuilder(builder: (ctx, _) {
              final sw = MediaQuery.of(ctx).size.width;
              final condFs = (sw * 0.056).clamp(18.0, 28.0);
              final subFs  = (sw * 0.035).clamp(12.0, 16.0);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TranslatedText(day.condition, style: GoogleFonts.dmSans(color: Colors.white,
                    fontSize: condFs, fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)])),
                const SizedBox(height: 6),
                Row(children: [
                  if (day.tempMax != 0)
                    TranslatedText('↑${day.tempMax.toStringAsFixed(0)}° / ↓${day.tempMin.toStringAsFixed(0)}°',
                        style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.90), fontSize: subFs,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)])),
                  const SizedBox(width: 14),
                  FutureBuilder<String>(
                    future: TranslatorService.translate('Feels like'),
                    initialData: 'Feels like',
                    builder: (_, s) => Text('${s.data} ${day.feelsLikeC.toStringAsFixed(0)}°',
                        style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.80), fontSize: subFs - 1,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)])),
                  ),
                ]),
              ]);
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: TranslatedText(_formatDate(_dateForSelDay(wp)), style: GoogleFonts.dmSans(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]));

  bool _isHeroNight() {
    final h = _nowIST().hour;
    return h >= 19 || h < 5;
  }

  Widget _buildHeroIcon(String condition, {required double size}) {
    final night = _isHeroNight();
    final c = condition.toLowerCase();
    final isClear = c.contains('sun') || c.contains('clear') ||
        c.contains('fair') || c.contains('hot') || c.contains('warm') ||
        c.contains('partly') || c.contains('partial');
    final hasSpecificIcon = c.contains('thunder') || c.contains('storm') ||
        c.contains('snow') || c.contains('cold') ||
        c.contains('rain') || c.contains('drizzle') || c.contains('shower') ||
        c.contains('wind') || c.contains('cloud') || c.contains('overcast') ||
        c.contains('haze') || c.contains('mist') || c.contains('fog');
    if (night && isClear && !hasSpecificIcon) {
      return Icon(Icons.nights_stay_rounded, color: Colors.white, size: size);
    }
    return AnimatedWeatherIcon(condition: condition, size: size);
  }

  // ── CPCB AQI card ─────────────────────────────────────────────────────────
  Widget _buildAqiCard() {
    if (_aqiLoading && _aqiData == null) {
      return _FrostCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        blurSigma: 18,
        bgOpacity: 0.16,
        child: Row(children: [
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
          const SizedBox(width: 10),
          TranslatedText('Fetching AQI from CPCB…',
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
        ]),
      );
    }

    if (_aqiData == null || _aqiData!.aqi == 0) return const SizedBox.shrink();

    final aqi       = _aqiData!.aqi;
    final aqiColor  = _AqiData.aqiColor(aqi);
    final aqiLabel  = _aqiData!.label;
    final aqiDesc   = _aqiData!.description;
    final station   = _aqiData!.stationName;
    final pollutant = _aqiData!.predominantParameter;

    const bandColors = [
      Color(0xFF00C853),
      Color(0xFF64DD17),
      Color(0xFFFFD600),
      Color(0xFFFF6D00),
      Color(0xFFD50000),
    ];
    final activeBand = aqi <= 100 ? 0 : aqi <= 200 ? 1 : aqi <= 300 ? 2 : aqi <= 400 ? 3 : 4;

    return _FrostCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      blurSigma: 18,
      bgOpacity: 0.18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // AQI circle — fixed size, never stretches
          SizedBox(
            width: 62, height: 62,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: aqiColor, width: 2.5),
                color: aqiColor.withOpacity(0.18),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.eco_rounded, color: aqiColor, size: 18),
                const SizedBox(height: 1),
                Text('$aqi', style: GoogleFonts.dmSans(
                    color: aqiColor, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          // Right side — must be Expanded so it never pushes outside the card
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Title + badge: use Wrap so badge wraps to next line if needed ──
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TranslatedText('Air Quality', style: GoogleFonts.dmSans(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: aqiColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TranslatedText(
                        aqiLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              TranslatedText(aqiDesc, style: GoogleFonts.dmSans(
                  color: Colors.white70, fontSize: 12, height: 1.4),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
              if (pollutant.isNotEmpty && pollutant != 'NA') ...[
                const SizedBox(height: 4),
                TranslatedText('Main pollutant: $pollutant',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                        color: aqiColor.withOpacity(0.85), fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Band bar
        LayoutBuilder(builder: (_, c) {
          const gap = 3.0;
          final segW = (c.maxWidth - gap * 4) / 5;
          return Row(
            children: List.generate(5, (i) {
              final isActive = i == activeBand;
              return Container(
                width: segW,
                height: isActive ? 7 : 5,
                margin: EdgeInsets.only(right: i < 4 ? gap : 0),
                decoration: BoxDecoration(
                  color: isActive
                      ? bandColors[i]
                      : bandColors[i].withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        }),
        if (station.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_rounded, color: Colors.white30, size: 11),
            const SizedBox(width: 3),
            Expanded(child: TranslatedText(station, style: GoogleFonts.dmSans(
                color: Colors.white38, fontSize: 10, height: 1.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            TranslatedText('CPCB', style: GoogleFonts.dmSans(
                color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
          ]),
        ],
      ]),
    );
  }

  // ── AI description card ────────────────────────────────────────────────────
  Widget _buildAiCard() {
    if (_aiLoading) {
      return _FrostCard(
          padding: const EdgeInsets.all(14), blurSigma: 18, bgOpacity: 0.16,
          child: Row(children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
            const SizedBox(width: 10),
            TranslatedText('Generating weather insight…',
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
          ]));
    }
    if (_aiDescription == null || _aiDescription!.isEmpty) return const SizedBox.shrink();
    return _FrostCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        blurSigma: 18, bgOpacity: 0.16,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFB300).withOpacity(0.18)),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFFFB300), size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TranslatedText('AI Weather Insight',
                style: GoogleFonts.dmSans(color: const Color(0xFFFFB300),
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            TranslatedText(_aiDescription!,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, height: 1.5)),
          ])),
        ]));
  }

  // ── 3-tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar(WeatherConditionTheme theme) {
    final tabDefs = [
      (_MainTab.temperature,   'Temperature'),
      (_MainTab.precipitation, 'Precipitation'),
      (_MainTab.wind,          'Wind'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
          ),
          child: Row(
            children: tabDefs.asMap().entries.map((entry) {
              final index    = entry.key;
              final tab      = entry.value;
              final isActive = _mainTab == tab.$1;
              final isLast   = index == tabDefs.length - 1;
              return Expanded(
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mainTab = tab.$1),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 50,
                        child: Stack(alignment: Alignment.center, children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: TranslatedText(tab.$2, textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                    color: isActive
                                        ? const Color(0xFFFFB300)
                                        : Colors.white.withOpacity(0.65),
                                    fontSize: 13.5,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                    letterSpacing: 0.1,
                                  )),
                            ),
                          ),
                          if (isActive)
                            Positioned(
                              bottom: 6, left: 12, right: 12,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(width: 1, height: 22, color: Colors.white.withOpacity(0.25)),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Tab content dispatcher ─────────────────────────────────────────────────
  Widget _buildTabContent(WeatherProvider wp, _ActiveDay day,
      WeatherConditionTheme theme, _ConditionType ct) {
    switch (_mainTab) {
      case _MainTab.temperature:   return _buildTempTab(wp, day, theme, ct);
      case _MainTab.precipitation: return _buildPrecipTab(wp, theme);
      case _MainTab.wind:          return _buildWindTab(wp, day, theme);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // TEMPERATURE TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildTempTab(WeatherProvider wp, _ActiveDay day,
      WeatherConditionTheme theme, _ConditionType ct) {
    final hrs = _getSlotsForSelDay(wp);
    return Column(children: [
      _FrostCard(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), blurSigma: 20, bgOpacity: 0.20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TranslatedText('Hourly Forecast', style: GoogleFonts.dmSans(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              TranslatedText('next 6 hrs  ›', style: GoogleFonts.dmSans(
                  color: Colors.white54, fontSize: 11)),
            ]),
            const SizedBox(height: 14),
            hrs.isEmpty
                ? TranslatedText('No data', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12))
                : _tempHourlyScroll(hrs, theme, ct),
          ])),
      const SizedBox(height: 12),
      _buildDayStrip(wp, theme),
      const SizedBox(height: 12),
      _buildTempGraph(wp, theme),
      const SizedBox(height: 12),
      _buildConditionCard(day, theme, ct),
      if (day.rainMm > 0) ...[const SizedBox(height: 12), _buildRainCard(day)],
    ]);
  }

  Widget _tempHourlyScroll(List<HourlyWeather> hrs,
      WeatherConditionTheme theme, _ConditionType ct) {
    return LayoutBuilder(builder: (context, constraints) {
      final slotW = math.max(constraints.maxWidth / hrs.length, 60.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: hrs.map((h) => SizedBox(width: slotW, child: _tempSlot(h, ct))).toList()),
          const SizedBox(height: 10),
          SizedBox(width: slotW * hrs.length, height: 24, child: CustomPaint(
              painter: _TempBarPainter(positions: _normTemp(hrs), accent: theme.accentColor))),
          const SizedBox(height: 10),
          Row(children: hrs.map((h) => SizedBox(width: slotW, child: Column(children: [
            Icon(Icons.water_drop_rounded,
                color: h.rainMm > 0 ? Colors.lightBlue[300] : Colors.white30, size: 11),
            Text(h.rainMm > 0 ? '${h.rainMm.toStringAsFixed(0)}%' : '0%',
                style: GoogleFonts.dmSans(
                    color: h.rainMm > 0 ? Colors.lightBlue[300] : Colors.white38, fontSize: 10)),
          ]))).toList()),
        ]),
      );
    });
  }

  Widget _tempSlot(HourlyWeather h, _ConditionType ct) {
    final isNow   = h.label == 'Now';
    final isNight = _slotIsNight(h.datetime);
    final ibg     = isNight ? const Color(0xFF1A237E) : _iconBg(ct);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TranslatedText(isNow ? 'Now' : _slotLabel(h.datetime), style: GoogleFonts.dmSans(
          color: isNow ? Colors.white : Colors.white.withOpacity(0.80), fontSize: 12,
          fontWeight: isNow ? FontWeight.w800 : FontWeight.w500)),
      const SizedBox(height: 5),
      Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: ibg.withOpacity(isNow ? 1.0 : 0.80),
              boxShadow: isNow ? [BoxShadow(color: ibg.withOpacity(0.5), blurRadius: 8)] : null),
          child: Icon(_iconSlot(h.condition, h.datetime), color: Colors.white, size: 18)),
      const SizedBox(height: 6),
      Text('${h.temperatureC.toStringAsFixed(0)}°', style: GoogleFonts.dmSans(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }

  // ════════════════════════════════════════════════════════════════
  // PRECIPITATION TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildPrecipTab(WeatherProvider wp, WeatherConditionTheme theme) {
    final hrs    = _getSlotsForSelDay(wp);
    final tenDay = _visibleForecast(wp);
    return Column(children: [
      _FrostCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        blurSigma: 20, bgOpacity: 0.20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TranslatedText('Hourly Precipitation', style: GoogleFonts.dmSans(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          hrs.isEmpty
              ? TranslatedText('No data', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12))
              : _precipHourlySlots(hrs),
        ]),
      ),
      const SizedBox(height: 12),
      _FrostCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        blurSigma: 20, bgOpacity: 0.20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TranslatedText('10-Day Forecast', style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          tenDay.isEmpty
              ? TranslatedText('No data', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12))
              : _precipTenDayList(tenDay),
        ]),
      ),
    ]);
  }

  Widget _precipHourlySlots(List<HourlyWeather> hrs) {
    final maxR = hrs
        .map((h) => h.rainMm)
        .fold(0.0, (a, b) => a > b ? a : b)
        .clamp(0.1, double.infinity);

    // Percentage row
    final pctRow = Row(
      children: hrs.map((h) {
        final pct = h.rainMm > 0 ? '${(h.rainMm / maxR * 100).round()}%' : '0%';
        return Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pct,
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        );
      }).toList(),
    );

    // Label row
    final labelRow = Row(
      children: hrs.map((h) {
        final isNow = h.label == 'Now';
        return Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TranslatedText(
                isNow ? 'Now' : _slotLabel(h.datetime),
                style: GoogleFonts.dmSans(
                  color: isNow ? Colors.white : Colors.white.withOpacity(0.80),
                  fontSize: 12,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final slotW  = totalW / hrs.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pctRow,
            const SizedBox(height: 10),
            SizedBox(
              height: 18,
              width: totalW,
              child: CustomPaint(
                size: Size(totalW, 18),
                painter: _PrecipBarPainter(hrs: hrs, maxR: maxR, slotW: slotW),
              ),
            ),
            const SizedBox(height: 6),
            labelRow,
          ],
        );
      },
    );
  }

  Widget _precipTenDayList(List<DayForecast> days) {
    return Column(children: days.asMap().entries.map((e) {
      final i = e.key; final df = e.value; final isToday = i == 0;
      final condIcon = _iconNow(df.condition);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: i < days.length - 1
              ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.12), width: 1))
              : null,
        ),
        child: Row(children: [
          SizedBox(width: 52,
              child: isToday
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TranslatedText('Today', style: GoogleFonts.dmSans(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w700)),
                TranslatedText(df.day, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.70),
                    fontSize: 11, fontWeight: FontWeight.w500)),
              ])
                  : TranslatedText(df.day, style: GoogleFonts.dmSans(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w600))),
          Icon(condIcon, color: Colors.white.withOpacity(0.85), size: 20),
          const SizedBox(width: 10),
          Icon(Icons.water_drop_rounded,
              color: df.rainTotal > 0 ? const Color(0xFF64B5F6) : Colors.white.withOpacity(0.50), size: 15),
          const SizedBox(width: 4),
          Text('${df.rainTotal.toStringAsFixed(1)} mm',
              style: GoogleFonts.dmSans(
                  color: df.rainTotal > 0 ? const Color(0xFF90CAF9) : Colors.white.withOpacity(0.65),
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${df.tempMax.toStringAsFixed(0)}°',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${df.tempMin.toStringAsFixed(0)}°',
              style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.70), fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      );
    }).toList());
  }

  // ════════════════════════════════════════════════════════════════
  // WIND TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildWindTab(WeatherProvider wp, _ActiveDay day,
      WeatherConditionTheme theme) {
    final hrs    = _getSlotsForSelDay(wp);
    final tenDay = _visibleForecast(wp);

    final nowSlot          = hrs.isNotEmpty ? hrs.first : null;
    final compassSpeedKmh  = nowSlot?.windSpeedKmh  ?? day.windSpeedKmh;
    final compassDirection = nowSlot?.windDirection  ?? day.windDirection;

    final compassDay = _ActiveDay(
      temperatureC:    day.temperatureC,
      feelsLikeC:      day.feelsLikeC,
      windSpeedKmh:    compassSpeedKmh,
      windDirection:   compassDirection,
      humidityPercent: day.humidityPercent,
      pressureHpa:     day.pressureHpa,
      condition:       day.condition,
      dayLabel:        day.dayLabel,
      tempMin:         day.tempMin,
      tempMax:         day.tempMax,
      rainMm:          day.rainMm,
    );

    final windSpeeds = <double>[];
    for (int i = 0; i < tenDay.length; i++) {
      if (i == 0) {
        if (hrs.isNotEmpty) {
          windSpeeds.add(hrs.map((h) => h.windSpeedKmh).reduce((a, b) => a + b) / hrs.length);
        } else {
          windSpeeds.add(compassSpeedKmh);
        }
      } else {
        final dt = DateTime.tryParse(tenDay[i].date);
        final dh = dt != null ? wp.hourlyForDate(dt) : <HourlyWeather>[];
        if (dh.isNotEmpty) {
          windSpeeds.add(dh.map((h) => h.windSpeedKmh).reduce((a, b) => a + b) / dh.length);
        } else {
          windSpeeds.add(windSpeeds.isNotEmpty ? windSpeeds.first : compassSpeedKmh);
        }
      }
    }

    return Column(children: [
      _buildCompassCard(compassDay, theme),
      const SizedBox(height: 12),
      _FrostCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        blurSigma: 20, bgOpacity: 0.20,
        child: tenDay.isEmpty
            ? TranslatedText('No data', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12))
            : _windWeekTrendChart(tenDay, windSpeeds, theme),
      ),
      const SizedBox(height: 12),
      _FrostCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        blurSigma: 20, bgOpacity: 0.20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TranslatedText('Hourly Wind', style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          hrs.isEmpty
              ? TranslatedText('No data', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12))
              : _windHourlyScroll(hrs, theme),
        ]),
      ),
    ]);
  }

  Widget _windWeekTrendChart(List<DayForecast> days, List<double> windSpeeds,
      WeatherConditionTheme theme) {
    if (days.isEmpty || windSpeeds.isEmpty) return const SizedBox.shrink();
    final maxS  = windSpeeds.reduce(math.max);
    final minS  = windSpeeds.reduce(math.min);
    final range = (maxS - minS).clamp(1.0, double.infinity);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TranslatedText('Wind Speed Trend', style: GoogleFonts.dmSans(
            color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
        Text('${minS.toStringAsFixed(0)} – ${maxS.toStringAsFixed(0)} km/h',
            style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 10)),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 80,
        child: LayoutBuilder(builder: (_, c) {
          final w     = c.maxWidth;
          final itemW = w / days.length;
          return Stack(children: [
            CustomPaint(
              size: Size(w, 80),
              painter: _WindWeekFillPainter(
                  speeds: windSpeeds, minS: minS, range: range, accent: theme.accentColor),
            ),
            Row(
              children: days.asMap().entries.map((e) {
                final i   = e.key;
                final df  = e.value;
                final spd = i < windSpeeds.length ? windSpeeds[i] : 0.0;
                return SizedBox(
                  width: itemW,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${spd.toStringAsFixed(0)}', style: GoogleFonts.dmSans(
                        color: i == 0 ? theme.accentColor : Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    TranslatedText(i == 0 ? 'Today' : df.day, style: GoogleFonts.dmSans(
                        color: i == 0 ? theme.accentColor : Colors.white.withOpacity(0.80),
                        fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
          ]);
        }),
      ),
    ]);
  }

  Widget _windHourlyScroll(List<HourlyWeather> hrs, WeatherConditionTheme theme) {
    return LayoutBuilder(builder: (context, constraints) {
      // Dynamically size each slot to fit screen, minimum 64px
      final slotW = math.max(constraints.maxWidth / hrs.length, 64.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
        child: Row(children: hrs.map((h) {
          final isNow = h.label == 'Now';
          return SizedBox(width: slotW, child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speed + unit on one line, never wraps
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${h.windSpeedKmh.toStringAsFixed(0)} km/h',
                    maxLines: 1,
                    style: GoogleFonts.dmSans(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Transform.rotate(
                angle: _dirRad(h.windDirection),
                child: const Icon(Icons.navigation_rounded, color: Color(0xFFFFB300), size: 22),
              ),
              const SizedBox(height: 8),
              TranslatedText(isNow ? 'Now' : _slotLabel(h.datetime),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: isNow ? Colors.white : Colors.white.withOpacity(0.80),
                      fontSize: 12,
                      fontWeight: isNow ? FontWeight.w800 : FontWeight.w500)),
            ],
          ));
        }).toList()),
      );
    });
  }

  Widget _windTenDayList(List<DayForecast> days) {
    return Column(children: days.asMap().entries.map((e) {
      final i = e.key; final df = e.value; final isToday = i == 0;
      final wDir = df.windDirection.isNotEmpty ? df.windDirection : 'N';
      return Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            SizedBox(width: 46, child: TranslatedText(isToday ? 'Today' : df.day,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600))),
            Icon(_iconNow(df.condition), color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Transform.rotate(angle: _dirRad(wDir),
                child: const Icon(Icons.navigation_rounded, color: Color(0xFFFFB300), size: 14)),
            const SizedBox(width: 4),
            TranslatedText(wDir, style: GoogleFonts.dmSans(color: const Color(0xFFFFB300),
                fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${df.tempMax.toStringAsFixed(0)}°',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${df.tempMin.toStringAsFixed(0)}°',
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w400)),
          ]));
    }).toList());
  }

  // ── Compass card ───────────────────────────────────────────────────────────
  Widget _buildCompassCard(_ActiveDay day, WeatherConditionTheme theme) {
    final deg     = _dirDeg(day.windDirection);
    final gustKmh = day.windSpeedKmh * 1.3;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TranslatedText('Wind Compass', style: GoogleFonts.dmSans(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      _FrostCard(
          padding: const EdgeInsets.all(16), blurSigma: 18, bgOpacity: 0.16,
          child: LayoutBuilder(builder: (context, constraints) {
            final compassSize = (constraints.maxWidth * 0.42).clamp(100.0, 160.0);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(width: compassSize, height: compassSize,
                    child: CustomPaint(
                        painter: _CompassPainter(windDeg: deg, accent: theme.accentColor))),
                const SizedBox(width: 14),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(
                    fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                    child: Row(children: [
                      Text('${day.windSpeedKmh.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(color: Colors.white,
                              fontSize: 48, fontWeight: FontWeight.w300)),
                      TranslatedText(' km/h', style: GoogleFonts.dmSans(
                          color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.multiple_stop_rounded, color: Color(0xFFFFB300), size: 15),
                    const SizedBox(width: 5),
                    Flexible(child: Row(children: [
                      TranslatedText('Wind', style: GoogleFonts.dmSans(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(': ${day.windDirection}', style: GoogleFonts.dmSans(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.flag_rounded, color: Colors.white54, size: 14),
                    const SizedBox(width: 5),
                    Flexible(child: Row(children: [
                      TranslatedText('Gusts', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                      TranslatedText(': ~${gustKmh.toStringAsFixed(0)} km/h',
                          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
                    ])),
                  ]),
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Container(width: 10, height: 10,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFB300))),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (gustKmh / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                      minHeight: 4,
                    ))),
              ]),
            ]);
          })),
    ]);
  }

  Widget _compStat(String lbl, String val, IconData icon, Color c) =>
      Column(children: [
        Icon(icon, color: c, size: 18), const SizedBox(height: 4),
        TranslatedText(val, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        TranslatedText(lbl, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 10)),
      ]);

  // ── Day strip ──────────────────────────────────────────────────────────────
  Widget _buildDayStrip(WeatherProvider wp, WeatherConditionTheme theme) {
    final ts = _ds(DateTime.now());
    int si = 0;
    for (int i = 0; i < wp.forecast.length; i++) {
      final s = wp.forecast[i].date;
      final d = s.length >= 10 ? s.substring(0, 10) : s;
      if (d == ts) { si = i; break; }
      if (d.compareTo(ts) < 0) si = i + 1;
    }
    final end = (si + 10).clamp(0, wp.forecast.length);
    final cnt = (end - si).clamp(0, 10);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TranslatedText('10-Day Forecast', style: GoogleFonts.dmSans(
          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      SizedBox(height: 112, child: cnt == 0
          ? Center(child: TranslatedText('No forecast data',
          style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)))
          : ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: cnt,
          itemBuilder: (ctx, vi) {
            final oi = si + vi; final sel = oi == _selDay;
            final df = wp.forecast[oi]; final isToday = vi == 0;
            return GestureDetector(
                onTap: () => _selectDay(oi),
                child: ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 8), width: 70,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                                color: sel ? Colors.white.withOpacity(0.32) : Colors.white.withOpacity(0.16),
                                border: Border.all(
                                    color: sel ? Colors.white.withOpacity(0.65) : Colors.white.withOpacity(0.22),
                                    width: sel ? 1.5 : 1)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              TranslatedText(isToday ? 'Today' : df.day, style: GoogleFonts.dmSans(
                                  color: sel ? Colors.white : Colors.white.withOpacity(0.85),
                                  fontSize: isToday ? 10 : 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              Icon(_iconNow(df.condition), color: Colors.white, size: 20),
                              const SizedBox(height: 5),
                              Text('${df.tempMax.toStringAsFixed(0)}°', style: GoogleFonts.dmSans(
                                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              Text('${df.tempMin.toStringAsFixed(0)}°', style: GoogleFonts.dmSans(
                                  color: Colors.white.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w600)),
                            ])))));
          })),
    ]);
  }


  // ── Stat row ──────────────────────────────────────────────────────────────
  Widget _buildStatRow(_ActiveDay day, WeatherConditionTheme theme, _ConditionType ct) =>
      Row(children: [
        _statChip(Icons.water_drop_rounded, const Color(0xFF64B5F6),
            '${day.humidityPercent.toStringAsFixed(0)}%', tl('Humidity')),
        const SizedBox(width: 10),
        _statChip(Icons.air_rounded, const Color(0xFF81C784),
            '${day.windSpeedKmh.toStringAsFixed(1)} km/h', tl('Wind')),
        const SizedBox(width: 10),
        _statChip(Icons.compress_rounded, const Color(0xFFFFCC80),
            '${day.pressureHpa.toStringAsFixed(0)} hPa', tl('Pressure')),
      ]);

  Widget _statChip(IconData icon, Color c, String val, String lbl) =>
      Expanded(child: _FrostCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          radius: 18, blurSigma: 16, bgOpacity: 0.22,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: c, size: 22), const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, child: TranslatedText(val,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w800), maxLines: 1)),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, child: TranslatedText(lbl,
                style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.80),
                    fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1)),
          ])));

  // ── Temp graph ─────────────────────────────────────────────────────────────
  Widget _buildTempGraph(WeatherProvider wp, WeatherConditionTheme theme) {
    if (wp.trend.isEmpty) return const SizedBox.shrink();
    final data = _limitTrend(wp.trend);
    final mn = wp.minTemp - 2, mx = wp.maxTemp + 2;
    return _FrostCard(padding: const EdgeInsets.all(16), blurSigma: 18, bgOpacity: 0.16,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TranslatedText('Temperature Trend', style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            TranslatedText('Tap to select', style: GoogleFonts.dmSans(
                color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(height: 14),
          GestureDetector(
            onTapDown: (d) {
              final w = MediaQuery.of(context).size.width - 80;
              final idx = ((d.localPosition.dx / w) * (data.length - 1)).round().clamp(0, data.length - 1);
              _selectDay(idx);
            },
            child: SizedBox(height: 130, child: CustomPaint(
                size: const Size(double.infinity, 130),
                painter: _TempPainter(trend: data, mn: mn, mx: mx, range: mx - mn,
                    sel: _selDay, accent: theme.accentColor))),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TranslatedText('Min: ${wp.minTemp.toStringAsFixed(1)}°C',
                style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 10)),
            TranslatedText('Max: ${wp.maxTemp.toStringAsFixed(1)}°C',
                style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 10)),
          ]),
        ]));
  }

  List<TrendPoint> _limitTrend(List<TrendPoint> full) {
    if (full.length <= 10) return full;
    final r = <TrendPoint>[];
    final step = (full.length - 1) / 9;
    for (int i = 0; i < 10; i++) r.add(full[(i * step).round()]);
    return r;
  }

  // ── Condition card — AI-powered, no hardcoded text ────────────────────────
  Widget _buildConditionCard(_ActiveDay day, WeatherConditionTheme theme, _ConditionType ct) {
    // Map condition type → icon + accent colour (visual logic unchanged)
    final IconData icon;
    final Color    accentC;
    final Color?   tint;
    String?        badge;

    switch (ct) {
      case _ConditionType.sunny:
        icon = Icons.wb_sunny_rounded; accentC = const Color(0xFFFFD54F); tint = null; badge = null;
        break;
      case _ConditionType.rainy:
        icon = Icons.water_drop_rounded; accentC = const Color(0xFF64B5F6); tint = null; badge = null;
        break;
      case _ConditionType.stormy:
        icon = Icons.thunderstorm_rounded; accentC = const Color(0xFFFFEE58);
        tint = const Color(0xFF311B92); badge = '⚡ High risk';
        break;
      case _ConditionType.snowy:
        icon = Icons.ac_unit_rounded; accentC = const Color(0xFFB3E5FC); tint = null; badge = null;
        break;
      case _ConditionType.cloudy:
        icon = Icons.cloud_rounded; accentC = const Color(0xFFB0BEC5); tint = null; badge = null;
        break;
      case _ConditionType.windy:
        icon = Icons.air_rounded; accentC = const Color(0xFF80DEEA); tint = null; badge = null;
        break;
      default:
        icon = Icons.wb_cloudy_rounded; accentC = Colors.white60; tint = null; badge = null;
    }

    // Loading state
    if (_conditionLoading && _conditionTitle == null) {
      return _FrostCard(
        padding: const EdgeInsets.all(16),
        blurSigma: 18,
        bgOpacity: tint != null ? 0.22 : 0.15,
        tint: tint,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentC.withOpacity(0.20)),
            child: Icon(icon, color: accentC, size: 24),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
          const SizedBox(width: 10),
          TranslatedText('Loading insight…',
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
        ]),
      );
    }

    // AI text — fall back to condition string if API failed
    final title = (_conditionTitle?.isNotEmpty ?? false) ? _conditionTitle! : day.condition;
    final body  = (_conditionBody?.isNotEmpty  ?? false) ? _conditionBody!  : 'Forecast data from NCMRWF NWP Model.';
    final extra = (_conditionExtra?.isNotEmpty ?? false) ? _conditionExtra  : null;

    return _frostInfo(icon, accentC, title, body, extra: extra, badge: badge, tint: tint);
  }

  Widget _frostInfo(IconData icon, Color c, String title, String body,
      {String? extra, String? badge, Color? tint}) =>
      _FrostCard(padding: const EdgeInsets.all(16), blurSigma: 18,
          bgOpacity: tint != null ? 0.22 : 0.15, tint: tint,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.20)),
                child: Icon(icon, color: c, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TranslatedText(title, style: GoogleFonts.dmSans(color: c,
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              TranslatedText(body, style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 12)),
              if (extra != null) ...[const SizedBox(height: 6),
                TranslatedText(extra, style: GoogleFonts.dmSans(color: c.withOpacity(0.85),
                    fontSize: 11, fontWeight: FontWeight.w600))],
              if (badge != null) ...[const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                        color: Colors.red.withOpacity(0.25)),
                    child: TranslatedText(badge, style: GoogleFonts.dmSans(
                        color: Colors.red[200], fontSize: 10, fontWeight: FontWeight.w700)))],
            ])),
          ]));

  Widget _buildRainCard(_ActiveDay day) => _FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      blurSigma: 16, bgOpacity: 0.15,
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.lightBlue.withOpacity(0.25)),
            child: const Icon(Icons.grain_rounded, color: Colors.lightBlue, size: 22)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TranslatedText('Rainfall', style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 12)),
          Text('${day.rainMm.toStringAsFixed(1)} mm', style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        ]),
      ]));

  // ── IMD link ───────────────────────────────────────────────────────────────
  Widget _buildIMDLink() => Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://mausam.imd.gov.in');
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: _FrostCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              blurSigma: 12, bgOpacity: 0.12, tint: Colors.amber,
              child: Row(children: [
                Icon(Icons.info_rounded, color: Colors.amber[300], size: 18),
                const SizedBox(width: 10),
                Expanded(child: Row(children: [
                  Flexible(child: TranslatedText('Official India weather alerts: ',
                      style: GoogleFonts.dmSans(color: Colors.amber[100], fontSize: 12, height: 1.5))),
                  const Text('mausam.imd.gov.in', style: TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline, decorationColor: Colors.white)),
                ])),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new_rounded, color: Colors.amber[300], size: 13),
              ]))));

  // ── Authorized users disclaimer ────────────────────────────────────────────
  Widget _buildAuthorizedDisclaimer() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFB71C1C).withOpacity(0.85),
                        const Color(0xFF7F0000).withOpacity(0.90),
                      ],
                    ),
                    border: Border.all(color: Colors.red[300]!.withOpacity(0.70), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withOpacity(0.35), blurRadius: 16, spreadRadius: 1),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(color: Colors.white.withOpacity(0.40), width: 1.2),
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText('Authorized Users Only',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)])),
                          const SizedBox(height: 3),
                          TranslatedText('Unauthorized access is strictly prohibited.',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white.withOpacity(0.90),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4)),
                        ])),
                    const SizedBox(width: 8),
                    Icon(Icons.shield_rounded, color: Colors.white.withOpacity(0.60), size: 22),
                  ])))));

  // ── CPCB AQI source disclaimer ─────────────────────────────────────────────
  Widget _buildCpcbDisclaimer() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://cpcb.nic.in/');
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: _FrostCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              blurSigma: 12, bgOpacity: 0.10,
              child: Row(children: [
                Icon(Icons.air_rounded, color: Colors.lightBlue[300], size: 15),
                const SizedBox(width: 8),
                Expanded(child: Row(children: [
                  TranslatedText('AQI data sourced from ',
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11, height: 1.4)),
                  TranslatedText('CPCB', style: GoogleFonts.dmSans(
                      color: Colors.lightBlue[200], fontSize: 11,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.lightBlue)),
                  TranslatedText(' · cpcb.nic.in',
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11, height: 1.4)),
                ])),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, color: Colors.white30, size: 11),
              ]))));

  // ── Favourites ─────────────────────────────────────────────────────────────
  void _showFavs(BuildContext ctx, WeatherConditionTheme ct) {
    final favs = ctx.read<FavoritesProvider>().favorites;
    if (favs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: TranslatedText('No favorites yet.',
              style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: Colors.black87));
      return;
    }
    showModalBottomSheet(
        context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (c) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  decoration: BoxDecoration(
                      color: ct.skyGradient.last.withOpacity(0.92),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15)))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Center(child: Container(width: 36, height: 4,
                        decoration: BoxDecoration(color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      TranslatedText('Switch Location', style: GoogleFonts.dmSans(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 12),
                    ...favs.map((fav) {
                      final isAct = ctx.read<WeatherProvider>().placeName == fav.name;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(c);
                          ctx.read<WeatherProvider>().fetchWeatherForLocation(
                              lat: fav.latitude, lon: fav.longitude, name: fav.name);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                              color: isAct ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.10),
                              border: Border.all(color: isAct
                                  ? Colors.white.withOpacity(0.55)
                                  : Colors.white.withOpacity(0.18))),
                          child: Row(children: [
                            Icon(isAct ? Icons.location_on_rounded : Icons.location_on_outlined,
                                color: isAct ? Colors.white : Colors.white60, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: TranslatedText(fav.name, style: GoogleFonts.dmSans(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                            if (isAct)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                                      color: Colors.white.withOpacity(0.2)),
                                  child: TranslatedText('Active', style: GoogleFonts.dmSans(
                                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))
                            else
                              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ))));
  }

  // ── Loading / Error ────────────────────────────────────────────────────────
  Widget _buildLoading() => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12)),
            child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 42)),
        const SizedBox(height: 22),
        TranslatedText('Fetching Weather…', style: GoogleFonts.dmSans(color: Colors.white,
            fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TranslatedText('Getting the latest forecast for you',
            style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 28),
        SizedBox(width: 200, child: ClipRRect(borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 2))),
      ]));

  Widget _buildError(WeatherProvider wp) {
    final isPermDenied = wp.locationFailReason == LocationFailReason.permissionPermanentlyDenied;
    final isServiceOff = wp.locationFailReason == LocationFailReason.serviceDisabled;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10)),
              child: const Icon(Icons.cloud_off_rounded, color: Colors.white60, size: 42)),
          const SizedBox(height: 22),
          TranslatedText('Something went wrong', style: GoogleFonts.dmSans(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TranslatedText('Unable to load weather.\nCheck your connection and try again.',
              style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          if (isPermDenied) ...[
            _errBtn(Icons.settings_rounded, tl('Open Settings'), wp.openLocationSettings),
            const SizedBox(height: 10),
          ],
          _errBtn(
              (isPermDenied || isServiceOff) ? Icons.location_city_rounded : Icons.refresh_rounded,
              (isPermDenied || isServiceOff) ? tl('Use New Delhi') : tl('Try Again'),
              (isPermDenied || isServiceOff)
                  ? () => wp.fetchWeatherForLocation(lat: 28.6139, lon: 77.2090, name: 'New Delhi')
                  : wp.refresh),
        ])));
  }

  Widget _errBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(color: Colors.white.withOpacity(0.35))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                    TranslatedText(label, style: GoogleFonts.dmSans(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14)),
                  ])))));

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _iconBg(_ConditionType ct) {
    switch (ct) {
      case _ConditionType.sunny:  return const Color(0xFFFFB300);
      case _ConditionType.rainy:  return const Color(0xFF1E88E5);
      case _ConditionType.stormy: return const Color(0xFF5C35A0);
      case _ConditionType.snowy:  return const Color(0xFF4FC3F7);
      case _ConditionType.windy:  return const Color(0xFF26A69A);
      default:                    return const Color(0xFF78909C);
    }
  }

  List<double> _normTemp(List<HourlyWeather> hrs) {
    if (hrs.isEmpty) return [];
    final ts = hrs.map((h) => h.temperatureC).toList();
    final mn = ts.reduce(math.min), mx = ts.reduce(math.max);
    final r = (mx - mn).clamp(1.0, double.infinity);
    return ts.map((t) => (t - mn) / r).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weather background
// ─────────────────────────────────────────────────────────────────────────────
class _WeatherBackground extends StatefulWidget {
  final String asset;
  final List<Color> fallbackColors;
  const _WeatherBackground({required this.asset, required this.fallbackColors});
  @override
  State<_WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<_WeatherBackground> {
  bool _loaded = false, _failed = false;

  @override
  void didUpdateWidget(covariant _WeatherBackground old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) setState(() { _loaded = false; _failed = false; });
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    Container(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: widget.fallbackColors))),
    if (!_failed) AnimatedOpacity(
        opacity: _loaded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Image.asset(widget.asset, fit: BoxFit.cover,
            frameBuilder: (ctx, child, frame, __) {
              if (frame != null && !_loaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _loaded = true);
                });
              }
              return child;
            },
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
              return const SizedBox.shrink();
            })),
  ]);
}

