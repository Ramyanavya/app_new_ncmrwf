
import 'package:flutter/material.dart';
import '../models/weather_model.dart';

class TempTrendChart extends StatefulWidget {
  final List<TrendPoint> trend;
  final double minTemp;
  final double maxTemp;

  const TempTrendChart({
    super.key,
    required this.trend,
    required this.minTemp,
    required this.maxTemp,
  });

  @override
  State<TempTrendChart> createState() => _TempTrendChartState();
}

class _TempTrendChartState extends State<TempTrendChart> {
  int _selDay = 0;

  List<TrendPoint> get _limited {
    if (widget.trend.length <= 10) return widget.trend;
    final result = <TrendPoint>[];
    final step = (widget.trend.length - 1) / 9;
    for (int i = 0; i < 10; i++) {
      result.add(widget.trend[(i * step).round()]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trend.isEmpty) return const SizedBox.shrink();
    final data = _limited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Temperature Trend',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Tap to select day',
              style: TextStyle(color: Colors.white.withOpacity(0.30), fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text('Level: 925mb  •  Location',
            style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
        const SizedBox(height: 14),
        GestureDetector(
          onTapDown: (d) {
            final w = context.size?.width ?? 300;
            final idx = ((d.localPosition.dx / w) * (data.length - 1))
                .round().clamp(0, data.length - 1);
            setState(() => _selDay = idx);
          },
          child: SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _GraphPainter(
                trend:  data,
                mn:     widget.minTemp - 2,
                mx:     widget.maxTemp + 2,
                range:  (widget.maxTemp + 2) - (widget.minTemp - 2),
                sel:    _selDay,
                accent: const Color(0xFF4ECDC4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Min: ${widget.minTemp.toStringAsFixed(1)}°C',
              style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
          Text('Max: ${widget.maxTemp.toStringAsFixed(1)}°C',
              style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11)),
        ]),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<TrendPoint> trend;
  final double mn, mx, range;
  final int sel;
  final Color accent;

  _GraphPainter({
    required this.trend, required this.mn, required this.mx,
    required this.range, required this.sel, required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty || range == 0) return;

    const double padH   = 20.0;
    const double padTop = 28.0;
    const double padBot = 22.0;
    final double gW = size.width - padH * 2;
    final double gH = size.height - padTop - padBot;

    final pts = <Offset>[];
    for (int i = 0; i < trend.length; i++) {
      pts.add(Offset(
        padH + (i / (trend.length - 1)) * gW,
        padTop + (1 - (trend[i].temperatureC - mn) / range) * gH,
      ));
    }

    // gradient fill
    final fill = Path()..moveTo(pts.first.dx, size.height - padBot);
    fill.lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      fill.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    fill.lineTo(pts.last.dx, size.height - padBot);
    fill.close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.28), accent.withOpacity(0.03)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i-1].dy);
      final cp2 = Offset((pts[i-1].dx + pts[i].dx) / 2, pts[i].dy);
      line.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(line, Paint()
      ..color = accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // dots + labels
    for (int i = 0; i < pts.length; i++) {
      final isSel = i == sel;

      if (isSel) {
        // dashed vertical line
        double yy = padTop;
        while (yy < size.height - padBot) {
          canvas.drawLine(Offset(pts[i].dx, yy), Offset(pts[i].dx, yy + 4),
              Paint()..color = accent.withOpacity(0.30)..strokeWidth = 1.0);
          yy += 8;
        }
        
        canvas.drawCircle(pts[i], 10, Paint()..color = accent.withOpacity(0.18));
        canvas.drawCircle(pts[i], 6,  Paint()..color = accent);
        canvas.drawCircle(pts[i], 3,  Paint()..color = Colors.white);
      } else {
     
        canvas.drawCircle(pts[i], 4.5, Paint()..color = const Color(0xFF1A3A4A));
        canvas.drawCircle(pts[i], 4.5, Paint()
          ..color = accent.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
      }

   
      final tp = TextPainter(
        text: TextSpan(
          text: "${trend[i].temperatureC.toStringAsFixed(0)}°",
          style: TextStyle(
            color: isSel ? Colors.white : Colors.white.withOpacity(0.78),
            fontSize: isSel ? 12.0 : 10.5,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, pts[i].dy - padTop + 2));

   
      final dp = TextPainter(
        text: TextSpan(
          text: trend[i].day,
          style: TextStyle(
            color: isSel ? accent : Colors.white.withOpacity(0.38),
            fontSize: 10,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dp.paint(canvas, Offset(pts[i].dx - dp.width / 2, size.height - padBot + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter o) =>
      o.sel != sel || o.trend != trend || o.accent != accent;
}
