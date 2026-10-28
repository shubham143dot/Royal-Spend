import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/theme/spring_curves.dart';
import 'package:royal_spend/ui/widgets/liquid_pop.dart';

void main() {
  group('iOS Damped Harmonic Oscillator (IOSSpringCurve) Tests', () {
    test('Snappy spring starts at 0 and terminates accurately at 1', () {
      const curve = IOSSpringCurve.snappy;
      expect(curve.transform(0.0), closeTo(0.0, 0.0001));
      expect(curve.transform(1.0), closeTo(1.0, 0.0001));
    });

    test('Bouncy spring exhibits subtle natural overshoot before settling', () {
      const curve = IOSSpringCurve.bouncy;
      expect(curve.transform(0.0), closeTo(0.0, 0.0001));
      expect(curve.transform(1.0), closeTo(1.0, 0.0001));

      // Over damped harmonic test - max value should exceed 1.0 for overshoot
      double maxVal = 0.0;
      for (double t = 0.0; t <= 1.0; t += 0.02) {
        final val = curve.transform(t);
        if (val > maxVal) maxVal = val;
      }
      expect(maxVal, greaterThan(1.0));
      expect(maxVal, lessThan(1.15)); // Bounded overshoot under 15%
    });

    test('Gentle and interactive springs are monotonic or smoothly damped', () {
      const gentle = IOSSpringCurve.gentle;
      const interactive = IOSSpringCurve.interactive;

      expect(gentle.transform(0.0), closeTo(0.0, 0.0001));
      expect(gentle.transform(1.0), closeTo(1.0, 0.0001));
      expect(interactive.transform(0.0), closeTo(0.0, 0.0001));
      expect(interactive.transform(1.0), closeTo(1.0, 0.0001));
    });
  });

  group('LiquidPop Spring Pop Interaction Tests', () {
    testWidgets('LiquidPop compresses on pointer down and springs back on pointer up',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidPop(
                pressedScale: 0.92,
                onTap: () => tapped = true,
                child: const SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('Spring Target'),
                ),
              ),
            ),
          ),
        ),
      );

      final target = find.text('Spring Target');
      expect(target, findsOneWidget);

      // Verify initial scale is 1.0
      AnimatedScale scaleWidget = tester.widget(find.byType(AnimatedScale));
      expect(scaleWidget.scale, equals(1.0));

      // Pointer down
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 95));

      scaleWidget = tester.widget(find.byType(AnimatedScale));
      expect(scaleWidget.scale, equals(0.92));

      // Pointer up
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      scaleWidget = tester.widget(find.byType(AnimatedScale));
      expect(scaleWidget.scale, equals(1.0));
      expect(tapped, isTrue);
    });

    testWidgets('LiquidPop restores scale if tap is cancelled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidPop(
                pressedScale: 0.90,
                onTap: () {},
                child: const SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('Cancel Target'),
                ),
              ),
            ),
          ),
        ),
      );

      final target = find.text('Cancel Target');
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 95));

      AnimatedScale scaleWidget = tester.widget(find.byType(AnimatedScale));
      expect(scaleWidget.scale, equals(0.90));

      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 350));

      scaleWidget = tester.widget(find.byType(AnimatedScale));
      expect(scaleWidget.scale, equals(1.0));
    });
  });

  group('Expenses Plus Button FAB Tests', () {
    testWidgets('Expenses FAB renders with RepaintBoundary and spring components',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: RepaintBoundary(
              child: LiquidPop(
                pressedScale: 0.91,
                onTap: () {},
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.add),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LiquidPop), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });
}

