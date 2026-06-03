import 'package:flutter/material.dart';

class LaserPainter extends CustomPainter {
  final Offset position;
  final double glowRadius;

  const LaserPainter({required this.position, this.glowRadius = 28});

  @override
  void paint(Canvas canvas, Size size) {
    // Outer glow
    canvas.drawCircle(
      position,
      glowRadius,
      Paint()
        ..color = const Color(0x22FF1744)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // Mid glow
    canvas.drawCircle(
      position,
      glowRadius * 0.45,
      Paint()
        ..color = const Color(0x88FF1744)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Core dot
    canvas.drawCircle(
      position,
      glowRadius * 0.18,
      Paint()..color = const Color(0xFFFF1744),
    );
    // Specular highlight
    canvas.drawCircle(
      position + Offset(-glowRadius * 0.06, -glowRadius * 0.06),
      glowRadius * 0.06,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(LaserPainter old) => old.position != position;
}
