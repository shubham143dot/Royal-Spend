import 'dart:math';
import 'package:flutter/animation.dart';

/// Pure Dart implementation of iOS-style spring curves.
///
/// Adapted from SwiftUI's `withAnimation(.spring(response:dampingFraction:))`
/// and physical harmonic oscillator formulations.
///
/// Can be used as a drop-in replacement for any Flutter [Curve].
class IOSSpringCurve extends Curve {
  /// The duration of one natural oscillation in seconds.
  /// Typically between 0.3 and 0.5.
  final double response;

  /// The damping ratio (zeta).
  /// - < 1.0: Underdamped (oscillates with bounce)
  /// - = 1.0: Critically damped (snappy without overshoot)
  /// - > 1.0: Overdamped (sluggish)
  final double dampingFraction;

  const IOSSpringCurve({
    this.response = 0.40,
    this.dampingFraction = 0.75,
  }) : assert(dampingFraction > 0, 'dampingFraction must be greater than zero');

  /// Snappy spring: quick reaction with subtle organic settling.
  /// Best for button releases, toggles, segmented controls, and chips.
  static const IOSSpringCurve snappy = IOSSpringCurve(
    response: 0.35,
    dampingFraction: 0.70,
  );

  /// Bouncy spring: noticeable playful spring overshoot.
  /// Best for dialog entrance pop, celebration badges, and notification alerts.
  static const IOSSpringCurve bouncy = IOSSpringCurve(
    response: 0.40,
    dampingFraction: 0.58,
  );

  /// Gentle spring: smooth, elegant settle with minimal overshoot.
  /// Best for bottom sheets, large card expansions, and route transitions.
  static const IOSSpringCurve gentle = IOSSpringCurve(
    response: 0.45,
    dampingFraction: 0.85,
  );

  /// Interactive spring: very responsive spring for finger drag releases.
  static const IOSSpringCurve interactive = IOSSpringCurve(
    response: 0.30,
    dampingFraction: 0.80,
  );

  @override
  double transformInternal(double t) {
    if (t == 0.0) return 0.0;
    if (t >= 1.0) return 1.0;

    final omega0 = 2.0 * pi / response;
    final zeta = dampingFraction;

    if (zeta < 1.0) {
      // Underdamped harmonic oscillator analytic solution
      final omegaD = omega0 * sqrt(1.0 - zeta * zeta);
      final decay = exp(-zeta * omega0 * t);
      return 1.0 - decay * (cos(omegaD * t) + (zeta / sqrt(1.0 - zeta * zeta)) * sin(omegaD * t));
    } else {
      // Critically damped harmonic oscillator analytic solution
      final decay = exp(-omega0 * t);
      return 1.0 - decay * (1.0 + omega0 * t);
    }
  }
}
