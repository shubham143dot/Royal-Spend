# Page Transitions & Route Choreography

This guide documents screen-to-screen navigation transitions, Hero element morphs, and iOS-style parallax push/pop routes from **`flutter/samples`** and Apple Human Interface Guidelines.

---

## 1. iOS Parallax Push/Pop Route

Standard Android transitions fade or slide up. iOS navigation pushes the incoming screen from the right while shifting the outgoing screen to the left at $25\%$ parallax speed:

```dart
class CupertinoParallaxRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  CupertinoParallaxRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Incoming page slide
            final inCurve = CurvedAnimation(
              parent: animation,
              curve: Curves.fastEaseInToSlowEaseOut,
              reverseCurve: Curves.easeInCubic,
            );

            // Parallax outgoing page slide
            final outCurve = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.fastEaseInToSlowEaseOut,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.0),
                end: const Offset(-0.25, 0.0), // 25% parallax drag
              ).animate(outCurve),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(inCurve),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12 * animation.value),
                        blurRadius: 16,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
}
```

---

## 2. Hero Expansion Transition (Card $\to$ Detail Page)

When a card expands into a full workspace or detail screen:
1. Wrap the card in `Hero(tag: 'trip_${trip.id}', child: Material(type: MaterialType.transparency, child: ...))`.
2. Wrap the detail screen header or container with the identical `Hero` tag.
3. Configure custom `createRectTween` with a curved arc:

```dart
Hero(
  tag: 'card_${item.id}',
  createRectTween: (begin, end) {
    return MaterialRectArcTween(begin: begin, end: end);
  },
  flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            Tween<double>(begin: 20.0, end: 0.0).evaluate(animation),
          ),
          child: toHeroContext.widget,
        );
      },
    );
  },
  child: CardWidget(...),
);
```

---

## 3. Shared Axis Transition (Tabs & Steps)

For wizard steps or horizontal tab flows:
- Incoming page fades in while sliding 30dp along X-axis (`Offset(0.15, 0) -> Offset.zero`).
- Outgoing page fades out while sliding -30dp along X-axis.
- Duration: 240ms with `Curves.easeInOutCubic`.
