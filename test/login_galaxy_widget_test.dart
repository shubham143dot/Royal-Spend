import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/ui/widgets/galaxy_background.dart';

void main() {
  testWidgets(
    'galaxy coalesces rapid input pulses and bounds repeated tap effects',
    (tester) async {
      final inputPulse = ValueNotifier<int>(0);
      final touchPulse = ValueNotifier<GalaxyTouch?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: GalaxyBackground(
            inputPulse: inputPulse,
            touchPulse: touchPulse,
          ),
        ),
      );

      for (var index = 0; index < 40; index++) {
        inputPulse.value++;
      }
      await tester.pump(const Duration(milliseconds: 120));

      for (var index = 0; index < 12; index++) {
        touchPulse.value = GalaxyTouch(
          id: index,
          position: Offset(40 + index * 8, 60 + index * 5),
        );
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 1800));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      inputPulse.dispose();
      touchPulse.dispose();
    },
  );

  testWidgets('reduced motion keeps the static starfield usable', (
    tester,
  ) async {
    final inputPulse = ValueNotifier<int>(0);
    final touchPulse = ValueNotifier<GalaxyTouch?>(null);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GalaxyBackground(
            inputPulse: inputPulse,
            touchPulse: touchPulse,
          ),
        ),
      ),
    );

    inputPulse.value++;
    touchPulse.value = const GalaxyTouch(id: 1, position: Offset(120, 150));
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.descendant(
        of: find.byType(GalaxyBackground),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    inputPulse.dispose();
    touchPulse.dispose();
  });
}
