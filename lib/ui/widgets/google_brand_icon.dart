import 'dart:math';
import 'package:flutter/material.dart';

/// Pixel-perfect vector Google "G" logo rendered via CustomPainter.
/// Zero asset network dependency, zero blur, sharp on all pixel densities.
class GoogleBrandIcon extends StatelessWidget {
  final double size;

  const GoogleBrandIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = min(w, h) / 2;

    // Google Brand Colors
    const Color blue = Color(0xFF4285F4);
    const Color red = Color(0xFFEA4335);
    const Color yellow = Color(0xFFFBBC05);
    const Color green = Color(0xFF34A853);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.44
      ..strokeCap = StrokeCap.butt;

    final Rect rect = Rect.fromCircle(center: center, radius: radius * 0.78);

    // Blue arc (Right & top-right)
    paint.color = blue;
    canvas.drawArc(rect, -pi / 6, pi / 2.2, false, paint);

    // Green arc (Bottom)
    paint.color = green;
    canvas.drawArc(rect, pi / 3.2, pi / 2.3, false, paint);

    // Yellow arc (Bottom-left)
    paint.color = yellow;
    canvas.drawArc(rect, 3 * pi / 4, pi / 2.5, false, paint);

    // Red arc (Top & top-left)
    paint.color = red;
    canvas.drawArc(rect, 1.15 * pi, pi / 1.7, false, paint);

    // Blue horizontal bar
    final Paint barPaint = Paint()
      ..color = blue
      ..style = PaintingStyle.fill;

    final double barThickness = radius * 0.44;
    final double barWidth = radius * 0.85;
    final Rect barRect = Rect.fromLTWH(
      center.dx,
      center.dy - barThickness / 2,
      barWidth,
      barThickness,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

