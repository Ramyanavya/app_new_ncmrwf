// lib/utils/weather_icon_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Maps raw API condition strings → canonical keys ───────────────────────────
String normalizeCondition(String raw) {
  final c = raw.toLowerCase().trim();
  if (c.contains('thunder') || c.contains('storm') || c.contains('lightning')) return 'stormy';
  if (c.contains('snow') || c.contains('sleet') || c.contains('hail') || c.contains('blizzard')) return 'snowy';
  if (c.contains('rain') || c.contains('shower') || c.contains('drizzle') || c.contains('precip')) return 'rainy';
  // ── mist/fog/haze → show cloudy icon (not fog lines which look like broken UI) ──
  if (c.contains('mist') || c.contains('fog') || c.contains('haze') || c.contains('smoke')) return 'cloudy';
  if (c.contains('cold') || c.contains('freeze') || c.contains('frost') || c.contains('ice')) return 'snowy';
  if (c.contains('wind') || c.contains('gale') || c.contains('breezy')) return 'windy';
  if (c.contains('partly') || c.contains('partial') || c.contains('scattered')) return 'partly cloudy';
  if (c.contains('cloud') || c.contains('overcast')) return 'cloudy';
  if (c.contains('sun') || c.contains('clear') || c.contains('fair') ||
      c.contains('hot') || c.contains('warm') || c.contains('bright')) return 'sunny';
  // ── default: show partly cloudy instead of blank ──
  return 'partly cloudy';
}

// ─────────────────────────────────────────────────────────────────────────────
class AnimatedWeatherIcon extends StatefulWidget {
  final String condition;
  final double size;
  const AnimatedWeatherIcon({super.key, required this.condition, this.size = 120});

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _rainCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 18000))..repeat();
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _rainCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    _rainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _rotateCtrl, _pulseCtrl, _rainCtrl]),
      builder: (_, __) {
        final floatY = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut).value;
        return Transform.translate(
          offset: Offset(0, floatY * 8 - 4),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _WeatherPainter(
                condition:  normalizeCondition(widget.condition),
                rotateProg: _rotateCtrl.value,
                pulseProg:  CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut).value,
                rainProg:   _rainCtrl.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _WeatherPainter extends CustomPainter {
  final String condition;
  final double rotateProg, pulseProg, rainProg;

  const _WeatherPainter({
    required this.condition,
    required this.rotateProg,
    required this.pulseProg,
    required this.rainProg,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    switch (condition) {
      case 'sunny':         _drawSun(canvas, sz);          break;
      case 'partly cloudy': _drawPartlyCloudy(canvas, sz); break;
      case 'cloudy':        _drawCloudy(canvas, sz);       break;
      case 'rainy':         _drawRainy(canvas, sz);        break;
      case 'stormy':        _drawStormy(canvas, sz);       break;
      case 'snowy':         _drawSnowy(canvas, sz);        break;
      case 'windy':         _drawWindy(canvas, sz);        break;
    // foggy is intentionally kept but now only reached if explicitly needed
      case 'foggy':         _drawFoggy(canvas, sz);        break;
      default:              _drawPartlyCloudy(canvas, sz);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUN
  // ══════════════════════════════════════════════════════════════════════════
  void _drawSun(Canvas canvas, Size sz) {
    final cx = sz.width  * 0.50;
    final cy = sz.height * 0.50;
    final r  = sz.width  * 0.26;

    canvas.drawCircle(Offset(cx, cy), r + 20 + pulseProg * 5,
        Paint()
          ..color = const Color(0xFFFFD54F).withOpacity(0.09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(cx, cy), r + 10 + pulseProg * 3,
        Paint()
          ..color = const Color(0xFFFFCA28).withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotateProg * math.pi * 2);
    final rp = Paint()
      ..color = const Color(0xFFFFD740).withOpacity(0.95)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2;
      canvas.drawLine(
        Offset(math.cos(angle) * (r + 8),  math.sin(angle) * (r + 8)),
        Offset(math.cos(angle) * (r + 21), math.sin(angle) * (r + 21)),
        rp,
      );
    }
    canvas.restore();

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.20, -0.22),
          colors: const [
            Color(0xFFFFFDE7),
            Color(0xFFFFEE58),
            Color(0xFFFFD740),
            Color(0xFFFFC400),
          ],
          stops: const [0.0, 0.28, 0.58, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.30, cy - r * 0.30),
        width:  r * 0.38,
        height: r * 0.20,
      ),
      Paint()..color = Colors.white.withOpacity(0.42),
    );

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = const Color(0xFFFFCA28).withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PARTLY CLOUDY
  // ══════════════════════════════════════════════════════════════════════════
  void _drawPartlyCloudy(Canvas canvas, Size sz) {
    final sx = sz.width * 0.64, sy = sz.height * 0.33, sr = sz.width * 0.21;
    canvas.drawCircle(Offset(sx, sy), sr + 8 + pulseProg * 4,
        Paint()..color = const Color(0xFFFFD54F).withOpacity(0.18));
    canvas.drawCircle(Offset(sx, sy), sr,
        Paint()..shader = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          colors: const [Color(0xFFFFFDE7), Color(0xFFFFE57F), Color(0xFFFFC400)],
        ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: sr)));
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(rotateProg * math.pi * 2);
    for (int i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2;
      canvas.drawLine(
        Offset(math.cos(a) * (sr + 5),  math.sin(a) * (sr + 5)),
        Offset(math.cos(a) * (sr + 13), math.sin(a) * (sr + 13)),
        Paint()..color = const Color(0xFFFFD740).withOpacity(0.90)..strokeWidth = 2.2..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    _whiteCloud(canvas, Offset(sz.width * 0.40, sz.height * 0.63), sz.width * 0.72);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLOUDY — now also used for mist/fog/haze
  // ══════════════════════════════════════════════════════════════════════════
  void _drawCloudy(Canvas canvas, Size sz) {
    _whiteCloud(canvas, Offset(sz.width * 0.55, sz.height * 0.43), sz.width * 0.52, opacity: 0.65);
    _whiteCloud(canvas, Offset(sz.width * 0.42, sz.height * 0.61), sz.width * 0.78);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RAINY
  // ══════════════════════════════════════════════════════════════════════════
  void _drawRainy(Canvas canvas, Size sz) {
    _blueCloud(canvas, Offset(sz.width * 0.50, sz.height * 0.40), sz.width * 0.82);
    final p = Paint()..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    const xf = [0.22, 0.35, 0.49, 0.63, 0.75, 0.42];
    for (int i = 0; i < xf.length; i++) {
      final off = (rainProg + i * 0.17) % 1.0;
      final x = sz.width * xf[i];
      final y0 = sz.height * (0.64 + off * 0.26);
      final y1 = y0 + sz.height * 0.10;
      if (y1 < sz.height - 2) {
        canvas.drawLine(Offset(x - 2, y0), Offset(x - 5, y1),
            p..color = const Color(0xFF90CAF9).withOpacity(0.42 + off * 0.55));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STORMY
  // ══════════════════════════════════════════════════════════════════════════
  void _drawStormy(Canvas canvas, Size sz) {
    _blueCloud(canvas, Offset(sz.width * 0.50, sz.height * 0.36), sz.width * 0.84, dark: true);
    final rp = Paint()..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    const rf = [0.24, 0.43, 0.65, 0.77];
    for (int i = 0; i < rf.length; i++) {
      final off = (rainProg + i * 0.25) % 1.0;
      final x = sz.width * rf[i];
      final y0 = sz.height * (0.60 + off * 0.22);
      final y1 = y0 + sz.height * 0.09;
      if (y1 < sz.height - 2) {
        canvas.drawLine(Offset(x - 2, y0), Offset(x - 4, y1),
            rp..color = const Color(0xFF90CAF9).withOpacity(0.40 + off * 0.40));
      }
    }
    if (pulseProg > 0.25) {
      final op = ((pulseProg - 0.25) / 0.75).clamp(0.0, 1.0);
      final bolt = Path()
        ..moveTo(sz.width * 0.55, sz.height * 0.56)
        ..lineTo(sz.width * 0.44, sz.height * 0.73)
        ..lineTo(sz.width * 0.53, sz.height * 0.71)
        ..lineTo(sz.width * 0.42, sz.height * 0.91);
      canvas.drawPath(bolt,
          Paint()..color = const Color(0xFFFFEE58).withOpacity(0.28 * op)
            ..strokeWidth = 13..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke);
      canvas.drawPath(bolt,
          Paint()..color = const Color(0xFFFFF176).withOpacity(op)
            ..strokeWidth = 3.5..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SNOWY
  // ══════════════════════════════════════════════════════════════════════════
  void _drawSnowy(Canvas canvas, Size sz) {
    _whiteCloud(canvas, Offset(sz.width * 0.48, sz.height * 0.40), sz.width * 0.80);
    final sp = Paint()..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    const sf = [0.25, 0.40, 0.56, 0.70, 0.38, 0.62];
    for (int i = 0; i < sf.length; i++) {
      final off = (rainProg + i * 0.18) % 1.0;
      final x = sz.width * sf[i];
      final y = sz.height * (0.63 + off * 0.26);
      if (y < sz.height - 4) {
        _snowflake(canvas, Offset(x, y), 5.5,
            sp..color = Colors.white.withOpacity(0.70 + off * 0.30));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WINDY
  // ══════════════════════════════════════════════════════════════════════════
  void _drawWindy(Canvas canvas, Size sz) {
    final lp = Paint()..strokeWidth = 3.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final lines = [
      [0.08, 0.33, 0.78, 0.33, 0.90],
      [0.04, 0.48, 0.88, 0.48, 0.70],
      [0.10, 0.63, 0.70, 0.63, 0.50],
      [0.15, 0.78, 0.55, 0.78, 0.32],
    ];
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      final s = math.sin(rainProg * math.pi * 2 + i * 0.8) * 4;
      final path = Path()..moveTo(sz.width * l[0], sz.height * l[1] + s);
      path.cubicTo(
        sz.width * (l[0] + (l[2] - l[0]) * 0.33), sz.height * l[1] - 10 + s,
        sz.width * (l[0] + (l[2] - l[0]) * 0.66), sz.height * l[1] + 10 + s,
        sz.width * l[2], sz.height * l[3] + s,
      );
      canvas.drawPath(path, lp..color = Colors.white.withOpacity(l[4]));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOGGY (kept for explicit use only — mist/fog/haze now map to 'cloudy')
  // ══════════════════════════════════════════════════════════════════════════
  void _drawFoggy(Canvas canvas, Size sz) {
    // Draw a cloud base first so it doesn't look like broken UI
    _whiteCloud(canvas, Offset(sz.width * 0.50, sz.height * 0.38), sz.width * 0.80, opacity: 0.7);
    // Then draw subtle fog lines below
    final lp = Paint()..strokeWidth = 7..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    const ys = [0.58, 0.68, 0.78, 0.88];
    for (int i = 0; i < ys.length; i++) {
      final wave = math.sin(rainProg * math.pi * 2 + i * 0.5) * 2;
      final widthFactor = 0.7 - i * 0.05;
      final xStart = sz.width * (0.5 - widthFactor / 2);
      final xEnd   = sz.width * (0.5 + widthFactor / 2);
      canvas.drawLine(
        Offset(xStart, sz.height * ys[i] + wave),
        Offset(xEnd,   sz.height * ys[i] + wave),
        lp..color = Colors.white.withOpacity(0.18 + (3 - i) * 0.04),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLOUD HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  void _whiteCloud(Canvas canvas, Offset c, double w, {double opacity = 1.0}) {
    final h = w * 0.44;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + h * 0.64), width: w * 0.72, height: h * 0.18),
      Paint()..color = const Color(0xFFB0C4DE).withOpacity(0.28 * opacity),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + h * 0.12), width: w, height: h * 0.60),
        Radius.circular(h * 0.30),
      ),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(opacity), const Color(0xFFDEEEFA).withOpacity(opacity)],
      ).createShader(Rect.fromCenter(center: c, width: w, height: h)),
    );
    final bp = Paint()..color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(Offset(c.dx - w * 0.23, c.dy - h * 0.02), h * 0.36, bp);
    canvas.drawCircle(Offset(c.dx - w * 0.04, c.dy - h * 0.22), h * 0.50, bp);
    canvas.drawCircle(Offset(c.dx + w * 0.18, c.dy - h * 0.08), h * 0.38, bp);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.48, c.dy + h * 0.08, w * 0.96, h * 0.22),
        Radius.circular(h * 0.10),
      ),
      Paint()..color = const Color(0xFFCBDFF0).withOpacity(0.55 * opacity),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx - h * 0.12, c.dy - h * 0.28), width: h * 0.22, height: h * 0.12),
      Paint()..color = Colors.white.withOpacity(0.65 * opacity),
    );
  }

  void _blueCloud(Canvas canvas, Offset c, double w, {bool dark = false}) {
    final h   = w * 0.46;
    final top = dark ? const Color(0xFF3D5A80) : const Color(0xFF5B7FA6);
    final bot = dark ? const Color(0xFF1E2D40) : const Color(0xFF3A6186);
    final bmp = dark ? const Color(0xFF4A6D90) : const Color(0xFF6B9EC7);
    final shn = dark ? const Color(0xFF7AA8CC) : const Color(0xFF9BC8E8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + h * 0.68), width: w * 0.80, height: h * 0.20),
      Paint()..color = Colors.black.withOpacity(0.20),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(c.dx, c.dy + h * 0.12), width: w, height: h * 0.62),
        Radius.circular(h * 0.30),
      ),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [top, bot]).createShader(Rect.fromCenter(center: c, width: w, height: h)),
    );
    Shader bsh(Offset center, double r) => RadialGradient(
      center: const Alignment(-0.3, -0.4), colors: [bmp, bot],
    ).createShader(Rect.fromCircle(center: center, radius: r));
    final bl = Offset(c.dx - w * 0.24, c.dy - h * 0.02);
    canvas.drawCircle(bl, h * 0.40, Paint()..shader = bsh(bl, h * 0.40));
    final bc = Offset(c.dx - w * 0.04, c.dy - h * 0.26);
    canvas.drawCircle(bc, h * 0.52, Paint()..shader = bsh(bc, h * 0.52));
    final br = Offset(c.dx + w * 0.20, c.dy - h * 0.10);
    canvas.drawCircle(br, h * 0.38, Paint()..shader = bsh(br, h * 0.38));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - w * 0.48, c.dy + h * 0.10, w * 0.96, h * 0.20),
        Radius.circular(h * 0.09),
      ),
      Paint()..color = bot.withOpacity(0.85),
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - w * 0.07, c.dy - h * 0.42), width: h * 0.28, height: h * 0.13),
        Paint()..color = shn.withOpacity(0.58));
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - w * 0.26, c.dy - h * 0.16), width: h * 0.18, height: h * 0.09),
        Paint()..color = shn.withOpacity(0.42));
  }

  void _snowflake(Canvas canvas, Offset c, double r, Paint p) {
    for (int i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2;
      canvas.drawLine(Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
          Offset(c.dx - math.cos(a) * r, c.dy - math.sin(a) * r), p);
    }
    canvas.drawCircle(c, 2.0, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter o) =>
      o.condition != condition || o.rotateProg != rotateProg ||
          o.pulseProg != pulseProg || o.rainProg != rainProg;
}