# Button & Interactive Tap Animations

This guide documents tactile button physics and tap interactions synthesized from **`bizz84/flutter_animations_gallery`**, **`amosgyamfi/open-swiftui-animations`**, and iOS HIG tap standards.

---

## 1. Anatomy of an iOS-Grade Button Press

A high-fidelity button interaction consists of 4 distinct phases:

1. **Touch Down (Instant Shrink)**:
   - Scale decreases to `0.95` (or `0.93` for compact icons, `0.97` for full-width action bars).
   - Duration: **80–110 ms**.
   - Curve: `Curves.easeOutCubic`.
   - Haptics: Light tactile click fired immediately on touch down.

2. **Touch Hold (Steady State)**:
   - Button maintains compressed scale while finger remains within hit test boundaries.

3. **Touch Up (Spring Rebound)**:
   - On finger release inside target bounds, button springs back to `1.0`.
   - Curve: `IOSSpringCurve.snappy` ($\text{response}=0.35, \zeta=0.70$).
   - Duration: **320–420 ms**.
   - The user callback `onTap` triggers smoothly.

4. **Touch Cancel (Recovery)**:
   - If the finger slides out of bounds (`onTapCancel`), the scale springs back to `1.0` smoothly without triggering `onTap`.

---

## 2. Drop-in Implementation Pattern: `SpringButton`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../examples/spring_curves.dart';

class SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptics;

  const SpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.95,
    this.pressDuration = const Duration(milliseconds: 90),
    this.releaseDuration = const Duration(milliseconds: 360),
    this.enableHaptics = true,
  });

  @override
  State<SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<SpringButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: IOSSpringCurve.snappy,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse();
    widget.onTap!();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptics) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
```

---

## 3. Squish & Stretch Variations

For expressive playful buttons (e.g. game elements, celebration actions):

```dart
// Asymmetric scaling: shrink vertically more than horizontally on press
Transform.scale(
  scaleX: 1.0 + (1.0 - scale) * 0.4, // Slight horizontal bulge
  scaleY: scale,                     // Vertical compression
  child: child,
);
```

---

## 4. Key Pitfalls to Avoid

- **Do NOT use `AnimatedContainer` for tap scale**: `AnimatedContainer` triggers layout recalculation if constraints aren't completely rigid. Use `Transform.scale` or `ScaleTransition` which operate on the RenderBox paint layer.
- **Do NOT omit `onTapCancel`**: If a user drags their thumb away to cancel the tap, failing to handle `onTapCancel` leaves the button stuck at `0.95` scale.
- **Do NOT exceed `0.90` scale compression**: Compressing smaller than 0.90 causes visual disorientation and makes icons look like they are disappearing.
