# Declarative Animation Chaining & Micro-Interactions

This guide documents declarative extension patterns adapted from **`gskinner/flutter_animate`**, enabling chained micro-interactions and staggered cascades with zero boilerplate.

---

## 1. Declarative Extension Pattern

Instead of creating `StatefulWidget`, `AnimationController`, `CurvedAnimation`, and `AnimatedBuilder` for simple micro-interactions, we can provide clean extension methods on `Widget` that wrap standard Flutter implicit widgets:

### Implementation: Fluent Animation Extension

```dart
import 'package:flutter/material.dart';

extension PremiumAnimateExtension on Widget {
  /// Applies a coordinated fade + slide entrance with an optional stagger delay.
  Widget animateEntrance({
    Duration duration = const Duration(milliseconds: 380),
    Duration delay = Duration.zero,
    Offset beginOffset = const Offset(0, 0.12),
    Curve curve = Curves.easeOutCubic,
  }) {
    return _EntranceAnimationWrapper(
      duration: duration,
      delay: delay,
      beginOffset: beginOffset,
      curve: curve,
      child: this,
    );
  }

  /// Wraps the widget with an error shake animation.
  Widget animateShake({
    required bool trigger,
    Duration duration = const Duration(milliseconds: 360),
    double offset = 8.0,
  }) {
    return _ShakeAnimationWrapper(
      trigger: trigger,
      duration: duration,
      offset: offset,
      child: this,
    );
  }
}

class _EntranceAnimationWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;
  final Curve curve;

  const _EntranceAnimationWrapper({
    required this.child,
    required this.duration,
    required this.delay,
    required this.beginOffset,
    required this.curve,
  });

  @override
  State<_EntranceAnimationWrapper> createState() => _EntranceAnimationWrapperState();
}

class _EntranceAnimationWrapperState extends State<_EntranceAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
```

---

## 2. Staggering Lists & Grids

When loading a dashboard, transaction history, or card feed, staggered entry prevents visual barrage:

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return items[index].animateEntrance(
      delay: Duration(milliseconds: (index * 40).clamp(0, 400)),
      beginOffset: const Offset(0, 0.08),
    );
  },
);
```

### Stagger Rules
- **Base Interval**: 35–50 ms per item.
- **Maximum Delay Cap**: 350–400 ms total. Items past index 8–10 should animate together so the user doesn't wait indefinitely.
- **Direction**: Vertical items translate up (`Offset(0, 0.1)`); horizontal carousel items translate from the trailing side (`Offset(0.1, 0)`).

---

## 3. Shimmer Skeleton Sweep

A subtle gradient highlight passing across placeholder shapes during network loading:

```dart
class ShimmerLoadingBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoadingBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerLoadingBox> createState() => _ShimmerLoadingBoxState();
}

class _ShimmerLoadingBoxState extends State<ShimmerLoadingBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3.0 * _controller.value, -0.3),
              end: Alignment(-0.5 + 3.0 * _controller.value, 0.3),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}
```
