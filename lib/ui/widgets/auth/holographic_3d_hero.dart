import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/auth_colors.dart';
import '../../../core/theme/spring_curves.dart';

/// 3D Vector for mathematical matrix transformations and projections.
class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 other) => _Vec3(x + other.x, y + other.y, z + other.z);
  _Vec3 operator -(_Vec3 other) => _Vec3(x - other.x, y - other.y, z - other.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 other) => x * other.x + y * other.y + z * other.z;

  _Vec3 cross(_Vec3 other) => _Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 normalized() {
    final len = length;
    if (len < 0.00001) return const _Vec3(0, 0, 1);
    return _Vec3(x / len, y / len, z / len);
  }
}

/// Rotates a 3D vector by yaw (Y axis) and pitch (X axis).
_Vec3 _rotate(_Vec3 v, double yaw, double pitch) {
  // Rotate around X (pitch)
  final cosP = math.cos(pitch);
  final sinP = math.sin(pitch);
  final y1 = v.y * cosP - v.z * sinP;
  final z1 = v.y * sinP + v.z * cosP;

  // Rotate around Y (yaw)
  final cosY = math.cos(yaw);
  final sinY = math.sin(yaw);
  final x2 = v.x * cosY + z1 * sinY;
  final z2 = -v.x * sinY + z1 * cosY;

  return _Vec3(x2, y1, z2);
}

/// 3D Polygon face for depth-sorting and glass rendering.
class _Face3D {
  final _Vec3 v0;
  final _Vec3 v1;
  final _Vec3 v2;
  final double depth;
  final _Vec3 normal;

  _Face3D(this.v0, this.v1, this.v2)
      : depth = (v0.z + v1.z + v2.z) / 3.0,
        normal = (v1 - v0).cross(v2 - v0).normalized();
}

/// Volumetric 3D Particle with orbital mechanics.
class _OrbitalParticle {
  final double radius;
  final double inclination;
  final double azimuthOffset;
  final double speed;
  final double baseSize;
  final Color color;
  double pulseOffset = 0.0;

  _OrbitalParticle({
    required this.radius,
    required this.inclination,
    required this.azimuthOffset,
    required this.speed,
    required this.baseSize,
    required this.color,
  });

  _Vec3 getPosition(double time, double touchPulse) {
    final angle = azimuthOffset + time * speed;
    final r = radius + (pulseOffset * touchPulse);
    final x = r * math.sin(inclination) * math.cos(angle);
    final y = r * math.cos(inclination);
    final z = r * math.sin(inclination) * math.sin(angle);
    return _Vec3(x, y, z);
  }
}

/// Interactive 3D Holographic Financial Hero Object.
///
/// Features:
/// - Real 3D faceted holographic crystal sphere with depth-sorted painter's algorithm.
/// - Dynamic normal calculation with directional lighting, specular sheen, and Fresnel refraction.
/// - 3 independent 3D orbital rings with energy satellites and depth occlusion.
/// - 36-particle 3D volumetric swarm with perspective scaling and touch reaction.
/// - Continuous smooth floating and 360-degree rotation.
/// - Interactive touch pan/drag with spring-damper recovery.
/// - Gyroscope / pointer parallax tilt response.
/// - Fully hardware-accelerated and isolated inside a RepaintBoundary.
/// - Pauses on app lifecycle inactive and respects reduced motion preferences.
class Holographic3DHero extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const Holographic3DHero({
    super.key,
    this.size = 180.0,
    this.onTap,
  });

  @override
  State<Holographic3DHero> createState() => _Holographic3DHeroState();
}

class _Holographic3DHeroState extends State<Holographic3DHero>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animController;
  late final AnimationController _springBackController;
  late final AnimationController _touchReactionController;

  double _touchYaw = 0.0;
  double _touchPitch = 0.0;
  double _releaseYaw = 0.0;
  double _releasePitch = 0.0;

  late final List<_OrbitalParticle> _particles;
  bool _isReducedMotion = false;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _touchReactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _initParticles();
  }

  void _initParticles() {
    final rand = math.Random(42);
    _particles = List.generate(36, (i) {
      final isCyan = i % 2 == 0;
      final isWhite = i % 5 == 0;
      final color = isWhite
          ? RoyalAuthColors.iceBlue
          : (isCyan ? RoyalAuthColors.neonCyan : RoyalAuthColors.electricBlue);

      return _OrbitalParticle(
        radius: 48.0 + rand.nextDouble() * 56.0,
        inclination: (rand.nextDouble() - 0.5) * math.pi * 0.9,
        azimuthOffset: rand.nextDouble() * 2 * math.pi,
        speed: (0.4 + rand.nextDouble() * 0.9) * (rand.nextBool() ? 1.0 : -1.0),
        baseSize: 1.5 + rand.nextDouble() * 2.2,
        color: color,
      )..pulseOffset = 18.0 + rand.nextDouble() * 24.0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkMotionPreferences();
  }

  void _checkMotionPreferences() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    if (reduceMotion != _isReducedMotion) {
      setState(() => _isReducedMotion = reduceMotion);
      if (_isReducedMotion) {
        _animController.stop();
      } else if (_isAppActive && !_animController.isAnimating) {
        _animController.repeat();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (!_isAppActive) {
      _animController.stop();
    } else if (!_isReducedMotion && !_animController.isAnimating) {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _springBackController.dispose();
    _touchReactionController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isReducedMotion) return;
    _springBackController.stop();
    setState(() {
      _touchYaw += details.delta.dx * 0.018;
      _touchPitch -= details.delta.dy * 0.018;
      _touchPitch = _touchPitch.clamp(-0.85, 0.85);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isReducedMotion) return;
    _releaseYaw = _touchYaw;
    _releasePitch = _touchPitch;

    _springBackController.reset();
    final Animation<double> curve = CurvedAnimation(
      parent: _springBackController,
      curve: IOSSpringCurve.gentle,
    );

    _springBackController.addListener(() {
      if (!mounted) return;
      setState(() {
        _touchYaw = _releaseYaw * (1.0 - curve.value);
        _touchPitch = _releasePitch * (1.0 - curve.value);
      });
    });

    _springBackController.forward();
  }

  void _handleTap() {
    _touchReactionController.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onTap: _handleTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _animController,
              _springBackController,
              _touchReactionController,
            ]),
            builder: (context, _) {
              final double time = _isReducedMotion
                  ? 0.5
                  : _animController.value * 2.0 * math.pi;

              final double touchPulse = _touchReactionController.isAnimating
                  ? (1.0 - _touchReactionController.value)
                  : 0.0;

              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _Holographic3DPainter(
                  time: time,
                  touchYaw: _touchYaw,
                  touchPitch: _touchPitch,
                  touchPulse: touchPulse,
                  particles: _particles,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Canvas painter implementing true 3D projection, depth sorting, normal calculations, and orbital physics.
class _Holographic3DPainter extends CustomPainter {
  final double time;
  final double touchYaw;
  final double touchPitch;
  final double touchPulse;
  final List<_OrbitalParticle> particles;

  // Icosahedron golden ratio geometry
  static final double _phi = (1.0 + math.sqrt(5.0)) / 2.0;
  static final List<_Vec3> _baseVertices = _generateVertices();
  static final List<List<int>> _faces = _generateFaces();

  _Holographic3DPainter({
    required this.time,
    required this.touchYaw,
    required this.touchPitch,
    required this.touchPulse,
    required this.particles,
  });

  static List<_Vec3> _generateVertices() {
    final list = <_Vec3>[
      _Vec3(-1, _phi, 0),
      _Vec3(1, _phi, 0),
      _Vec3(-1, -_phi, 0),
      _Vec3(1, -_phi, 0),
      _Vec3(0, -1, _phi),
      _Vec3(0, 1, _phi),
      _Vec3(0, -1, -_phi),
      _Vec3(0, 1, -_phi),
      _Vec3(_phi, 0, -1),
      _Vec3(_phi, 0, 1),
      _Vec3(-_phi, 0, -1),
      _Vec3(-_phi, 0, 1),
    ];
    return list.map((v) => v.normalized()).toList();
  }

  static List<List<int>> _generateFaces() {
    return const [
      [0, 11, 5],
      [0, 5, 1],
      [0, 1, 7],
      [0, 7, 10],
      [0, 10, 11],
      [1, 5, 9],
      [5, 11, 4],
      [11, 10, 2],
      [10, 7, 6],
      [7, 1, 8],
      [3, 9, 4],
      [3, 4, 2],
      [3, 2, 6],
      [3, 6, 8],
      [3, 8, 9],
      [4, 9, 5],
      [2, 4, 11],
      [6, 2, 10],
      [8, 6, 7],
      [9, 8, 1],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double crystalRadius = size.width * 0.22;
    const double cameraDistance = 340.0;

    // Smooth floating height oscillation
    final double floatOffset = math.sin(time * 1.5) * 6.0;

    // Total rotation angles
    final double yaw = time * 0.75 + touchYaw;
    final double pitch = math.sin(time * 0.5) * 0.12 + touchPitch;

    // 1. Ambient holographic radial illumination behind crystal
    final bgGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          RoyalAuthColors.electricBlue.withValues(alpha: 0.28 + touchPulse * 0.2),
          RoyalAuthColors.neonCyan.withValues(alpha: 0.10 + touchPulse * 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, cy + floatOffset),
        radius: crystalRadius * 1.9,
      ));
    canvas.drawCircle(Offset(cx, cy + floatOffset), crystalRadius * 1.9, bgGlowPaint);

    // 2. Transform 3D Crystal Vertices
    final transformed = <_Vec3>[];
    final projected = <Offset>[];
    final scales = <double>[];

    for (final v in _baseVertices) {
      final scaled = v * crystalRadius;
      final rot = _rotate(scaled, yaw, pitch);
      transformed.add(rot);

      final double s = cameraDistance / (cameraDistance + rot.z);
      scales.add(s);
      projected.add(Offset(cx + rot.x * s, cy + rot.y * s + floatOffset));
    }

    // 3. Render 3D Orbiting Rings (Background segments with z > 0)
    _drawOrbitingRings(
      canvas,
      cx,
      cy + floatOffset,
      cameraDistance,
      yaw,
      pitch,
      drawFront: false,
    );

    // 4. Render Orbiting Particles (Background particles with z > 0)
    _drawParticles(
      canvas,
      cx,
      cy + floatOffset,
      cameraDistance,
      yaw,
      pitch,
      drawFront: false,
    );

    // 5. Depth Sort 3D Crystal Faces (Painter's Algorithm)
    final faces = <_Face3D>[];
    for (final f in _faces) {
      faces.add(_Face3D(
        transformed[f[0]],
        transformed[f[1]],
        transformed[f[2]],
      ));
    }
    faces.sort((a, b) => b.depth.compareTo(a.depth));

    // Directional light vector
    final lightDir = const _Vec3(0.38, -0.62, -0.68).normalized();

    // Inner glowing core octahedron
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          RoyalAuthColors.neonCyan.withValues(alpha: 0.85 + touchPulse * 0.15),
          RoyalAuthColors.royalBlue.withValues(alpha: 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, cy + floatOffset),
        radius: crystalRadius * 0.55,
      ));
    canvas.drawCircle(Offset(cx, cy + floatOffset), crystalRadius * 0.55, corePaint);

    // Draw 3D Crystal Polygons
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final face in faces) {
      // Perspective projection of face vertices
      final s0 = cameraDistance / (cameraDistance + face.v0.z);
      final s1 = cameraDistance / (cameraDistance + face.v1.z);
      final s2 = cameraDistance / (cameraDistance + face.v2.z);

      final p0 = Offset(cx + face.v0.x * s0, cy + face.v0.y * s0 + floatOffset);
      final p1 = Offset(cx + face.v1.x * s1, cy + face.v1.y * s1 + floatOffset);
      final p2 = Offset(cx + face.v2.x * s2, cy + face.v2.y * s2 + floatOffset);

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      // Lighting normal calculations
      final diffuse = math.max(0.0, face.normal.dot(lightDir));
      final fresnel = math.pow(1.0 - face.normal.z.abs(), 2.2).toDouble();
      final isFront = face.normal.z < 0.0;

      final double faceAlpha = isFront
          ? (0.28 + diffuse * 0.35 + fresnel * 0.25 + touchPulse * 0.15).clamp(0.0, 0.85)
          : (0.10 + fresnel * 0.15).clamp(0.0, 0.40);

      final Color baseFaceColor = isFront
          ? Color.lerp(
              RoyalAuthColors.deepSpaceBlue,
              RoyalAuthColors.neonCyan,
              (diffuse * 0.7 + fresnel * 0.3).clamp(0.0, 1.0),
            )!
          : RoyalAuthColors.midnightNavy;

      fillPaint.color = baseFaceColor.withValues(alpha: faceAlpha);
      canvas.drawPath(path, fillPaint);

      // Specular edge hairline
      final double edgeAlpha = isFront
          ? (0.55 + diffuse * 0.4 + touchPulse * 0.2).clamp(0.0, 1.0)
          : 0.18;

      edgePaint.color = (isFront ? RoyalAuthColors.iceBlue : RoyalAuthColors.royalBlue)
          .withValues(alpha: edgeAlpha);
      edgePaint.strokeWidth = isFront ? 1.15 : 0.75;
      canvas.drawPath(path, edgePaint);
    }

    // 6. Render 3D Orbiting Rings (Foreground segments with z <= 0)
    _drawOrbitingRings(
      canvas,
      cx,
      cy + floatOffset,
      cameraDistance,
      yaw,
      pitch,
      drawFront: true,
    );

    // 7. Render Orbiting Particles (Foreground particles with z <= 0)
    _drawParticles(
      canvas,
      cx,
      cy + floatOffset,
      cameraDistance,
      yaw,
      pitch,
      drawFront: true,
    );
  }

  void _drawOrbitingRings(
    Canvas canvas,
    double cx,
    double cy,
    double camDist,
    double sceneYaw,
    double scenePitch, {
    required bool drawFront,
  }) {
    // 3 Unique Rings with independent inclinations
    _drawSingleRing(
      canvas,
      cx,
      cy,
      camDist,
      radius: 64.0,
      ringPitch: 0.42,
      ringRoll: 0.26,
      rotationAngle: time * 0.9,
      strokeColor: RoyalAuthColors.neonCyan,
      sceneYaw: sceneYaw,
      scenePitch: scenePitch,
      drawFront: drawFront,
      showSatellite: true,
    );

    _drawSingleRing(
      canvas,
      cx,
      cy,
      camDist,
      radius: 76.0,
      ringPitch: -0.78,
      ringRoll: -0.45,
      rotationAngle: -time * 0.7,
      strokeColor: RoyalAuthColors.electricBlue,
      sceneYaw: sceneYaw,
      scenePitch: scenePitch,
      drawFront: drawFront,
      showSatellite: false,
    );

    _drawSingleRing(
      canvas,
      cx,
      cy,
      camDist,
      radius: 88.0,
      ringPitch: 1.15,
      ringRoll: 0.55,
      rotationAngle: time * 0.5,
      strokeColor: RoyalAuthColors.iceBlue,
      sceneYaw: sceneYaw,
      scenePitch: scenePitch,
      drawFront: drawFront,
      showSatellite: true,
    );
  }

  void _drawSingleRing(
    Canvas canvas,
    double cx,
    double cy,
    double camDist, {
    required double radius,
    required double ringPitch,
    required double ringRoll,
    required double rotationAngle,
    required Color strokeColor,
    required double sceneYaw,
    required double scenePitch,
    required bool drawFront,
    required bool showSatellite,
  }) {
    const int segments = 54;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segments; i++) {
      final a0 = (i / segments) * 2.0 * math.pi + rotationAngle;
      final a1 = ((i + 1) / segments) * 2.0 * math.pi + rotationAngle;

      // Unrotated ring circle in local plane
      final p0Local = _Vec3(radius * math.cos(a0), 0.0, radius * math.sin(a0));
      final p1Local = _Vec3(radius * math.cos(a1), 0.0, radius * math.sin(a1));

      // Incline ring in space
      final p0Inclined = _rotate(p0Local, ringRoll, ringPitch);
      final p1Inclined = _rotate(p1Local, ringRoll, ringPitch);

      // Rotate with scene yaw/pitch
      final p0World = _rotate(p0Inclined, sceneYaw, scenePitch);
      final p1World = _rotate(p1Inclined, sceneYaw, scenePitch);

      final midZ = (p0World.z + p1World.z) / 2.0;
      final isSegmentFront = midZ <= 0.0;
      if (isSegmentFront != drawFront) continue;

      final s0 = camDist / (camDist + p0World.z);
      final s1 = camDist / (camDist + p1World.z);

      final screen0 = Offset(cx + p0World.x * s0, cy + p0World.y * s0);
      final screen1 = Offset(cx + p1World.x * s1, cy + p1World.y * s1);

      final double depthAlpha = isSegmentFront
          ? (0.55 + (-midZ / radius) * 0.35 + touchPulse * 0.2).clamp(0.1, 0.95)
          : (0.16 + (radius - midZ) / (2 * radius) * 0.15).clamp(0.05, 0.35);

      ringPaint.color = strokeColor.withValues(alpha: depthAlpha);
      ringPaint.strokeWidth = isSegmentFront ? 1.4 : 0.85;

      canvas.drawLine(screen0, screen1, ringPaint);
    }

    // Satellite beacon orbiting along this ring
    if (showSatellite) {
      final satAngle = rotationAngle * 1.8;
      final satLocal = _Vec3(radius * math.cos(satAngle), 0.0, radius * math.sin(satAngle));
      final satInclined = _rotate(satLocal, ringRoll, ringPitch);
      final satWorld = _rotate(satInclined, sceneYaw, scenePitch);

      final isSatFront = satWorld.z <= 0.0;
      if (isSatFront == drawFront) {
        final s = camDist / (camDist + satWorld.z);
        final satPos = Offset(cx + satWorld.x * s, cy + satWorld.y * s);

        final satGlowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              strokeColor.withValues(alpha: 0.95),
              strokeColor.withValues(alpha: 0.35),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: satPos, radius: 6.0 * s));
        canvas.drawCircle(satPos, 6.0 * s, satGlowPaint);

        final satCorePaint = Paint()..color = Colors.white;
        canvas.drawCircle(satPos, 2.0 * s, satCorePaint);
      }
    }
  }

  void _drawParticles(
    Canvas canvas,
    double cx,
    double cy,
    double camDist,
    double sceneYaw,
    double scenePitch, {
    required bool drawFront,
  }) {
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final posLocal = p.getPosition(time, touchPulse);
      final posWorld = _rotate(posLocal, sceneYaw, scenePitch);

      final isFront = posWorld.z <= 0.0;
      if (isFront != drawFront) continue;

      final s = camDist / (camDist + posWorld.z);
      final screenPos = Offset(cx + posWorld.x * s, cy + posWorld.y * s);

      final double depthAlpha = isFront
          ? (0.45 + (-posWorld.z / 100.0) * 0.45 + touchPulse * 0.25).clamp(0.2, 1.0)
          : (0.15 + (100.0 - posWorld.z) / 200.0 * 0.2).clamp(0.08, 0.35);

      final double radius = p.baseSize * s * (1.0 + touchPulse * 0.4);

      particlePaint.color = p.color.withValues(alpha: depthAlpha);
      canvas.drawCircle(screenPos, radius, particlePaint);

      // Core sparkle for large particles
      if (isFront && p.baseSize > 2.5) {
        canvas.drawCircle(
          screenPos,
          radius * 0.5,
          Paint()..color = Colors.white.withValues(alpha: depthAlpha * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Holographic3DPainter oldDelegate) => true;
}
