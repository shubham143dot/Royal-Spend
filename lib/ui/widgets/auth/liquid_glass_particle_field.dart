import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/liquid_auth_colors.dart';

/// Floating Particle Data Structure adapted from `Ag1rin/login_glass_app`.
class FloatingGlassParticle {
  final int id;
  double baseX, baseY;
  final double size;
  final double speed;
  final double phase;
  final double opacity;

  FloatingGlassParticle({
    required this.id,
    required this.baseX,
    required this.baseY,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
  });

  /// Harmonic oscillation calculation adapted from Ag1rin/login_glass_app
  double calculateX(double animValue, double screenWidth) {
    final swayX = math.sin(animValue * 2 * math.pi * speed + phase) * 75;
    return (baseX + swayX).clamp(0.0, screenWidth - size);
  }

  double calculateY(double animValue, double screenHeight) {
    final swayY = math.cos(animValue * 2 * math.pi * speed + phase) * 85;
    return (baseY + swayY).clamp(0.0, screenHeight - size);
  }
}

/// Interactive Floating Liquid Glass Particle Field.
///
/// Adapted from `https://github.com/Ag1rin/login_glass_app`:
/// - Harmonic floating motion using sine and cosine waves.
/// - Interactive touch mechanics: Tap position tracking with fleeing/repulsion effect.
/// - Pure neutral silver and translucent white particles (NO blue, NO golden).
/// - Wrapped in a [RepaintBoundary] to ensure 60/120 FPS performance over background video.
class InteractiveGlassParticleField extends StatefulWidget {
  final Widget? child;
  final int particleCount;

  const InteractiveGlassParticleField({
    super.key,
    this.child,
    this.particleCount = 14,
  });

  @override
  State<InteractiveGlassParticleField> createState() =>
      InteractiveGlassParticleFieldState();
}

class InteractiveGlassParticleFieldState
    extends State<InteractiveGlassParticleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;
  final List<FloatingGlassParticle> _particles = [];
  Offset? _lastTapPosition;
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _initParticles();
  }

  void _initParticles() {
    final random = math.Random();
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(
        FloatingGlassParticle(
          id: i,
          baseX: random.nextDouble() * 400,
          baseY: random.nextDouble() * 800,
          size: random.nextDouble() * 18 + 8, // 8dp to 26dp diameter
          speed: random.nextDouble() * 0.4 + 0.3,
          phase: random.nextDouble() * 2 * math.pi,
          opacity: random.nextDouble() * 0.25 + 0.08, // Subtle 8% to 33%
        ),
      );
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  /// Interactive touch mechanics from Ag1rin/login_glass_app:
  /// Repels particles away from the touch location with smooth fading.
  void handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() {
      _lastTapPosition = details.localPosition;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _lastTapPosition = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Rescale base coordinates when screen geometry changes
    if (_lastScreenSize != null &&
        (_lastScreenSize!.width != size.width ||
            _lastScreenSize!.height != size.height)) {
      for (final p in _particles) {
        p.baseX = (p.baseX / _lastScreenSize!.width) * size.width;
        p.baseY = (p.baseY / _lastScreenSize!.height) * size.height;
      }
    }
    _lastScreenSize = size;

    if (reduceMotion) {
      return widget.child ?? const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: handleTapDown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Floating Liquid Glass Particles Layer
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                final animValue = _particleController.value;

                return CustomPaint(
                  size: size,
                  painter: _ParticleFieldPainter(
                    particles: _particles,
                    animValue: animValue,
                    screenSize: size,
                    lastTapPosition: _lastTapPosition,
                  ),
                );
              },
            ),
          ),

          // Content overlay
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

/// Photorealistic Glass Particle Painter: renders subtle translucent white & soft silver bubbles
class _ParticleFieldPainter extends CustomPainter {
  final List<FloatingGlassParticle> particles;
  final double animValue;
  final Size screenSize;
  final Offset? lastTapPosition;

  _ParticleFieldPainter({
    required this.particles,
    required this.animValue,
    required this.screenSize,
    required this.lastTapPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      double posX = p.calculateX(animValue, size.width);
      double posY = p.calculateY(animValue, size.height);

      if (lastTapPosition != null) {
        final dx = posX - lastTapPosition!.dx;
        final dy = posY - lastTapPosition!.dy;
        final distance = math.sqrt(dx * dx + dy * dy);
        const repulsionRadius = 150.0;
        if (distance < repulsionRadius && distance > 0.001) {
          final force = (1.0 - (distance / repulsionRadius)) * 50.0;
          posX += (dx / distance) * force;
          posY += (dy / distance) * force;
        }
      }

      final center = Offset(posX + p.size / 2, posY + p.size / 2);
      final radius = p.size / 2;

      // 1. Soft ambient glow
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, radius + 2, glowPaint);

      // 2. Liquid glass bubble body
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: p.opacity * 0.8),
            LiquidAuthColors.softSilver.withValues(alpha: p.opacity * 0.25),
            Colors.white.withValues(alpha: 0.02),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, bodyPaint);

      // 3. Specular rim meniscus
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: p.opacity * 0.9),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) => true;
}

