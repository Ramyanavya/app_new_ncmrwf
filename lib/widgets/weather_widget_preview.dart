// lib/widget/weather_widget_preview.dart
// In-app widget preview — renders the widget UI inside the app so users can
// see exactly how it will look on their home screen.
//
// ✅ KEY FIX: All temperature displays now use wp.liveTemperatureC and
// wp.liveFeelsLikeC (diurnal model) instead of cw.temperatureC (raw API).
// This makes the widget preview match the main forecast screen exactly.
//
// ✅ THEME FIX: Widget background scene now uses wp.liveCondition instead of
// wp.currentWeather?.condition (raw API) so the theme matches the forecast screen.

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../providers/app_providers.dart';
import '../utils/weather_condition_theme.dart';
import '../utils/weather_icon_painter.dart';
import 'weather_widget.dart';

class WeatherWidgetPreviewScreen extends StatelessWidget {
  const WeatherWidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    final wp = context.watch<WeatherProvider>();
    // ✅ THEME FIX: use liveCondition (matches forecast screen) not raw condition
    final condition = wp.liveCondition;
    final condTheme = WeatherConditionTheme.of(condition);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: condTheme.skyGradient,
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(.3)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Widget Preview',
                    style: GoogleFonts.dmSans(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await WeatherWidgetUpdater.update(wp);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Widget updated!',
                              style: GoogleFonts.dmSans(color: Colors.white)),
                          backgroundColor: Colors.black54,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('Update Widget',
                          style: GoogleFonts.dmSans(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text('Home Screen Preview',
                      style: GoogleFonts.dmSans(
                          color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  WeatherWidgetCard(wp: wp),
                  const SizedBox(height: 30),
                  Text('Small Widget Preview',
                      style: GoogleFonts.dmSans(
                          color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  WeatherWidgetSmall(wp: wp),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIUM WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class WeatherWidgetCard extends StatelessWidget {
  final WeatherProvider wp;
  const WeatherWidgetCard({super.key, required this.wp});

  @override
  Widget build(BuildContext context) {
    // ✅ THEME FIX: use liveCondition for background theme (not raw condition)
    final condition = wp.liveCondition;
    final condTheme = WeatherConditionTheme.of(condition);
    final cw        = wp.currentWeather;
    final now       = DateTime.now();

    final hour   = now.hour.toString().padLeft(2, '0');
    final min    = now.minute.toString().padLeft(2, '0');
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    // ✅ Use liveTemperatureC (diurnal model) — matches the main forecast screen
    final displayTemp    = wp.liveTemperatureC;
    final displayFeels   = wp.liveFeelsLikeC;
    final displayCond    = wp.liveCondition;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              // ✅ THEME FIX: pass liveCondition so scene matches forecast screen
              child: _WidgetSceneBackground(condition: condition),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 160,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          condTheme.skyGradient.last.withOpacity(0.85),
                          condTheme.skyGradient.last.withOpacity(0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location + time ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF8C00).withOpacity(0.9),
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 11),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          wp.placeName.isEmpty ? 'Loading...' : wp.placeName,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$hour:$min',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                            )),
                        Text(dateStr,
                            style: GoogleFonts.dmSans(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Big temp + icon ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // ✅ liveTemperatureC (diurnal) — not cw.temperatureC (raw API)
                          Text(
                            displayTemp.toStringAsFixed(0),
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w300,
                              height: 0.9,
                              shadows: [Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('°c',
                                style: GoogleFonts.dmSans(
                                    color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w300)),
                          ),
                        ]),
                        // ✅ Min/Max from daily forecast
                        if (wp.forecast.isNotEmpty)
                          Row(children: [
                            Icon(Icons.arrow_downward_rounded,
                                color: Colors.lightBlue[200], size: 12),
                            Text(wp.forecast[0].tempMin.toStringAsFixed(0),
                                style: GoogleFonts.dmSans(
                                    color: Colors.lightBlue[200], fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_upward_rounded,
                                color: Colors.orange[200], size: 12),
                            Text(wp.forecast[0].tempMax.toStringAsFixed(0),
                                style: GoogleFonts.dmSans(
                                    color: Colors.orange[200], fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('°C', style: GoogleFonts.dmSans(
                                color: Colors.white54, fontSize: 11)),
                          ]),
                        const SizedBox(height: 4),
                        // ✅ liveCondition instead of cw?.condition
                        Text(
                          displayCond,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(height: 2),
                        // ✅ liveFeelsLikeC (diurnal) — not cw.feelsLikeC (raw API)
                        Text(
                          cw != null
                              ? 'Feels like ${displayFeels.toStringAsFixed(1)}°C'
                              : '',
                          style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 12),
                        ),
                      ]),
                      const Spacer(),
                      if (cw != null)
                        AnimatedWeatherIcon(condition: displayCond, size: 110),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 12),

                  // ── Stats row ─────────────────────────────────────────
                  // ✅ Uses live getters for humidity and wind (not raw cw)
                  if (cw != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFF64B5F6),
                          value: '${wp.liveHumidityPercent.toStringAsFixed(0)}%',
                          label: 'Humidity',
                        ),
                        Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2)),
                        _StatItem(
                          icon: Icons.air_rounded,
                          iconColor: const Color(0xFF81C784),
                          value: '${wp.liveWindSpeedKmh.toStringAsFixed(0)} km/h',
                          label: 'Wind',
                        ),
                        Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2)),
                        // ✅ Real pressure from API
                        _StatItem(
                          icon: Icons.compress_rounded,
                          iconColor: const Color(0xFFFFB74D),
                          value: '${cw.pressureMb} hPa',
                          label: 'Pressure',
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 12),

                  // ── 4-day forecast ────────────────────────────────────
                  if (wp.forecast.isNotEmpty)
                    Row(
                      children: List.generate(
                        math.min(4, wp.forecast.length),
                            (i) {
                          final f       = wp.forecast[i];
                          final fDate   = DateTime.now().add(Duration(days: i + 1));
                          final dayShort = days[fDate.weekday - 1];
                          final isLast  = i == math.min(4, wp.forecast.length) - 1;
                          return Expanded(
                            child: Row(children: [
                              Expanded(
                                child: _ForecastDayCell(
                                  day:     dayShort,
                                  condition: f.condition,
                                  // ✅ Real tempMax/tempMin from daily forecast
                                  tempMax: '${f.tempMax.toStringAsFixed(0)}°',
                                  tempMin: '${f.tempMin.toStringAsFixed(0)}°',
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 1, height: 56,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                            ]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class WeatherWidgetSmall extends StatelessWidget {
  final WeatherProvider wp;
  const WeatherWidgetSmall({super.key, required this.wp});

  @override
  Widget build(BuildContext context) {
    // ✅ THEME FIX: use liveCondition for background theme (not raw condition)
    final condition   = wp.liveCondition;
    final cw          = wp.currentWeather;
    // ✅ Use diurnal temp to match forecast screen
    final displayTemp = wp.liveTemperatureC;
    final displayCond = wp.liveCondition;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 160, height: 160,
        child: Stack(children: [
          // ✅ THEME FIX: pass liveCondition so scene matches forecast screen
          Positioned.fill(child: _WidgetSceneBackground(condition: condition)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 11),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      wp.placeName.isEmpty ? '--' : wp.placeName.split(',').first,
                      style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const Spacer(),
                // ✅ Show liveCondition icon
                AnimatedWeatherIcon(condition: displayCond, size: 48),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ✅ liveTemperatureC (diurnal) — not cw.temperatureC
                  Text(
                    cw != null ? displayTemp.toStringAsFixed(0) : '--',
                    style: GoogleFonts.dmSans(
                        color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300, height: 1),
                  ),
                  Text('°',
                      style: GoogleFonts.dmSans(
                          color: Colors.white60, fontSize: 18, fontWeight: FontWeight.w300)),
                ]),
                // ✅ liveCondition text
                Text(displayCond,
                    style: GoogleFonts.dmSans(
                        color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET SCENE BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────
class _WidgetSceneBackground extends StatefulWidget {
  final String condition;
  const _WidgetSceneBackground({required this.condition});

  @override
  State<_WidgetSceneBackground> createState() => _WidgetSceneBackgroundState();
}

class _WidgetSceneBackgroundState extends State<_WidgetSceneBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final condTheme = WeatherConditionTheme.of(widget.condition);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _WidgetBgPainter(
          condition: widget.condition.toLowerCase(),
          animProgress: _anim.value,
          skyColors: condTheme.skyGradient,
        ),
      ),
    );
  }
}

class _WidgetBgPainter extends CustomPainter {
  final String condition;
  final double animProgress;
  final List<Color> skyColors;

  _WidgetBgPainter({
    required this.condition,
    required this.animProgress,
    required this.skyColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: skyColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    switch (condition) {
      case 'rainy': case 'stormy':
      _drawNightRainyBg(canvas, size); break;
      case 'snowy': case 'cold':
      _drawSnowyBg(canvas, size); break;
      case 'sunny': case 'hot': case 'clear':
      _drawSunnyBg(canvas, size); break;
      case 'partly cloudy':
        _drawPartlyCloudyBg(canvas, size); break;
      default:
        _drawCloudyBg(canvas, size);
    }
  }

  void _drawNightRainyBg(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white;
    final rng = math.Random(7);
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final r = rng.nextDouble() * 1.5 + 0.3;
      final twinkle = (math.sin(animProgress * math.pi * 2 + i * 0.7) + 1) / 2;
      canvas.drawCircle(Offset(x, y), r, starPaint..color = Colors.white.withOpacity(0.3 + twinkle * 0.5));
    }
    final moonX = size.width * 0.78;
    final moonY = size.height * 0.18 + animProgress * 4;
    final moonR = size.width * 0.12;
    canvas.drawCircle(Offset(moonX, moonY), moonR + 8 + animProgress * 3,
        Paint()..color = const Color(0xFFFFF9C4).withOpacity(0.15));
    canvas.drawCircle(Offset(moonX, moonY), moonR,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [const Color(0xFFFFF9C4), const Color(0xFFFFE082), const Color(0xFFFFD54F)],
        ).createShader(Rect.fromCircle(center: Offset(moonX, moonY), radius: moonR)));
    canvas.drawCircle(Offset(moonX + moonR * 0.45, moonY - moonR * 0.15), moonR * 0.82,
        Paint()..color = const Color(0xFF1A2744));
    _drawStormCloud(canvas, Offset(size.width * 0.3, size.height * 0.3), size.width * 0.55, 1.0);
    _drawStormCloud(canvas, Offset(size.width * 0.72, size.height * 0.38), size.width * 0.42, 0.85);
    _drawStormCloud(canvas, Offset(size.width * 0.1, size.height * 0.42 + animProgress * 3), size.width * 0.38, 0.7);
    final rainPaint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.45)
      ..strokeWidth = 1.0..strokeCap = StrokeCap.round;
    for (int i = 0; i < 22; i++) {
      final x = (i * 137.0 % size.width);
      final progress = (animProgress * 0.8 + i / 22.0) % 1.0;
      final y = progress * (size.height + 30) - 15;
      canvas.drawLine(Offset(x - 2, y), Offset(x + 3, y + 14), rainPaint);
    }
    final groundPath = Path()
      ..moveTo(0, size.height)..lineTo(0, size.height * 0.82)
      ..cubicTo(size.width * 0.3, size.height * 0.76, size.width * 0.65, size.height * 0.80, size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)..close();
    canvas.drawPath(groundPath, Paint()..color = const Color(0xFF0D1520).withOpacity(0.9));
  }

  void _drawStormCloud(Canvas canvas, Offset center, double width, double opacity) {
    final paint = Paint()..color = const Color(0xFF2C3E60).withOpacity(opacity);
    final h = width * 0.38;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + h * 0.1), width: width, height: h * 0.65),
        Radius.circular(h * 0.32)), paint);
    canvas.drawCircle(Offset(center.dx - width * 0.22, center.dy), h * 0.42, paint);
    canvas.drawCircle(Offset(center.dx, center.dy - h * 0.22), h * 0.52, paint);
    canvas.drawCircle(Offset(center.dx + width * 0.2, center.dy - h * 0.05), h * 0.38, paint);
  }

  void _drawSunnyBg(Canvas canvas, Size size) {
    final sunX = size.width * 0.75;
    final sunY = size.height * 0.22 + animProgress * 5;
    final sunR = size.width * 0.18;
    for (int i = 3; i >= 0; i--) {
      canvas.drawCircle(Offset(sunX, sunY), sunR + i * 14 + animProgress * 5,
          Paint()..color = const Color(0xFFFFD54F).withOpacity(0.04 + i * 0.03));
    }
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2 + animProgress * 0.5;
      final p1 = Offset(sunX + math.cos(angle) * (sunR + 6), sunY + math.sin(angle) * (sunR + 6));
      final p2 = Offset(sunX + math.cos(angle) * (sunR + 18), sunY + math.sin(angle) * (sunR + 18));
      canvas.drawLine(p1, p2, Paint()..color = const Color(0xFFFFE082).withOpacity(0.6)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(Offset(sunX, sunY), sunR,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [const Color(0xFFFFF9C4), const Color(0xFFFFE082), const Color(0xFFFFC107)],
        ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: sunR)));
    _drawHills(canvas, size, const Color(0xFF388E3C), const Color(0xFF2E7D32));
  }

  void _drawPartlyCloudyBg(Canvas canvas, Size size) {
    final sunX = size.width * 0.72;
    final sunY = size.height * 0.25 + animProgress * 4;
    final sunR = size.width * 0.15;
    canvas.drawCircle(Offset(sunX, sunY), sunR + 10 + animProgress * 4,
        Paint()..color = const Color(0xFFFFD54F).withOpacity(0.3));
    canvas.drawCircle(Offset(sunX, sunY), sunR,
        Paint()..shader = RadialGradient(
          colors: [const Color(0xFFFFF9C4), const Color(0xFFFFD54F), const Color(0xFFFFC107)],
        ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: sunR)));
    _drawFluffyCloud(canvas, Offset(size.width * 0.52, size.height * 0.42 - animProgress * 3), size.width * 0.62);
    _drawHills(canvas, size, const Color(0xFFBF4700).withOpacity(0.5), const Color(0xFF8B3300).withOpacity(0.7));
  }

  void _drawCloudyBg(Canvas canvas, Size size) {
    _drawFluffyCloud(canvas, Offset(size.width * 0.4, size.height * 0.28 + animProgress * 4), size.width * 0.65);
    _drawFluffyCloud(canvas, Offset(size.width * 0.72, size.height * 0.42 - animProgress * 3), size.width * 0.45);
    _drawHills(canvas, size, const Color(0xFF546E7A).withOpacity(0.6), const Color(0xFF37474F));
  }

  void _drawSnowyBg(Canvas canvas, Size size) {
    _drawFluffyCloud(canvas, Offset(size.width * 0.4, size.height * 0.28), size.width * 0.65);
    final snowPaint = Paint()..color = Colors.white.withOpacity(0.85);
    for (int i = 0; i < 25; i++) {
      final x = (i * 97.0) % size.width;
      final progress = (animProgress * 0.5 + i / 25.0) % 1.0;
      canvas.drawCircle(Offset(x, progress * size.height), 2.0 + (i % 3), snowPaint);
    }
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.82, size.width, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.82, size.width, size.height * 0.18)),
    );
  }

  void _drawFluffyCloud(Canvas canvas, Offset center, double width) {
    final paint = Paint()..color = Colors.white.withOpacity(0.92);
    final h = width * 0.4;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy + h * 0.12), width: width, height: h * 0.62),
        Radius.circular(h * 0.31)), paint);
    canvas.drawCircle(Offset(center.dx - width * 0.22, center.dy), h * 0.4, paint);
    canvas.drawCircle(Offset(center.dx, center.dy - h * 0.22), h * 0.52, paint);
    canvas.drawCircle(Offset(center.dx + width * 0.2, center.dy - h * 0.05), h * 0.36, paint);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - width * 0.5, center.dy + h * 0.08, width, h * 0.28),
        Radius.circular(h * 0.1)),
        Paint()..color = const Color(0xFFCBDFF0).withOpacity(0.5));
  }

  void _drawHills(Canvas canvas, Size size, Color back, Color front) {
    final backPath = Path()
      ..moveTo(0, size.height)..lineTo(0, size.height * 0.72)
      ..cubicTo(size.width * 0.25, size.height * 0.58, size.width * 0.55, size.height * 0.64, size.width, size.height * 0.68)
      ..lineTo(size.width, size.height)..close();
    canvas.drawPath(backPath, Paint()..color = back);
    final frontPath = Path()
      ..moveTo(0, size.height)..lineTo(0, size.height * 0.82)
      ..cubicTo(size.width * 0.3, size.height * 0.72, size.width * 0.62, size.height * 0.76, size.width, size.height * 0.78)
      ..lineTo(size.width, size.height)..close();
    canvas.drawPath(frontPath, Paint()..color = front);
  }

  @override
  bool shouldRepaint(covariant _WidgetBgPainter old) => old.animProgress != animProgress;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: iconColor, size: 16),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: GoogleFonts.dmSans(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 10)),
      ]),
    ],
  );
}

class _ForecastDayCell extends StatelessWidget {
  final String day;
  final String condition;
  final String tempMax;
  final String tempMin;

  const _ForecastDayCell({
    required this.day,
    required this.condition,
    required this.tempMax,
    required this.tempMin,
  });

  IconData _icon(String c) {
    switch (c.toLowerCase()) {
      case 'rainy':         return Icons.water_drop_rounded;
      case 'cloudy':        return Icons.cloud_rounded;
      case 'partly cloudy': return Icons.wb_cloudy_rounded;
      case 'hot': case 'sunny': case 'clear': return Icons.wb_sunny_rounded;
      case 'cold':          return Icons.ac_unit_rounded;
      case 'stormy':        return Icons.thunderstorm_rounded;
      case 'windy':         return Icons.air_rounded;
      case 'drizzle':       return Icons.grain_rounded;
      default:              return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(children: [
      Text(day,
          style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Icon(_icon(condition), color: Colors.white, size: 22),
      const SizedBox(height: 2),
      // ✅ Real tempMax
      Text(tempMax,
          style: GoogleFonts.dmSans(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      // ✅ Real tempMin in muted colour
      Text(tempMin,
          style: GoogleFonts.dmSans(
              color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
    ]),
  );
}