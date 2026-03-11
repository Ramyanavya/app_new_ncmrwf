import 'package:flutter/material.dart';

class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;

  const WeatherIcon({super.key, required this.condition, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Text(
      _emoji(condition),
      style: TextStyle(fontSize: size),
    );
  }

  static String _emoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'rainy':
        return '🌧️';
      case 'cloudy':
        return '☁️';
      case 'partly cloudy':
        return '⛅';
      case 'hot':
        return '☀️';
      case 'cold':
        return '🌨️';
      case 'thunderstorm':
        return '⛈️';
      default:
        return '🌤️';
    }
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF2A4A5A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}
