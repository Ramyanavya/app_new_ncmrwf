// lib/widgets/wind_compass_widget.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wind Direction Compass Widget
// Animated rotating arrow inside a frosted glass circle
// Usage:
//   WindCompassWidget(
//     windDirection: 'NE',        // e.g. N, NE, E, SE, S, SW, W, NW, or degrees string
//     windSpeedKmh: 18.5,
//     accentColor: Colors.lightBlue,
//   )
// ─────────────────────────────────────────────────────────────────────────────

class WindCompassWidget extends StatefulWidget {
  final String windDirection;   // Cardinal: N / NE / E / SE / S / SW / W / NW  OR  "180°" style
  final double windSpeedKmh;
  final Color accentColor;
  final double size;

  const WindCompassWidget({
    super.key,
    required this.windDirection,
    required this.windSpeedKmh,
    this.accentColor = const Color(0xFF81C784),
    this.size = 180,
  });

  @override
  State<WindCompassWidget> createState() => _WindCompassWidgetState();
}

class _WindCompassWidgetState extends State<WindCompassWidget>
    with TickerProviderStateMixin {

  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _sweepController;
  late AnimationController _entryController;

  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _sweepAnim;
  late Animation<double> _entryFadeAnim;
  late Animation<double> _entryScaleAnim;

  double _currentAngle = 0;
  double _targetAngle  = 0;

  // ── degree conversion ──────────────────────────────────────────────────────
  static double _dirToDeg(String dir) {
    final s = dir.trim().toUpperCase().replaceAll('°', '').replaceAll(' ', '');
    // Try numeric first
    final numeric = double.tryParse(s);
    if (numeric != null) return numeric;
    // Cardinal mapping
    const map = {
      'N': 0.0,   'NNE': 22.5, 'NE': 45.0,  'ENE': 67.5,
      'E': 90.0,  'ESE': 112.5,'SE': 135.0,  'SSE': 157.5,
      'S': 180.0, 'SSW': 202.5,'SW': 225.0,  'WSW': 247.5,
      'W': 270.0, 'WNW': 292.5,'NW': 315.0,  'NNW': 337.5,
    };
    return map[s] ?? 0.0;
  }

  // ── wind speed to Beaufort description ────────────────────────────────────
  static String _beaufortLabel(double kmh) {
    if (kmh < 1)   return 'Calm';
    if (kmh < 6)   return 'Light Air';
    if (kmh < 12)  return 'Light Breeze';
    if (kmh < 20)  return 'Gentle Breeze';
    if (kmh < 29)  return 'Moderate Breeze';
    if (kmh < 39)  return 'Fresh Breeze';
    if (kmh < 50)  return 'Strong Breeze';
    if (kmh < 62)  return 'Near Gale';
    if (kmh < 75)  return 'Gale';
    if (kmh < 89)  return 'Strong Gale';
    if (kmh < 103) return 'Storm';
    return 'Violent Storm';
  }

  // Wind speed => soft glow color
  Color get _speedColor {
    final kmh = widget.windSpeedKmh;
    if (kmh < 20) return const Color(0xFF81C784);   // green – calm
    if (kmh < 40) return const Color(0xFFFFD54F);   // amber – moderate
    if (kmh < 60) return const Color(0xFFFF8A65);   // orange – strong
    return const Color(0xFFEF5350);                 // red – severe
  }

  @override
  void initState() {
    super.initState();

    _targetAngle = _dirToDeg(widget.windDirection);
    _currentAngle = _targetAngle;

    // ── Entry animation
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryFadeAnim  = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _entryScaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.elasticOut));

    // ── Arrow rotation animation (smooth dial turn)
    _rotateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _rotateAnim = Tween<double>(begin: _currentAngle, end: _targetAngle)
        .animate(CurvedAnimation(parent: _rotateController, curve: Curves.easeInOutCubic));

    // ── Pulse ring animation
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // ── Sweep arc animation (spinning outer ring)
    _sweepController = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _sweepAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _sweepController, curve: Curves.linear));

    _entryController.forward();
  }

  @override
  void didUpdateWidget(covariant WindCompassWidget old) {
    super.didUpdateWidget(old);
    final newDeg = _dirToDeg(widget.windDirection);
    if (newDeg != _targetAngle) {
      // Shortest-path rotation
      double delta = newDeg - _currentAngle;
      if (delta > 180)  delta -= 360;
      if (delta < -180) delta += 360;
      final fromAngle = _currentAngle;
      final toAngle   = _currentAngle + delta;
      _rotateAnim = Tween<double>(begin: fromAngle, end: toAngle)
          .animate(CurvedAnimation(parent: _rotateController, curve: Curves.easeInOutCubic));
      _rotateController
        ..reset()
        ..forward().then((_) => _currentAngle = newDeg % 360);
      _targetAngle = newDeg;
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _sweepController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Cardinal label from angle ──────────────────────────────────────────────
  String _angleToCardinal(double deg) {
    const labels = ['N','NNE','NE','ENE','E','ESE','SE','SSE',
      'S','SSW','SW','WSW','W','WNW','NW','NNW'];
    final idx = ((deg % 360) / 22.5).round() % 16;
    return labels[idx];
  }

  @override
  Widget build(BuildContext context) {
    final sz   = widget.size;
    final half = sz / 2;

    return FadeTransition(
      opacity: _entryFadeAnim,
      child: ScaleTransition(
        scale: _entryScaleAnim,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Wind Direction',
                          style: GoogleFonts.dmSans(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _speedColor.withOpacity(0.20),
                          border: Border.all(color: _speedColor.withOpacity(0.40), width: 1),
                        ),
                        child: Text(_beaufortLabel(widget.windSpeedKmh),
                            style: GoogleFonts.dmSans(
                                color: _speedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Compass dial
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_rotateAnim, _pulseAnim, _sweepAnim]),
                    builder: (_, __) {
                      final arrowDeg    = _rotateAnim.value;
                      final cardinalStr = _angleToCardinal(arrowDeg);

                      return SizedBox(
                        width: sz,
                        height: sz,
                        child: Stack(alignment: Alignment.center, children: [

                          // ── Outer sweeping arc ring
                          CustomPaint(
                            size: Size(sz, sz),
                            painter: _SweepRingPainter(
                              sweepAngle : _sweepAnim.value,
                              color      : _speedColor,
                              strokeWidth: 2.0,
                            ),
                          ),

                          // ── Pulsing glow circle
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, __) => Container(
                              width : sz * 0.82 * _pulseAnim.value,
                              height: sz * 0.82 * _pulseAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                boxShadow: [
                                  BoxShadow(
                                    color : _speedColor.withOpacity(0.18 * _pulseAnim.value),
                                    blurRadius  : 28,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Main compass background circle
                          Container(
                            width: sz * 0.80,
                            height: sz * 0.80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.14), width: 1.5),
                            ),
                          ),

                          // ── Compass tick marks + NESW labels
                          CustomPaint(
                            size: Size(sz, sz),
                            painter: _CompassTickPainter(
                              accentColor: _speedColor,
                            ),
                          ),

                          // ── Rotating arrow
                          Transform.rotate(
                            angle: arrowDeg * math.pi / 180,
                            child: CustomPaint(
                              size: Size(sz * 0.62, sz * 0.62),
                              painter: _ArrowPainter(
                                color: _speedColor,
                                glowColor: _speedColor.withOpacity(0.5),
                              ),
                            ),
                          ),

                          // ── Center hub
                          Container(
                            width: sz * 0.10,
                            height: sz * 0.10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _speedColor,
                              boxShadow: [
                                BoxShadow(
                                  color     : _speedColor.withOpacity(0.6),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),

                          // ── Cardinal direction label overlay (bottom)
                          Positioned(
                            bottom: sz * 0.04,
                            child: Column(
                              children: [
                                Text(cardinalStr,
                                    style: GoogleFonts.dmSans(
                                        color: _speedColor,
                                        fontSize: sz * 0.11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                              color: _speedColor.withOpacity(0.7),
                                              blurRadius: 10)
                                        ])),
                              ],
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Speed display row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.air_rounded, color: _speedColor, size: 18),
                      const SizedBox(width: 6),
                      Text(widget.windSpeedKmh.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w200,
                              height: 1.0)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('km/h',
                            style: GoogleFonts.dmSans(
                                color: Colors.white54, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow painter — points UP (north) at 0°, rotates clockwise
// ─────────────────────────────────────────────────────────────────────────────
class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color glowColor;
  const _ArrowPainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // ── Shadow / glow under arrow
    final glowPaint = Paint()
      ..color     = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // ── North pointer (colored, pointing up)
    final northPath = Path();
    northPath.moveTo(cx, cy - r * 0.80);            // tip
    northPath.lineTo(cx + r * 0.13, cy - r * 0.05); // right base
    northPath.lineTo(cx, cy + r * 0.12);             // bottom notch
    northPath.lineTo(cx - r * 0.13, cy - r * 0.05); // left base
    northPath.close();

    canvas.drawPath(northPath, glowPaint);
    canvas.drawPath(northPath, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(northPath, Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    // ── South pointer (white/muted, pointing down)
    final southPath = Path();
    southPath.moveTo(cx, cy + r * 0.80);            // tip (down)
    southPath.lineTo(cx + r * 0.13, cy + r * 0.05); // right base
    southPath.lineTo(cx, cy - r * 0.12);             // top notch
    southPath.lineTo(cx - r * 0.13, cy + r * 0.05); // left base
    southPath.close();

    canvas.drawPath(southPath, Paint()
      ..color = Colors.white.withOpacity(0.28)..style = PaintingStyle.fill);
    canvas.drawPath(southPath, Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.color != color || old.glowColor != glowColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Compass tick marks + N/E/S/W labels
// ─────────────────────────────────────────────────────────────────────────────
class _CompassTickPainter extends CustomPainter {
  final Color accentColor;
  const _CompassTickPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    final outer  = size.width * 0.40;  // radius to outer edge of tick
    final inner  = size.width * 0.35;  // radius to inner edge of tick
    final innerSmall = size.width * 0.375;

    const cardinals = ['N', 'E', 'S', 'W'];

    for (int i = 0; i < 36; i++) {
      final angle    = i * 10.0 * math.pi / 180;
      final isCard   = i % 9 == 0;
      final isSubCard = i % 3 == 0;

      final tickInner = isCard ? inner : (isSubCard ? innerSmall : size.width * 0.385);
      final sin = math.sin(angle);
      final cos = math.cos(angle);

      final p1 = Offset(cx + outer * sin, cy - outer * cos);
      final p2 = Offset(cx + tickInner * sin, cy - tickInner * cos);

      final paint = Paint()
        ..color = isCard
            ? accentColor.withOpacity(0.85)
            : (isSubCard ? Colors.white.withOpacity(0.40) : Colors.white.withOpacity(0.18))
        ..strokeWidth = isCard ? 1.8 : (isSubCard ? 1.1 : 0.7)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }

    // ── N/E/S/W labels
    final labelR = size.width * 0.29;
    for (int i = 0; i < 4; i++) {
      final angle = i * 90.0 * math.pi / 180;
      final lx    = cx + labelR * math.sin(angle);
      final ly    = cy - labelR * math.cos(angle);

      final isNorth = i == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            color : isNorth ? accentColor : Colors.white.withOpacity(0.70),
            fontSize: size.width * 0.085,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CompassTickPainter old) => old.accentColor != accentColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sweeping arc ring
// ─────────────────────────────────────────────────────────────────────────────
class _SweepRingPainter extends CustomPainter {
  final double sweepAngle;
  final Color  color;
  final double strokeWidth;

  const _SweepRingPainter({
    required this.sweepAngle,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final r    = size.width / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Faint full ring base
    canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()
      ..color       = color.withOpacity(0.10)
      ..strokeWidth = strokeWidth * 0.6
      ..style       = PaintingStyle.stroke);

    // ── Moving bright arc (90°)
    const arcSpan = math.pi / 2;
    canvas.drawArc(rect, sweepAngle, arcSpan, false, Paint()
      ..shader = SweepGradient(
        startAngle : sweepAngle,
        endAngle   : sweepAngle + arcSpan,
        colors     : [color.withOpacity(0.0), color.withOpacity(0.8)],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _SweepRingPainter old) =>
      old.sweepAngle != sweepAngle || old.color != color;
}