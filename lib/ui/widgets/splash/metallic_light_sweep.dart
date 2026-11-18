import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders a dynamic metallic light sweep / specular reflection across child widgets.
class MetallicLightSweep extends StatelessWidget {
  final Widget child;
  /// Progress of the sweep: -1.0 is fully to the left/top, 2.0 is fully off to the right/bottom.
  final double sweepProgress;
  /// Overall opacity of the metallic reflection.
  final double intensity;

  const MetallicLightSweep({
    super.key,
    required this.child,
    required this.sweepProgress,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.001) return child;

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final double width = bounds.width;
        final double height = bounds.height;
        final double diagonal = math.sqrt(width * width + height * height);

        // Sweep center shifts from -0.5 * diagonal to 1.5 * diagonal
        final double center = sweepProgress * diagonal;
        final double beamWidth = diagonal * 0.35;

        final double start = ((center - beamWidth) / diagonal).clamp(-0.5, 1.5);
        final double peak = (center / diagonal).clamp(-0.5, 1.5);
        final double end = ((center + beamWidth) / diagonal).clamp(-0.5, 1.5);

        return LinearGradient(
          begin: const Alignment(-1.0, -1.0),
          end: const Alignment(1.0, 1.0),
          colors: [
            Colors.transparent,
            const Color(0xFFFFE6A0).withValues(alpha: 0.15 * intensity),
            const Color(0xFFFFFFFF).withValues(alpha: 0.65 * intensity),
            const Color(0xFFFFD700).withValues(alpha: 0.30 * intensity),
            Colors.transparent,
          ],
          stops: [
            (start).clamp(0.0, 1.0),
            ((start + peak) / 2).clamp(0.0, 1.0),
            peak.clamp(0.0, 1.0),
            ((peak + end) / 2).clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// Photorealistic crown specular diamond glint flare.
class SpecularCrownGlint extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;

  const SpecularCrownGlint({
    super.key,
    required this.progress,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001 || progress >= 0.999) {
      return const SizedBox.shrink();
    }

    // Triangular bell curve for glint opacity: peaks at 0.5
    final double alpha = (1.0 - (progress - 0.5).abs() * 2.0).clamp(0.0, 1.0);
    final double scale = 0.5 + 0.8 * math.sin(progress * math.pi);

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SpecularGlintPainter(alpha: alpha),
        ),
      ),
    );
  }
}

class _SpecularGlintPainter extends CustomPainter {
  final double alpha;

  _SpecularGlintPainter({required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.01) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Core radial soft glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95 * alpha),
          const Color(0xFFFFD700).withValues(alpha: 0.65 * alpha),
          const Color(0xFFF5B82E).withValues(alpha: 0.25 * alpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, glowPaint);

    // 2. Horizontal anamorphic light streak
    final streakPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.90 * alpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, center.dy - 1.2, size.width, 2.4));

    canvas.drawRect(
      Rect.fromLTWH(0, center.dy - 1.2, size.width, 2.4),
      streakPaint,
    );

    // 3. Vertical diamond streak
    final vertStreakPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.90 * alpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(center.dx - 1.2, 0, 2.4, size.height));

    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1.2, 0, 2.4, size.height),
      vertStreakPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpecularGlintPainter oldDelegate) {
    return oldDelegate.alpha != alpha;
  }
}
