# Cards, Dialogs & Modal Pop Animations

This guide documents presentation choreography for cards, center pop dialogs, and interactive modals adapted from **`flutter/samples`**, **`gskinner/flutter_animate`**, and iOS HIG modal patterns.

---

## 1. Center Pop Dialog (iOS Alert & Modal Style)

Standard Material dialogs fade in rigidly. iOS-grade dialogs use a coordinated **Scale + Fade + Spring** entrance:

### Transition Specifications
- **Scale**: `0.85` $\to$ `1.0`
- **Opacity**: `0.0` $\to$ `1.0`
- **Curve**: `IOSSpringCurve.bouncy` ($\text{response}=0.38, \zeta=0.68$) or `Curves.easeOutBack`
- **Duration**: **320–380 ms**
- **Dismiss**: Fast fade + scale down (`0.95`, 180ms, `Curves.easeInCubic`)

### Flutter Custom Dialog Route Transition

```dart
Future<T?> showSpringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.54),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim1, anim2) => builder(ctx),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: IOSSpringCurve.bouncy,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
```

---

## 2. 3D Perspective Card Tilt (Gyro / Drag Physics)

For premium cards (credit cards, subscription plans, featured trip banners), adding a subtle 3D perspective tilt on touch drag produces an immersive physical feel:

```dart
class TiltCard extends StatefulWidget {
  final Widget child;
  const TiltCard({super.key, required this.child});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset _dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _dragOffset += details.delta;
        });
      },
      onPanEnd: (_) {
        setState(() {
          _dragOffset = Offset.zero;
        });
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: _dragOffset),
        duration: const Duration(milliseconds: 240),
        curve: IOSSpringCurve.interactive,
        builder: (context, offset, child) {
          final rotateX = (offset.dy / 250).clamp(-0.25, 0.25);
          final rotateY = (-offset.dx / 250).clamp(-0.25, 0.25);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D Perspective focal length
              ..rotateX(rotateX)
              ..rotateY(rotateY),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
```

---

## 3. Swipe-to-Dismiss Card Physics

When swiping items horizontally in a list:
1. Translate horizontally with 1:1 finger track.
2. Diminish scale slightly (`1.0 -> 0.96`) as card pulls away.
3. Fade opacity proportional to drag distance ($1.0 - \frac{|\Delta x|}{\text{threshold}}$).
4. If released before threshold, spring back with `IOSSpringCurve.snappy`.
5. If passed threshold, fling card offscreen and collapse slot height smoothly.
