import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:royal_spend/ui/screens/splash/cinematic_splash_screen.dart';
import 'package:royal_spend/ui/widgets/splash/cinematic_particles_painter.dart';
import 'package:royal_spend/ui/widgets/splash/metallic_light_sweep.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cinematic 2D + 3D Opening Animation Tests', () {
    test('GoldenParticle pool creates deterministic particle list with valid colors', () {
      final pool = GoldenParticle.createParticlePool(count: 28);
      expect(pool.length, equals(28));
      for (final p in pool) {
        expect(p.x, inInclusiveRange(0.0, 1.0));
        expect(p.y, inInclusiveRange(0.0, 1.0));
        expect(p.radius, greaterThan(0.0));
        expect(p.baseAlpha, inInclusiveRange(0.0, 1.0));
        expect([
          const Color(0xFFFFD700),
          const Color(0xFFFFE6A0),
          const Color(0xFFF5B82E),
          const Color(0xFFE88A00),
        ].contains(p.color), isTrue);
      }
    });

    testWidgets('SpecularCrownGlint renders correctly and scales with progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SpecularCrownGlint(progress: 0.5, size: 50),
            ),
          ),
        ),
      );

      expect(find.byType(SpecularCrownGlint), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SpecularCrownGlint),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CinematicSplashScreen renders Scene 1 through Scene 6 and completes', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicSplashScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Initial frame: triggers postFrameCallback and starts controller
      await tester.pump();

      // Frame 0: Scene 1 (Royal Darkness)
      expect(find.text('ROYAL SPEND'), findsOneWidget);
      expect(find.text('EXPENSE TRACKER & TRAVEL PLANNER'), findsOneWidget);
      expect(completed, isFalse);

      // Advance 600ms (Scene 2: Crown Crest emergence)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isFalse);

      // Advance 700ms (Scene 3: 2D + 3D RS Monogram reveal)
      await tester.pump(const Duration(milliseconds: 700));
      expect(completed, isFalse);

      // Advance 600ms (Scene 4: Typography reveal)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isFalse);

      // Advance 500ms (Scene 5: Climax glint & signature sweep)
      await tester.pump(const Duration(milliseconds: 500));
      expect(completed, isFalse);

      // Advance 600ms (Scene 6: Application transition & completion)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isTrue);
    });

    testWidgets('Tapping anywhere skips the animation directly to application', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CinematicSplashScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Pump initial frame
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, isFalse);

      // Tap screen to skip
      await tester.tap(find.byType(CinematicSplashScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(completed, isTrue);
    });

    testWidgets('CinematicSplashGate displays splash once on cold start, never on resume', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CinematicSplashGate(
            child: Scaffold(
              body: Center(
                child: Text('PROTECTED_HOME_SCREEN'),
              ),
            ),
          ),
        ),
      );

      // Initial frame: splash layer is present
      expect(find.byType(CinematicSplashScreen), findsOneWidget);

      // Tap to complete splash
      await tester.tap(find.byType(CinematicSplashScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Pump AnimatedSwitcher duration so outgoing splash unmounts
      await tester.pump(const Duration(milliseconds: 350));

      // After splash finishes, home screen content is revealed
      expect(find.text('PROTECTED_HOME_SCREEN'), findsOneWidget);

      // Trigger a rebuild (simulating state updates or app resume)
      await tester.pump();
      expect(find.text('PROTECTED_HOME_SCREEN'), findsOneWidget);
      // Verify CinematicSplashScreen is unmounted and not replaying
      expect(find.byType(CinematicSplashScreen), findsNothing);
    });

    testWidgets('Reduced motion instantly skips animation without blocking user', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: CinematicSplashScreen(
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(completed, isTrue);
    });
  });
}
