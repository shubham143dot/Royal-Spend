# Spring Physics & Mathematical Foundations

This reference translates iOS/SwiftUI spring animation mechanics from **`GetStream/swiftui-spring-animations`** and **`amosgyamfi/open-swiftui-animations`** into high-performance, drop-in Flutter/Dart code.

---

## 1. Mathematical Formulation

A damped harmonic oscillator obeys the differential equation:

$$m \frac{d^2x}{dt^2} + c \frac{dx}{dt} + k x = 0$$

Where:
- $m$ = mass
- $c$ = damping coefficient
- $k$ = spring stiffness constant

### SwiftUI Parameters vs. Physical Properties

SwiftUI parameterizes springs using **`response`** and **`dampingFraction`**:
- **`response` ($T_0$)**: The natural period of the undamped spring in seconds (typically $0.3\text{s} - 0.5\text{s}$). It dictates how quickly the spring reacts.
- **`dampingFraction` ($\zeta$)**: The ratio of actual damping to critical damping.
  - $\zeta < 1.0$: **Underdamped**. The system overshoots the target and oscillates back and forth. (Ideal for tactile bounce: $0.65 \le \zeta \le 0.85$).
  - $\zeta = 1.0$: **Critically Damped**. Returns to equilibrium as rapidly as possible without overshooting. (Ideal for sheet presentation, standard navigation).
  - $\zeta > 1.0$: **Overdamped**. Sluggish, no overshoot.

### Conversion Formulas (SwiftUI $\to$ Flutter)

Given SwiftUI values `response` and `dampingFraction` with unit mass ($m = 1.0$):

$$\omega_0 = \frac{2\pi}{\text{response}}$$

$$\text{stiffness } (k) = \omega_0^2 = \left(\frac{2\pi}{\text{response}}\right)^2$$

$$\text{damping } (c) = 2 \zeta \sqrt{k \cdot m} = 2 \zeta \omega_0 = \frac{4\pi \zeta}{\text{response}}$$

In Flutter's `flutter/physics.dart`:
```dart
import 'dart:math';
import 'package:flutter/physics.dart';

SpringDescription springFromSwiftUI({
  required double response,
  required double dampingFraction,
  double mass = 1.0,
}) {
  final omega0 = 2 * pi / response;
  final stiffness = pow(omega0, 2) * mass;
  final damping = 2 * dampingFraction * omega0 * mass;
  return SpringDescription(
    mass: mass,
    stiffness: stiffness.toDouble(),
    damping: damping.toDouble(),
  );
}
```

---

## 2. Analytic `Curve` Implementation (Zero Dependencies)

Flutter's standard `AnimationController` and implicit widgets (`AnimatedContainer`, `AnimatedScale`, `AnimatedPositioned`) take a `Curve`. 

By solving the underdamped harmonic equation analytically over the normalized time range $t \in [0, 1]$, we produce a drop-in Flutter `Curve` that exhibits exact iOS spring physics without requiring physics simulation tickers:

$$x(t) = 1 - e^{-\zeta \omega_0 t} \left( \cos(\omega_d t) + \frac{\zeta}{\sqrt{1 - \zeta^2}} \sin(\omega_d t) \right)$$

where $\omega_d = \omega_0 \sqrt{1 - \zeta^2}$.

### Complete Dart Implementation

```dart
import 'dart:math';
import 'package:flutter/animation.dart';

class IOSSpringCurve extends Curve {
  final double response;
  final double dampingFraction;

  const IOSSpringCurve({
    this.response = 0.4,
    this.dampingFraction = 0.75,
  }) : assert(dampingFraction > 0, 'Damping fraction must be positive');

  /// Snappy spring: quick reaction with subtle settling bounce (buttons, toggles).
  static const IOSSpringCurve snappy = IOSSpringCurve(response: 0.35, dampingFraction: 0.70);

  /// Bouncy spring: noticeable springiness for badges, dialog pops, celebrations.
  static const IOSSpringCurve bouncy = IOSSpringCurve(response: 0.40, dampingFraction: 0.58);

  /// Gentle spring: smooth, elegant settle with zero jarring (cards, sheets).
  static const IOSSpringCurve gentle = IOSSpringCurve(response: 0.45, dampingFraction: 0.85);

  /// Interactive drag release spring.
  static const IOSSpringCurve interactive = IOSSpringCurve(response: 0.30, dampingFraction: 0.80);

  @override
  double transformInternal(double t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;

    final omega0 = 2 * pi / response;
    final zeta = dampingFraction;

    if (zeta < 1.0) {
      // Underdamped (oscillates with decay)
      final omegaD = omega0 * sqrt(1.0 - zeta * zeta);
      final decay = exp(-zeta * omega0 * t);
      return 1.0 - decay * (cos(omegaD * t) + (zeta / sqrt(1.0 - zeta * zeta)) * sin(omegaD * t));
    } else {
      // Critically damped or overdamped
      final decay = exp(-omega0 * t);
      return 1.0 - decay * (1.0 + omega0 * t);
    }
  }
}
```

---

## 3. Flutter `SpringSimulation` for Gesture Velocity

When user drags an element and releases it with velocity $v_0$, an explicit `SpringSimulation` inherits the finger release velocity:

```dart
void releaseWithVelocity(Offset velocity, Offset currentPosition, Offset targetPosition) {
  final spring = SpringDescription(mass: 1.0, stiffness: 180.0, damping: 20.0);
  final simulationX = SpringSimulation(spring, currentPosition.dx, targetPosition.dx, velocity.dx);
  final simulationY = SpringSimulation(spring, currentPosition.dy, targetPosition.dy, velocity.dy);
  
  _controller.animateWith(simulationY);
}
```
This ensures continuity of motion with zero visual hitch at the moment of touch release.
