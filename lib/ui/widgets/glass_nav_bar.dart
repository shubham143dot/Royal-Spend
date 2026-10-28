import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/utils/haptic_helper.dart';

/// Navigation item model for [GlassFloatingNavBar].
@immutable
class GlassNavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const GlassNavItemData({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;
}

/// Transparent frosted glass floating bottom navigation bar with an organic
/// crystal-clear water bubble that slides across tabs, illuminating buttons
/// with blue (dark mode) / purple (light mode) only when the bubble touches them.
class GlassFloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isDark;

  const GlassFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.isDark,
  });

  @override
  State<GlassFloatingNavBar> createState() => _GlassFloatingNavBarState();
}

class _GlassFloatingNavBarState extends State<GlassFloatingNavBar>
    with TickerProviderStateMixin {
  // Navigation item configurations
  static const List<GlassNavItemData> _items = [
    GlassNavItemData(
      icon: CupertinoIcons.square_grid_2x2,
      selectedIcon: CupertinoIcons.square_grid_2x2_fill,
      label: 'Expenses',
    ),
    GlassNavItemData(
      icon: CupertinoIcons.list_bullet,
      selectedIcon: CupertinoIcons.list_bullet_indent,
      label: 'History',
    ),
    GlassNavItemData(
      icon: CupertinoIcons.airplane,
      selectedIcon: CupertinoIcons.airplane,
      label: 'Travel',
    ),
    GlassNavItemData(
      icon: CupertinoIcons.chart_pie,
      selectedIcon: CupertinoIcons.chart_pie_fill,
      label: 'Analytics',
    ),
    GlassNavItemData(
      icon: CupertinoIcons.person_crop_circle,
      selectedIcon: CupertinoIcons.person_crop_circle_fill,
      label: 'Profile',
    ),
  ];

  // Fluid physics constants
  static const double _barHeight = 68.0;
  static const double _maxWidth = 440.0;
  static const double _horizontalMargin = 18.0;
  static const double _bottomGap = 14.0;
  static const double _innerPadding = 8.0;
  static const double _capsuleVerticalInset = 5.0;
  static const double _blobHorizontalInset = 4.0;
  static const double _dragMagnify = 0.12;
  static const double _dragWiden = 0.35;
  static const double _dragStretch = 0.25;
  static const double _dragTopOverflow = 6.0;
  static const double _dragBottomOverflow = 6.0;
  static const double _bottomLiftHeadroom = 10.0;
  static const double _lensIconGain = 0.28;
  static const double _lensLabelGain = 0.12;
  static const double _dragVerticalSwell = 0.03;
  static const double _maxSquash = 0.06;
  static const double _refVelocity = 16.0;
  static const double _velRelax = 0.05;
  static const double _stretchEase = 0.06;
  static const double _actEase = 0.11;
  static const double _lensFalloff = 2.2;

  late final AnimationController _controller;
  late final Listenable _capsuleRepaint;
  late int _fromIndex;
  late int _toIndex;

  final ValueNotifier<double?> _dragLeft = ValueNotifier<double?>(null);
  bool _settling = false;
  double _settleFromLeft = 0;
  double _settleToLeft = 0;

  final ValueNotifier<_WaterDragFx> _dragFx =
      ValueNotifier<_WaterDragFx>(_WaterDragFx.rest);
  late final Ticker _fxTicker;
  bool _dragging = false;
  double _vel = 0;
  double _fxActivation = 0;
  double _fxStretch = 0;
  int _lastTickMicros = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _toIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: 1.0,
    )..addStatusListener(_onControllerStatus);
    _fxTicker = createTicker(_onFxTick);
    _capsuleRepaint = Listenable.merge([_controller, _dragLeft, _dragFx]);
  }

  void _onControllerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _settling = false;
    }
  }

  @override
  void didUpdateWidget(covariant GlassFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _toIndex) {
      _flowTo(widget.currentIndex);
    }
  }

  void _flowTo(int target) {
    _settling = false;
    if (target == _toIndex) return;
    _fromIndex = _toIndex;
    _toIndex = target;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fxTicker.dispose();
    _controller.dispose();
    _dragLeft.dispose();
    _dragFx.dispose();
    super.dispose();
  }

  ({double left, double width}) _capsuleMetrics(double itemWidth) {
    final fromLeft = _slotLeft(_fromIndex, itemWidth);
    final toLeft = _slotLeft(_toIndex, itemWidth);
    final t = _controller.value;
    final lead = Curves.easeOutCubic.transform(t);
    final trail = Curves.easeInOutCubic.transform(t);
    final double leftEdge;
    final double rightEdge;
    if (toLeft >= fromLeft) {
      leftEdge = fromLeft + (toLeft - fromLeft) * trail;
      rightEdge = fromLeft + itemWidth + (toLeft - fromLeft) * lead;
    } else {
      leftEdge = fromLeft + (toLeft - fromLeft) * lead;
      rightEdge = fromLeft + itemWidth + (toLeft - fromLeft) * trail;
    }
    return (left: leftEdge, width: rightEdge - leftEdge);
  }

  double _slotLeft(int i, double itemWidth) =>
      _innerPadding + itemWidth * i;

  double _clampLeft(double rawLeft, double itemWidth) => rawLeft.clamp(
        _slotLeft(0, itemWidth),
        _slotLeft(_items.length - 1, itemWidth),
      );

  int _nearestIndex(double left, double itemWidth) {
    if (itemWidth <= 0) return widget.currentIndex;
    final slot = ((left - _innerPadding) / itemWidth).round();
    return slot.clamp(0, _items.length - 1);
  }

  int? _previewIndex(double itemWidth) {
    final dragLeft = _dragLeft.value;
    if (dragLeft == null) return null;
    return _nearestIndex(dragLeft, itemWidth);
  }

  void _dragTo(double localX, double itemWidth) {
    _settling = false;
    _dragLeft.value = _clampLeft(localX - itemWidth / 2, itemWidth);
  }

  void _beginDragFx() {
    if (MediaQuery.of(context).disableAnimations) return;
    _dragging = true;
    _vel = 0;
    if (!_fxTicker.isTicking) {
      _lastTickMicros = 0;
      _fxTicker.start();
    }
  }

  void _feedDragVelocity(double dx) {
    if (!_dragging) return;
    _vel = _vel * 0.45 + dx * 0.55;
  }

  void _endDragFx() {
    _dragging = false;
  }

  void _onFxTick(Duration elapsed) {
    final micros = elapsed.inMicroseconds;
    var dt = (micros - _lastTickMicros) / 1e6;
    _lastTickMicros = micros;
    if (dt <= 0) dt = 0.016;
    if (dt > 0.05) dt = 0.05;

    _vel *= math.exp(-dt / _velRelax);

    final intensity = (_vel / _refVelocity).clamp(-1.0, 1.0);
    final targetStretch = _dragging ? intensity : 0.0;
    final targetActivation = _dragging ? 1.0 : 0.0;

    _fxStretch +=
        (targetStretch - _fxStretch) * (1 - math.exp(-dt / _stretchEase));
    _fxActivation +=
        (targetActivation - _fxActivation) * (1 - math.exp(-dt / _actEase));

    if (!_dragging && _fxActivation.abs() < 0.001 && _fxStretch.abs() < 0.001) {
      _fxActivation = 0;
      _fxStretch = 0;
      _vel = 0;
      _lastTickMicros = 0;
      _dragFx.value = _WaterDragFx.rest;
      _fxTicker.stop();
      return;
    }
    _dragFx.value = _WaterDragFx(activation: _fxActivation, stretch: _fxStretch);
  }

  void _commitDrag(double itemWidth) {
    final start = _dragLeft.value;
    _dragLeft.value = null;
    if (start == null) return;
    final target = _nearestIndex(start, itemWidth);
    _beginSettle(start, target, itemWidth);
    if (target != widget.currentIndex) {
      HapticHelper.selectionClick();
      widget.onTabSelected(target);
    }
  }

  void _cancelDrag(double itemWidth) {
    final start = _dragLeft.value;
    _dragLeft.value = null;
    if (start == null) return;
    _beginSettle(start, widget.currentIndex, itemWidth);
  }

  void _beginSettle(double fromLeft, int target, double itemWidth) {
    _settleFromLeft = fromLeft;
    _settleToLeft = _slotLeft(target, itemWidth);
    _fromIndex = target;
    _toIndex = target;
    if (MediaQuery.of(context).disableAnimations) {
      _settling = false;
      _controller.value = 1.0;
    } else {
      _settling = true;
      _controller.forward(from: 0.0);
    }
  }

  ({double left, double width}) _resolveCapsule(double itemWidth) {
    final dragLeft = _dragLeft.value;
    if (dragLeft != null) return (left: dragLeft, width: itemWidth);
    if (_settling) {
      final t = Curves.easeOutBack.transform(_controller.value);
      return (
        left: lerpDouble(_settleFromLeft, _settleToLeft, t)!,
        width: itemWidth,
      );
    }
    return _capsuleMetrics(itemWidth);
  }

  double _lensFactor(int index, double itemWidth) {
    if (itemWidth <= 0) return 0;
    final activation = _dragFx.value.activation;
    if (activation <= 0) return 0;
    final capsule = _resolveCapsule(itemWidth);
    final capsuleCenter = capsule.left + capsule.width / 2;
    final itemCenter = _slotLeft(index, itemWidth) + itemWidth / 2;
    final norm = (capsuleCenter - itemCenter).abs() / itemWidth;
    final proximity = math.exp(-norm * norm * _lensFalloff);
    return proximity * activation;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bool highContrast = MediaQuery.of(context).highContrast;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Button active color: Apple Blue in dark mode, Vibrant Royal Purple in light mode.
    final Color buttonActiveColor =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFFA855F7);

    // Completely monochrome neutral for unselected tabs (Apple secondary in dark mode).
    final Color buttonNeutralColor = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF0F172A).withValues(alpha: 0.60);

    // Ultra-transparent glassfrost surface for the floating capsule.
    final Color glassfrostFill = highContrast
        ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF))
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.40));

    final Color glassfrostBorder = highContrast
        ? (isDark ? Colors.white : const Color(0xFF334155))
        : (isDark
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.75));

    // Pure crystal-clear transparent water bubble colors (ZERO blue or purple tint in the bubble).
    final _WaterBubbleColors waterColors = isDark
        ? _WaterBubbleColors(
            fillTop: Colors.white.withValues(alpha: 0.12),
            fillBottom: Colors.white.withValues(alpha: 0.03),
            border: Colors.white.withValues(alpha: 0.28),
            rimLight: Colors.white.withValues(alpha: 0.75),
            specular: Colors.white.withValues(alpha: 0.60),
            innerShade: Colors.black.withValues(alpha: 0.22),
            glow: Colors.white.withValues(alpha: 0.10),
          )
        : _WaterBubbleColors(
            fillTop: Colors.white.withValues(alpha: 0.55),
            fillBottom: Colors.white.withValues(alpha: 0.22),
            border: Colors.white.withValues(alpha: 0.65),
            rimLight: Colors.white.withValues(alpha: 0.95),
            specular: Colors.white.withValues(alpha: 0.85),
            innerShade: Colors.black.withValues(alpha: 0.06),
            glow: Colors.white.withValues(alpha: 0.25),
          );

    final barRadius = BorderRadius.circular(_barHeight / 2);
    final liftHeadroom = _dragTopOverflow + 8.0;
    final bottomHeadroom = _bottomLiftHeadroom;
    final bottomPadding = (_bottomGap - bottomHeadroom).clamp(
      0.0,
      double.infinity,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _horizontalMargin,
          0,
          _horizontalMargin,
          bottomPadding,
        ),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: SizedBox(
              height: _barHeight + liftHeadroom + bottomHeadroom,
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth =
                        constraints.maxWidth - _innerPadding * 2;
                    final itemWidth = contentWidth / _items.length;

                    // Frosted transparent glass bar
                    final glassBar = DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: barRadius,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 28,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: barRadius,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: highContrast ? 0 : 24,
                            sigmaY: highContrast ? 0 : 24,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: glassfrostFill,
                              borderRadius: barRadius,
                              border: Border.all(
                                color: glassfrostBorder,
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );

                    // Row of interactive tab items
                    final itemsRow = Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _innerPadding,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              Expanded(
                                child: _GlassNavItemWidget(
                                  item: _items[i],
                                  selected: i == widget.currentIndex,
                                  buttonActiveColor: buttonActiveColor,
                                  buttonNeutralColor: buttonNeutralColor,
                                  reduceMotion: reduceMotion,
                                  lensRepaint: _capsuleRepaint,
                                  lensFactor: () => _lensFactor(i, itemWidth),
                                  lensIconGain: _lensIconGain,
                                  lensLabelGain: _lensLabelGain,
                                  previewActive: () =>
                                      _previewIndex(itemWidth) == i,
                                  onTap: () {
                                    HapticHelper.selectionClick();
                                    widget.onTabSelected(i);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottomHeadroom,
                          height: _barHeight,
                          child: glassBar,
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottomHeadroom,
                          height: _barHeight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (d) {
                              _beginDragFx();
                              _dragTo(d.localPosition.dx, itemWidth);
                            },
                            onHorizontalDragUpdate: (d) {
                              _feedDragVelocity(d.delta.dx);
                              _dragTo(d.localPosition.dx, itemWidth);
                            },
                            onHorizontalDragEnd: (_) {
                              _endDragFx();
                              _commitDrag(itemWidth);
                            },
                            onHorizontalDragCancel: () {
                              _endDragFx();
                              _cancelDrag(itemWidth);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Pure transparent water bubble (ZERO blue/purple in bubble)
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _capsuleRepaint,
                                    builder: (context, _) {
                                      final m = _resolveCapsule(itemWidth);
                                      final fx = _dragFx.value;

                                      Widget bubble = _WaterBubble(
                                        colors: waterColors,
                                        blobHorizontalInset:
                                            _blobHorizontalInset,
                                        glowBoost: fx.activation,
                                      );

                                      final stretch = fx.stretch;
                                      if (stretch != 0) {
                                        bubble = Transform.scale(
                                          scaleX:
                                              1 + _dragStretch * stretch.abs(),
                                          scaleY:
                                              1 - _maxSquash * stretch.abs(),
                                          alignment: stretch >= 0
                                              ? Alignment.centerLeft
                                              : Alignment.centerRight,
                                          child: bubble,
                                        );
                                      }
                                      if (fx.activation != 0) {
                                        bubble = Transform.scale(
                                          scaleX: 1 +
                                              (_dragMagnify + _dragWiden) *
                                                  fx.activation,
                                          scaleY: 1 +
                                              _dragVerticalSwell *
                                                  fx.activation,
                                          alignment: Alignment.center,
                                          child: bubble,
                                        );
                                      }

                                      final a = fx.activation;
                                      final topInset = _capsuleVerticalInset -
                                          _dragTopOverflow * a;
                                      final bottomInset =
                                          _capsuleVerticalInset -
                                              _dragBottomOverflow * a;

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: m.left,
                                            width: m.width,
                                            top: topInset,
                                            bottom: bottomInset,
                                            child: bubble,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                // Items on top
                                itemsRow,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live drag dynamics for the water bubble.
@immutable
class _WaterDragFx {
  const _WaterDragFx({required this.activation, required this.stretch});

  final double activation;
  final double stretch;

  static const _WaterDragFx rest = _WaterDragFx(activation: 0, stretch: 0);
}

/// Pure transparent water bubble colors.
@immutable
class _WaterBubbleColors {
  const _WaterBubbleColors({
    required this.fillTop,
    required this.fillBottom,
    required this.border,
    required this.rimLight,
    required this.specular,
    required this.innerShade,
    required this.glow,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color rimLight;
  final Color specular;
  final Color innerShade;
  final Color glow;
}

/// Renders the transparent liquid water droplet bubble.
class _WaterBubble extends StatelessWidget {
  const _WaterBubble({
    required this.colors,
    required this.blobHorizontalInset,
    this.glowBoost = 0,
  });

  final _WaterBubbleColors colors;
  final double blobHorizontalInset;
  final double glowBoost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: blobHorizontalInset),
      child: CustomPaint(
        painter: _WaterBubblePainter(colors: colors, glowBoost: glowBoost),
      ),
    );
  }
}

/// Photorealistic transparent water bubble painter.
class _WaterBubblePainter extends CustomPainter {
  _WaterBubblePainter({required this.colors, required this.glowBoost});

  final _WaterBubbleColors colors;
  final double glowBoost;

  static const double _squircleN = 3.2;
  static const double _lensTaper = 0.24;
  static const double _restWaist = 0.05;
  static const double _squircleBulge = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final bulge = glowBoost;
    final body = _squirclePath(rect, bulge: bulge);

    // 1) Soft transparent water halo
    final glowPaint = Paint()
      ..color = colors.glow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 10 * glowBoost);
    canvas.drawPath(
      _squirclePath(rect.inflate(1.5 + 2.0 * glowBoost), bulge: bulge),
      glowPaint,
    );

    // 2) Subtle depth shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10 + 0.08 * glowBoost)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 5 * glowBoost);
    canvas.drawPath(
      _squirclePath(rect.shift(Offset(0, 2.0 + 2.5 * glowBoost)), bulge: bulge),
      shadowPaint,
    );

    canvas.save();
    canvas.clipPath(body);

    // 3) Pure water transparent body fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.fillTop, colors.fillBottom],
      ).createShader(rect);
    canvas.drawRect(rect, fillPaint);

    // 4) Refractive liquid shading (creates water volume)
    final shadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [const Color(0x00000000), colors.innerShade],
      ).createShader(rect);
    canvas.drawRect(rect, shadePaint);

    // 5) Bright white specular dome (water surface shine catch)
    final specRect = Rect.fromLTWH(
      size.width * 0.08,
      -size.height * 0.12,
      size.width * 0.84,
      size.height * 0.78,
    );
    final specPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [colors.specular, const Color(0x00FFFFFF)],
      ).createShader(specRect);
    canvas.drawOval(specRect, specPaint);

    canvas.restore();

    // 6) Clean crystal meniscus rim light along top edge
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.rimLight,
          colors.border,
          colors.border.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawPath(
      _squirclePath(rect.deflate(0.6), bulge: bulge),
      borderPaint,
    );
  }

  Path _squirclePath(Rect rect, {double bulge = 0}) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final a = rect.width / 2;
    final b = rect.height / 2;
    final exp = 2 / _squircleN;
    const steps = 64;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final ct = math.cos(theta);
      final st = math.sin(theta);
      final sx = ct.sign * math.pow(ct.abs(), exp).toDouble();
      final sy = st.sign * math.pow(st.abs(), exp).toDouble();
      final taper = 1 - _lensTaper * sx * sx;
      final swell = 1 + (_restWaist + bulge * _squircleBulge) * (1 - sy.abs());
      final x = cx + a * sx * swell;
      final y = cy + b * sy * taper;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _WaterBubblePainter old) =>
      old.glowBoost != glowBoost || old.colors != colors;
}

/// Navigation tab item: color illuminates ONLY when the transparent water bubble
/// touches / is centered over the tab.
class _GlassNavItemWidget extends StatefulWidget {
  const _GlassNavItemWidget({
    required this.item,
    required this.selected,
    required this.buttonActiveColor,
    required this.buttonNeutralColor,
    required this.reduceMotion,
    required this.lensRepaint,
    required this.lensFactor,
    required this.lensIconGain,
    required this.lensLabelGain,
    required this.previewActive,
    required this.onTap,
  });

  final GlassNavItemData item;
  final bool selected;
  final Color buttonActiveColor;
  final Color buttonNeutralColor;
  final bool reduceMotion;
  final Listenable lensRepaint;
  final double Function() lensFactor;
  final double lensIconGain;
  final double lensLabelGain;
  final bool Function() previewActive;
  final VoidCallback onTap;

  @override
  State<_GlassNavItemWidget> createState() => _GlassNavItemWidgetState();
}

class _GlassNavItemWidgetState extends State<_GlassNavItemWidget> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    const pressDuration = Duration(milliseconds: 120);
    const switchDuration = Duration(milliseconds: 200);
    const styleDuration = Duration(milliseconds: 280);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.90 : 1.0,
          duration: widget.reduceMotion ? Duration.zero : pressDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedBuilder(
            animation: widget.lensRepaint,
            builder: (context, _) {
              // Bubble touches the button either when selected or during live drag preview
              final isTouchedByBubble =
                  widget.selected || widget.previewActive();

              // Colour ONLY when touched by the bubble; otherwise clean monochrome neutral
              final color = isTouchedByBubble
                  ? widget.buttonActiveColor
                  : widget.buttonNeutralColor;

              final iconData = isTouchedByBubble
                  ? widget.item.selectedIcon
                  : widget.item.icon;

              final lens = widget.lensFactor();

              Widget icon = AnimatedSwitcher(
                duration: widget.reduceMotion ? Duration.zero : switchDuration,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  iconData,
                  key: ValueKey(isTouchedByBubble),
                  size: 22,
                  color: color,
                ),
              );

              icon = AnimatedScale(
                scale: isTouchedByBubble ? 1.12 : 1.0,
                duration: widget.reduceMotion ? Duration.zero : styleDuration,
                curve: isTouchedByBubble
                    ? Curves.easeOutBack
                    : Curves.easeOutCubic,
                child: icon,
              );

              if (widget.item.label == 'Travel') {
                icon = AnimatedSlide(
                  offset: isTouchedByBubble
                      ? const Offset(0.04, -0.08)
                      : Offset.zero,
                  duration: widget.reduceMotion ? Duration.zero : styleDuration,
                  curve: Curves.easeOutBack,
                  child: AnimatedRotation(
                    turns: isTouchedByBubble ? -0.06 : 0.0,
                    duration:
                        widget.reduceMotion ? Duration.zero : styleDuration,
                    curve: Curves.easeOutBack,
                    child: icon,
                  ),
                );
              }

              if (lens > 0) {
                icon = Transform.scale(
                  scale: 1 + widget.lensIconGain * lens,
                  child: icon,
                );
              }

              Widget label = AnimatedDefaultTextStyle(
                duration: widget.reduceMotion ? Duration.zero : styleDuration,
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight:
                      isTouchedByBubble ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: isTouchedByBubble ? -0.1 : 0.0,
                ),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );

              if (lens > 0) {
                label = Transform.scale(
                  scale: 1 + widget.lensLabelGain * lens,
                  child: label,
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 4),
                  label,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
