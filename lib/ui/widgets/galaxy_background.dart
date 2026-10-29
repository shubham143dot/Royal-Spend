import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A stable, decorative galaxy with bounded tap and text-input effects.
///
/// Text values are never passed to this widget. The notifier communicates only
/// that a field changed, so neither email nor password content can be painted.
class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({
    super.key,
    required this.inputPulse,
    required this.touchPulse,
  });

  final ValueListenable<int> inputPulse;
  final ValueListenable<GalaxyTouch?> touchPulse;

  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _maxEffects = 6;
  static const int _effectLifetimeMs = 1500;
  static const int _inputThrottleMs = 95;

  final Random _random = Random(73921);
  final Stopwatch _clock = Stopwatch()..start();
  final List<_GalaxyEffect> _effects = <_GalaxyEffect>[];
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  late final List<_GalaxyStar> _stars;
  late final AnimationController _twinkleController;
  bool _reduceMotion = false;
  bool _appIsActive = true;
  int _lastInputPulse = 0;
  int _lastInputEffectAt = -_inputThrottleMs;
  int _inputEffectCount = 0;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _stars = _createStars();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
      animationBehavior: AnimationBehavior.normal,
    )..addListener(_handleAnimationFrame);
    widget.inputPulse.addListener(_handleInputPulse);
    widget.touchPulse.addListener(_handleTouchPulse);
    _lastInputPulse = widget.inputPulse.value;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant GalaxyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inputPulse != widget.inputPulse) {
      oldWidget.inputPulse.removeListener(_handleInputPulse);
      _lastInputPulse = widget.inputPulse.value;
      widget.inputPulse.addListener(_handleInputPulse);
    }
    if (oldWidget.touchPulse != widget.touchPulse) {
      oldWidget.touchPulse.removeListener(_handleTouchPulse);
      widget.touchPulse.addListener(_handleTouchPulse);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (!mounted) return;
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    _syncAnimation();
  }

  void _syncAnimation() {
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (_reduceMotion || !_appIsActive) {
      _twinkleController.stop();
      _effects.clear();
      _requestRepaint();
      return;
    }
    if (!_twinkleController.isAnimating) {
      _twinkleController.repeat();
    }
  }

  List<_GalaxyStar> _createStars() {
    return List<_GalaxyStar>.generate(420, (index) {
      final isNebulaBand = index % 4 == 0;
      final x = _random.nextDouble();
      final y = isNebulaBand
          ? (0.24 + x * 0.42 + (_random.nextDouble() - 0.5) * 0.5).clamp(
              0.02,
              0.98,
            )
          : _random.nextDouble();
      final radius = index % 23 == 0
          ? 1.65 + _random.nextDouble() * 0.8
          : 0.45 + _random.nextDouble() * 0.8;
      final alpha = index % 23 == 0
          ? 145 + _random.nextInt(75)
          : 44 + _random.nextInt(105);
      final isGold = index % 11 == 0;
      return _GalaxyStar(
        position: Offset(x, y),
        radius: radius,
        color: isGold
            ? Color.fromARGB(alpha, 244, 208, 125)
            : Color.fromARGB(alpha, 220, 228, 245),
        phase: _random.nextDouble() * pi * 2,
        signature: index % 61 == 0,
      );
    }, growable: false);
  }

  void _handleInputPulse() {
    final pulse = widget.inputPulse.value;
    if (pulse == _lastInputPulse) return;
    _lastInputPulse = pulse;
    if (_reduceMotion || !_appIsActive) return;

    final now = _clock.elapsedMilliseconds;
    if (now - _lastInputEffectAt < _inputThrottleMs) return;
    _lastInputEffectAt = now;
    _inputEffectCount++;

    // A rare fixed constellation gives the effect a word-like accent without
    // rendering, deriving, or retaining any characters from the field value.
    final effect = _GalaxyEffect.fallingStar(
      origin: Offset(
        0.16 + _random.nextDouble() * 0.68,
        0.08 + _random.nextDouble() * 0.18,
      ),
      drift: (_random.nextDouble() - 0.5) * 0.055,
      startedAtMs: now,
      constellation: _inputEffectCount % 8 == 0,
    );
    _addEffect(effect);
  }

  void _addEffect(_GalaxyEffect effect) {
    if (_effects.length == _maxEffects) _effects.removeAt(0);
    _effects.add(effect);
    _requestRepaint();
  }

  void _requestRepaint() => _repaint.value++;

  void _handleAnimationFrame() {
    final now = _clock.elapsedMilliseconds;
    _effects.removeWhere(
      (effect) => now - effect.startedAtMs > _effectLifetimeMs,
    );
    _requestRepaint();
  }

  void _handleTouchPulse() {
    final touch = widget.touchPulse.value;
    if (touch == null || _reduceMotion || !_appIsActive || _size.isEmpty) {
      return;
    }
    final local = touch.position;
    _addEffect(
      _GalaxyEffect.ripple(
        origin: Offset(local.dx / _size.width, local.dy / _size.height),
        startedAtMs: _clock.elapsedMilliseconds,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.inputPulse.removeListener(_handleInputPulse);
    widget.touchPulse.removeListener(_handleTouchPulse);
    _twinkleController
      ..removeListener(_handleAnimationFrame)
      ..dispose();
    _repaint.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF05060A),
                    Color(0xFF090C16),
                    Color(0xFF050609),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.64, -0.7),
                      radius: 0.9,
                      colors: [Color(0x302A3159), Color(0x0010172A)],
                      stops: [0, 1],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.72, 0.76),
                      radius: 0.72,
                      colors: [Color(0x18B77721), Color(0x00130D0A)],
                      stops: [0, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _GalaxyPainter(
                    stars: _stars,
                    effects: _effects,
                    clock: _clock,
                    twinkle: _twinkleController,
                    repaintSignal: _repaint,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A tap coordinate plus a changing id, so repeated taps at the same point
/// still produce separate visual events.
@immutable
class GalaxyTouch {
  const GalaxyTouch({required this.id, required this.position});

  final int id;
  final Offset position;
}

class _GalaxyStar {
  const _GalaxyStar({
    required this.position,
    required this.radius,
    required this.color,
    required this.phase,
    required this.signature,
  });

  final Offset position;
  final double radius;
  final Color color;
  final double phase;
  final bool signature;
}

enum _GalaxyEffectKind { fallingStar, ripple }

class _GalaxyEffect {
  const _GalaxyEffect._({
    required this.kind,
    required this.origin,
    required this.startedAtMs,
    this.drift = 0,
    this.constellation = false,
  });

  factory _GalaxyEffect.fallingStar({
    required Offset origin,
    required double drift,
    required int startedAtMs,
    required bool constellation,
  }) => _GalaxyEffect._(
    kind: _GalaxyEffectKind.fallingStar,
    origin: origin,
    drift: drift,
    startedAtMs: startedAtMs,
    constellation: constellation,
  );

  factory _GalaxyEffect.ripple({
    required Offset origin,
    required int startedAtMs,
  }) => _GalaxyEffect._(
    kind: _GalaxyEffectKind.ripple,
    origin: origin,
    startedAtMs: startedAtMs,
  );

  final _GalaxyEffectKind kind;
  final Offset origin;
  final double drift;
  final int startedAtMs;
  final bool constellation;
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter({
    required this.stars,
    required this.effects,
    required this.clock,
    required this.twinkle,
    required this.repaintSignal,
  }) : super(repaint: repaintSignal);

  final List<_GalaxyStar> stars;
  final List<_GalaxyEffect> effects;
  final Stopwatch clock;
  final Animation<double> twinkle;
  final Listenable repaintSignal;

  final Paint _starPaint = Paint()..isAntiAlias = true;
  final Paint _highlightPaint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1;
  final Paint _trailPaint = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.5;
  final Paint _ripplePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = twinkle.value * pi * 2;
    for (final star in stars) {
      final center = Offset(
        star.position.dx * size.width,
        star.position.dy * size.height,
      );
      _starPaint.color = star.color;
      final shimmer = star.signature
          ? 0.79 + 0.21 * sin(phase + star.phase)
          : 1.0;
      canvas.drawCircle(center, star.radius * shimmer, _starPaint);

      if (star.signature) {
        final extent = star.radius * (2.8 + shimmer * 1.8);
        _highlightPaint
          ..color = const Color(0x55F3D98B)
          ..strokeWidth = 0.7 + shimmer * 0.4;
        canvas.drawLine(
          center.translate(-extent, 0),
          center.translate(extent, 0),
          _highlightPaint,
        );
        canvas.drawLine(
          center.translate(0, -extent),
          center.translate(0, extent),
          _highlightPaint,
        );
      }
    }

    final now = clock.elapsedMilliseconds;
    for (final effect in effects) {
      final age = now - effect.startedAtMs;
      if (age < 0) continue;
      final progress = (age / _GalaxyBackgroundState._effectLifetimeMs).clamp(
        0.0,
        1.0,
      );
      final center = Offset(
        effect.origin.dx * size.width,
        effect.origin.dy * size.height,
      );
      if (effect.kind == _GalaxyEffectKind.fallingStar) {
        _paintFallingStar(canvas, size, center, effect, progress);
      } else {
        _paintRipple(canvas, center, progress);
      }
    }
  }

  void _paintFallingStar(
    Canvas canvas,
    Size size,
    Offset origin,
    _GalaxyEffect effect,
    double progress,
  ) {
    final travel = size.height * 0.36 * progress;
    final head = Offset(
      origin.dx + sin(progress * pi) * size.width * effect.drift,
      origin.dy + travel,
    );
    final fade = (1 - progress).clamp(0.0, 1.0);
    _trailPaint
      ..color = const Color(0x99EACB7A).withValues(alpha: 0.6 * fade)
      ..strokeWidth = 1.4;
    canvas.drawLine(head.translate(-2, -38), head, _trailPaint);
    _starPaint.color = const Color(0xFFFFE7A3).withValues(alpha: fade);
    canvas.drawCircle(head, 2.4 * fade, _starPaint);
    _starPaint.color = const Color(0x66F0C75D).withValues(alpha: 0.38 * fade);
    canvas.drawCircle(head, 7.5 * fade, _starPaint);

    if (effect.constellation && progress < 0.62) {
      const offsets = <Offset>[
        Offset(-12, -7),
        Offset(-6, 2),
        Offset(0, -7),
        Offset(6, 2),
        Offset(12, -7),
      ];
      final constellationFade = ((0.62 - progress) / 0.62).clamp(0.0, 1.0);
      _starPaint.color = const Color(
        0xFFEFD48D,
      ).withValues(alpha: constellationFade * fade);
      for (final offset in offsets) {
        canvas.drawCircle(
          head.translate(offset.dx, offset.dy),
          1.1,
          _starPaint,
        );
      }
    }
  }

  void _paintRipple(Canvas canvas, Offset center, double progress) {
    final fade = (1 - progress).clamp(0.0, 1.0);
    _ripplePaint.color = const Color(0x88E4BF62).withValues(alpha: 0.56 * fade);
    canvas.drawCircle(center, 8 + progress * 52, _ripplePaint);
    _starPaint.color = const Color(0x66E4BF62).withValues(alpha: 0.24 * fade);
    canvas.drawCircle(center, (3 + progress * 14) * fade, _starPaint);

    for (var index = 0; index < 4; index++) {
      final angle = index * pi / 2 + pi / 4;
      final distance = progress * 28;
      final point = center.translate(
        cos(angle) * distance,
        sin(angle) * distance,
      );
      _starPaint.color = const Color(0xDDEFD48D).withValues(alpha: fade);
      canvas.drawCircle(point, 1.2 * fade, _starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) =>
      !identical(oldDelegate.stars, stars) ||
      !identical(oldDelegate.effects, effects) ||
      !identical(oldDelegate.repaintSignal, repaintSignal);
}
