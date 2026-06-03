import 'package:flutter/material.dart';

class PawPainter extends CustomPainter {
  final double scale;
  final double opacity;

  const PawPainter({this.scale = 1.0, this.opacity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final paint = Paint()..color = Colors.white.withValues(alpha: opacity * 0.9);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-cx, -cy);

    // Main pad — large oval, bottom-centre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.22), width: r * 1.1, height: r * 0.9),
      paint,
    );

    // Toe beans — three across the top, one on each side
    final toePositions = [
      Offset(cx - r * 0.54, cy - r * 0.30),
      Offset(cx,            cy - r * 0.58),
      Offset(cx + r * 0.54, cy - r * 0.30),
    ];
    for (final pos in toePositions) {
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: r * 0.42, height: r * 0.48),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PawPainter old) => old.scale != scale || old.opacity != opacity;
}
