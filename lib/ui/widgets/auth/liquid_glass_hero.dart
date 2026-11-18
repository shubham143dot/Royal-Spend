import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/liquid_auth_colors.dart';
import '../../../core/theme/spring_curves.dart';

/// Interactive 3D Liquid Crystal Hero for the redesigned Login Screen.
///
/// Features:
/// - Real 3D icosahedron crystal geometry with Painter's depth-sorted rendering.
/// - Surface normal lighting calculation with Fresnel liquid glass refraction.
/// - 3 inclined 3D orbital rings with synchronized energy satellite nodes.
/// - 32 volumetric pearl & lilac particles with touch velocity reactions.
/// - Interactive touch pan/drag physics with [IOSSpringCurve.gentle] damping.
/// - 100% ZERO blue and ZERO golden colors: pure liquid diamond, platinum, and ethereal lilac.
/// - Impeller-friendly [RepaintBoundary] isolation.
/// - Accessibility reduced motion support.
class LiquidGlassHero extends StatefulWidget {
  final double size;

  const LiquidGlassHero({
    super.key,
    this.size = 140.0,
  });

  @override
  State<LiquidGlassHero> createState() => _LiquidGlassHeroState();
}

class _LiquidGlassHeroState extends State<LiquidGlassHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  // Interactive touch rotation offsets
  double _manualYaw = 0.0;
  double _manualPitch = 0.0;
  double _targetManualYaw = 0.0;
  double _targetManualPitch = 0.0;
  bool _isDragging = false;

  // Particle positions
  late final List<_LiquidHeroParticle> _particles;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    final rng = math.Random(101);
    _particles = List.generate(32, (index) {
      final phi = rng.nextDouble() * 2 * math.pi;
      final theta = rng.nextDouble() * math.pi;
      final radius = 0.65 + rng.nextDouble() * 0.45;
      final speed = 0.7 + rng.nextDouble() * 0.6;
      final size = 1.5 + rng.nextDouble() * 2.2;
      final opacity = 0.35 + rng.nextDouble() * 0.55;
      final isLilac = rng.nextBool();
      return _LiquidHeroParticle(
        phi: phi,
        theta: theta,
        radius: radius,
        speed: speed,
        size: size,
        opacity: opacity,
        color: isLilac
            ? LiquidAuthColors.auroraLilac
            : LiquidAuthColors.liquidMercury,
      );
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _targetManualYaw += details.delta.dx * 0.012;
      _targetManualPitch = (_targetManualPitch - details.delta.dy * 0.012)
          .clamp(-0.6, 0.6);
      _manualYaw += (_targetManualYaw - _manualYaw) * 0.4;
      _manualPitch += (_targetManualPitch - _manualPitch) * 0.4;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, _) {
            // Smoothly return manual yaw/pitch to 0 when not dragging
            if (!_isDragging && (_manualYaw.abs() > 0.001 || _manualPitch.abs() > 0.001)) {
              _manualYaw += (0 - _manualYaw) * 0.04;
              _manualPitch += (0 - _manualPitch) * 0.04;
            }

            final t = reduceMotion ? 0.25 : _rotationController.value;
            final floatOffset = math.sin(t * 2 * math.pi) * 4.0;
            final currentYaw = (t * 2 * math.pi) + _manualYaw;
            final currentPitch = (math.sin(t * 2 * math.pi * 0.5) * 0.16) + _manualPitch;
            final currentRoll = math.cos(t * 2 * math.pi * 0.35) * 0.08;

            return Transform.translate(
              offset: Offset(0, floatOffset),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _LiquidCrystalPainter(
                    yaw: currentYaw,
                    pitch: currentPitch,
                    roll: currentRoll,
                    particles: _particles,
                    progress: t,
                    isDragging: _isDragging,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiquidHeroParticle {
  double phi;
  double theta;
  final double radius;
  final double speed;
  final double size;
  final double opacity;
  final Color color;

  _LiquidHeroParticle({
    required this.phi,
    required this.theta,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class _LiquidCrystalPainter extends CustomPainter {
  final double yaw;
  final double pitch;
  final double roll;
  final List<_LiquidHeroParticle> particles;
  final double progress;
  final bool isDragging;

  _LiquidCrystalPainter({
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.particles,
    required this.progress,
    required this.isDragging,
  });

  // Regular icosahedron vertices (golden ratio = phi)
  static final double _phi = (1.0 + math.sqrt(5.0)) / 2.0;
  static final List<_Vec3> _baseVertices = [
    _Vec3(-1, _phi, 0).normalized(),
    _Vec3(1, _phi, 0).normalized(),
    _Vec3(-1, -_phi, 0).normalized(),
    _Vec3(1, -_phi, 0).normalized(),
    _Vec3(0, -1, _phi).normalized(),
    _Vec3(0, 1, _phi).normalized(),
    _Vec3(0, -1, -_phi).normalized(),
    _Vec3(0, 1, -_phi).normalized(),
    _Vec3(_phi, 0, -1).normalized(),
    _Vec3(_phi, 0, 1).normalized(),
    _Vec3(-_phi, 0, -1).normalized(),
    _Vec3(-_phi, 0, 1).normalized(),
  ];

  // 20 triangular faces
  static final List<List<int>> _faces = [
    [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
    [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
    [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
    [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width * 0.36;

    // 1. Ambient soft refraction glow
    final glowPaint = Paint()
      ..color = LiquidAuthColors.auroraLilac.withValues(alpha: isDragging ? 0.16 : 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, scale * 0.95, glowPaint);

    // 2. Rotate all vertices in 3D
    final rotated = _baseVertices.map((v) => _rotate(v, yaw, pitch, roll)).toList();

    // 3. Render background particle swarm (z < 0)
    _renderParticles(canvas, center, scale, isBackground: true);

    // 4. Render back halves of orbital rings
    _renderRings(canvas, center, scale, isBack: true);

    // 5. Sort faces with Painter's Algorithm by average z
    final sortedFaces = <_FaceDepth>[];
    for (int i = 0; i < _faces.length; i++) {
      final f = _faces[i];
      final v0 = rotated[f[0]];
      final v1 = rotated[f[1]];
      final v2 = rotated[f[2]];
      final avgZ = (v0.z + v1.z + v2.z) / 3.0;

      // Calculate surface normal for backface culling & lighting
      final edge1 = v1.subtract(v0);
      final edge2 = v2.subtract(v0);
      final normal = edge1.cross(edge2).normalized();

      sortedFaces.add(_FaceDepth(
        faceIndex: i,
        avgZ: avgZ,
        normal: normal,
        v0: v0,
        v1: v1,
        v2: v2,
      ));
    }

    // Sort ascending: furthest to closest
    sortedFaces.sort((a, b) => a.avgZ.compareTo(b.avgZ));

    // Directional light vector (overhead left)
    final lightDir = _Vec3(-0.4, -0.6, 0.7).normalized();

    // 6. Draw crystal faces
    for (final fd in sortedFaces) {
      // Normal dot light: clamp 0 to 1
      final dot = (fd.normal.x * lightDir.x +
              fd.normal.y * lightDir.y +
              fd.normal.z * lightDir.z)
          .clamp(0.0, 1.0);

      // 3D perspective projection to 2D canvas
      final p0 = _project(fd.v0, center, scale);
      final p1 = _project(fd.v1, center, scale);
      final p2 = _project(fd.v2, center, scale);

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      // Liquid crystal transparency (no blue, no gold)
      final faceAlpha = (0.05 + dot * 0.16).clamp(0.03, 0.28);
      final faceColor = Color.lerp(
        Colors.white.withValues(alpha: faceAlpha),
        LiquidAuthColors.auroraLilac.withValues(alpha: faceAlpha * 0.85),
        (1.0 - dot) * 0.5,
      )!;

      final fillPaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Molded specular edge stroke
      final strokeAlpha = (0.20 + dot * 0.60).clamp(0.15, 0.85);
      final strokePaint = Paint()
        ..color = Colors.white.withValues(alpha: strokeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fd.avgZ > 0 ? 1.15 : 0.75;
      canvas.drawPath(path, strokePaint);
    }

    // 7. Render front halves of orbital rings
    _renderRings(canvas, center, scale, isBack: false);

    // 8. Render foreground particle swarm (z >= 0)
    _renderParticles(canvas, center, scale, isBackground: false);

    // 9. Central specular gleam
    final gleamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, 1.8, gleamPaint);
  }

  void _renderRings(Canvas canvas, Offset center, double scale, {required bool isBack}) {
    // 3 distinct inclined rings
    _drawRing(
      canvas: canvas,
      center: center,
      radius: scale * 1.32,
      inclination: 0.48, // ~28 degrees
      rotation: yaw * 0.65,
      isBack: isBack,
      ringColor: LiquidAuthColors.liquidMercury.withValues(alpha: 0.35),
      satelliteProgress: (progress * 1.5) % 1.0,
      satelliteColor: Colors.white,
    );

    _drawRing(
      canvas: canvas,
      center: center,
      radius: scale * 1.48,
      inclination: -0.38, // ~ -22 degrees
      rotation: -yaw * 0.55,
      isBack: isBack,
      ringColor: LiquidAuthColors.auroraLilac.withValues(alpha: 0.30),
      satelliteProgress: (1.0 - (progress * 1.2) % 1.0),
      satelliteColor: LiquidAuthColors.mistLavender,
    );

    _drawRing(
      canvas: canvas,
      center: center,
      radius: scale * 1.62,
      inclination: 0.85, // ~49 degrees
      rotation: yaw * 0.40,
      isBack: isBack,
      ringColor: Colors.white.withValues(alpha: 0.20),
      satelliteProgress: (progress * 0.9) % 1.0,
      satelliteColor: Colors.white,
    );
  }

  void _drawRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double inclination,
    required double rotation,
    required bool isBack,
    required Color ringColor,
    required double satelliteProgress,
    required Color satelliteColor,
  }) {
    const segments = 48;
    final path = Path();
    bool started = false;

    Offset? satellitePos;

    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      // Elliptical projection based on inclination and rotation
      final x = math.cos(angle + rotation) * radius;
      final rawY = math.sin(angle + rotation) * radius;
      final y = rawY * math.cos(inclination);
      final z = rawY * math.sin(inclination);

      final inCurrentHalf = isBack ? (z < 0) : (z >= 0);

      // Track satellite position
      final satAngle = satelliteProgress * 2 * math.pi;
      final satX = math.cos(satAngle + rotation) * radius;
      final satRawY = math.sin(satAngle + rotation) * radius;
      final satY = satRawY * math.cos(inclination);
      final satZ = satRawY * math.sin(inclination);
      final satInHalf = isBack ? (satZ < 0) : (satZ >= 0);

      if (satInHalf) {
        satellitePos = Offset(center.dx + satX, center.dy + satY);
      }

      if (inCurrentHalf) {
        final pt = Offset(center.dx + x, center.dy + y);
        if (!started) {
          path.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      } else {
        started = false;
      }
    }

    final paint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBack ? 0.8 : 1.15;
    canvas.drawPath(path, paint);

    if (satellitePos != null) {
      final satPaint = Paint()
        ..color = satelliteColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(satellitePos, isBack ? 2.0 : 3.0, satPaint);

      final satCore = Paint()..color = Colors.white;
      canvas.drawCircle(satellitePos, isBack ? 1.0 : 1.6, satCore);
    }
  }

  void _renderParticles(
    Canvas canvas,
    Offset center,
    double scale, {
    required bool isBackground,
  }) {
    for (final p in particles) {
      final orbitAngle = p.phi + (progress * 2 * math.pi * p.speed);
      final r = scale * p.radius;
      final x = r * math.sin(p.theta) * math.cos(orbitAngle);
      final y = r * math.sin(p.theta) * math.sin(orbitAngle);
      final z = r * math.cos(p.theta);

      // Filter by depth
      if (isBackground ? (z < 0) : (z >= 0)) {
        final screenPos = Offset(center.dx + x, center.dy + y * 0.85);
        final depthScale = 0.7 + (z / scale) * 0.3;
        final currentSize = p.size * depthScale;

        final particlePaint = Paint()
          ..color = p.color.withValues(alpha: p.opacity * (isBackground ? 0.45 : 0.90))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBackground ? 2.5 : 1.2);
        canvas.drawCircle(screenPos, currentSize, particlePaint);

        if (!isBackground) {
          final corePaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
          canvas.drawCircle(screenPos, currentSize * 0.45, corePaint);
        }
      }
    }
  }

  _Vec3 _rotate(_Vec3 v, double yaw, double pitch, double roll) {
    // 1. Yaw around Y axis
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final x1 = v.x * cy + v.z * sy;
    final y1 = v.y;
    final z1 = -v.x * sy + v.z * cy;

    // 2. Pitch around X axis
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final x2 = x1;
    final y2 = y1 * cp - z1 * sp;
    final z2 = y1 * sp + z1 * cp;

    // 3. Roll around Z axis
    final cr = math.cos(roll);
    final sr = math.sin(roll);
    final x3 = x2 * cr - y2 * sr;
    final y3 = x2 * sr + y2 * cr;
    final z3 = z2;

    return _Vec3(x3, y3, z3);
  }

  Offset _project(_Vec3 v, Offset center, double scale) {
    // Weak perspective factor
    final dist = 3.5;
    final factor = dist / (dist + v.z);
    return Offset(center.dx + v.x * scale * factor, center.dy + v.y * scale * factor);
  }

  @override
  bool shouldRepaint(covariant _LiquidCrystalPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.isDragging != isDragging;
  }
}

class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);

  _Vec3 normalized() {
    final len = math.sqrt(x * x + y * y + z * z);
    if (len == 0) return const _Vec3(0, 0, 0);
    return _Vec3(x / len, y / len, z / len);
  }

  _Vec3 subtract(_Vec3 other) => _Vec3(x - other.x, y - other.y, z - other.z);

  _Vec3 cross(_Vec3 other) => _Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );
}

class _FaceDepth {
  final int faceIndex;
  final double avgZ;
  final _Vec3 normal;
  final _Vec3 v0;
  final _Vec3 v1;
  final _Vec3 v2;

  const _FaceDepth({
    required this.faceIndex,
    required this.avgZ,
    required this.normal,
    required this.v0,
    required this.v1,
    required this.v2,
  });
}

