import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pre-allocated particle model for high-efficiency 60–120 FPS canvas rendering
/// with zero object allocation during animation frame ticks.
class GoldenParticle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double phase;
  final double baseAlpha;
  final Color color;

  const GoldenParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.baseAlpha,
    required this.color,
  });

  /// Generates a deterministic list of luxury gold ambient dust particles.
  static List<GoldenParticle> createParticlePool({int count = 28}) {
    final rng = math.Random(1337);
    const goldPalette = [
      Color(0xFFFFD700), // Royal Gold
      Color(0xFFFFE6A0), // Champagne Gold
      Color(0xFFF5B82E), // Metallic Gold
      Color(0xFFE88A00), // Golden Orange
    ];

    return List.generate(count, (index) {
      return GoldenParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.0 + rng.nextDouble() * 2.0,
        speed: 0.15 + rng.nextDouble() * 0.25,
        drift: 0.015 + rng.nextDouble() * 0.025,
        phase: rng.nextDouble() * math.pi * 2,
        baseAlpha: 0.35 + rng.nextDouble() * 0.55,
        color: goldPalette[index % goldPalette.length],
      );
    });
  }
}

/// Photorealistic ambient golden dust particle painter.
class CinematicParticlesPainter extends CustomPainter {
  final List<GoldenParticle> particles;
  final double progress;
  final double masterAlpha;

  CinematicParticlesPainter({
    required this.particles,
    required this.progress,
    required this.masterAlpha,
  });

  static final Paint _particlePaint = Paint()..isAntiAlias = true;
  static final Paint _glowPaint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (masterAlpha <= 0.001 || size.isEmpty) return;

    final w = size.width;
    final h = size.height;

    for (final p in particles) {
      // Sinusoidal floating drift
      final xOffset = math.sin(progress * 2 * math.pi + p.phase) * p.drift * w;
      final curX = (p.x * w + xOffset) % w;

      // Upward floating motion with smooth wrapping
      final curY = ((p.y - progress * p.speed) % 1.0) * h;

      // Soft sparkling twinkling modulation
      final twinkle = 0.7 + 0.3 * math.sin(progress * 8 * math.pi + p.phase * 3);
      final alpha = (p.baseAlpha * masterAlpha * twinkle).clamp(0.0, 1.0);

      if (alpha <= 0.01) continue;

      final center = Offset(curX, curY);

      // Outer ambient gold glow
      _glowPaint.color = p.color.withValues(alpha: alpha * 0.35);
      canvas.drawCircle(center, p.radius * 2.2, _glowPaint);

      // Core particle
      _particlePaint.color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(center, p.radius, _particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CinematicParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.masterAlpha != masterAlpha;
  }
}
