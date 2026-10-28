# Accessibility & 120Hz ProMotion Performance

This guide outlines performance optimization and accessibility standards for Flutter animations, ensuring zero-jank frame rendering at 120 FPS on modern displays (Apple ProMotion, Android 120Hz AMOLED) and compliance with OS accessibility preferences.

---

## 1. Respecting Reduced Motion (`disableAnimations`)

Users who experience vestibular motion disorders can enable "Reduce Motion" in their system accessibility settings. 

In Flutter, this is exposed via `MediaQuery.of(context).disableAnimations`:

```dart
class AccessibleAnimatedWidget extends StatelessWidget {
  final Widget child;
  const AccessibleAnimatedWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (disableAnimations) {
      // Return static child without springs or scale oscillations
      return child;
    }

    // Otherwise render spring animation
    return SpringButton(child: child);
  }
}
```

### Motion Graceful Fallback Strategy
- **Spring scale on tap**: Collapse to a simple highlight or instant action without scale.
- **Parallax / 3D tilts**: Disable completely.
- **Page transitions**: Substitute `SlideTransition` with an instantaneous cut or minimal 100ms cross-fade.
- **Staggered cascades**: Render all items simultaneously with `Duration.zero`.

---

## 2. 120 FPS Performance Rules (Impeller & Skia)

### Rule A: Animate Transforms and Opacity Only
- **Correct**: `Transform.scale`, `Transform.translate`, `ScaleTransition`, `SlideTransition`, `FadeTransition`.
  - These update the GPU transformation matrix or alpha channel directly without relayout or measure phases.
- **Incorrect**: Animating `width`, `height`, `margin`, `padding`, `BorderRadius`, or `constraints` on high-frequency gestures.
  - Modifying geometry invalidates layout constraints, forcing a full pass of `performLayout()` down the widget tree on every frame.

### Rule B: Isolate Paint Subtrees with `RepaintBoundary`
When an item in a list or complex dashboard card scales or slides, wrap it in `RepaintBoundary` so the surrounding scaffold doesn't re-rasterize:

```dart
RepaintBoundary(
  child: AnimatedBuilder(
    animation: _scaleAnimation,
    builder: (context, child) => Transform.scale(
      scale: _scaleAnimation.value,
      child: child,
    ),
    child: complexCardWidget,
  ),
);
```

### Rule C: Reuse Child Parameter in `AnimatedBuilder`
Never instantiate expensive child widgets inside the `AnimatedBuilder.builder` callback. Build the child once outside and pass it through the `child:` parameter:

```dart
// Efficient:
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) => Transform.scale(
    scale: _controller.value,
    child: child, // Reuses static pre-built subtree!
  ),
  child: const ExpensiveHeavyCard(),
);
```

### Rule D: Ticker & Controller Hygiene
- Always call `_controller.dispose()` in `State.dispose()`.
- Use `SingleTickerProviderStateMixin` when there is only one controller; use `TickerProviderStateMixin` only when multiple concurrent controllers exist.
- Avoid recurring `repeat()` tickers when the widget is off-screen.
