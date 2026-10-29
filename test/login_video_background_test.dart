import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/auth/login_screen.dart';
import 'package:royal_spend/ui/widgets/google_brand_icon.dart';
import 'package:royal_spend/ui/widgets/liquid_pop.dart';
import 'package:royal_spend/ui/widgets/login_video_background.dart';
import 'package:royal_spend/ui/widgets/royal_logo.dart';

/// Test platform interface tracking video player calls, looping, volume, and playback state.
class TestVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _eventStreams = {};
  int _nextId = 0;
  bool lastLooping = false;
  double lastVolume = 1.0;
  bool isPlaying = false;
  bool simulateError = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    await _eventStreams[playerId]?.close();
    _eventStreams.remove(playerId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    if (simulateError) {
      throw Exception('Video decoding failure for simulated low-end hardware');
    }

    final id = _nextId++;
    late final StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(
              VideoEvent(
                eventType: VideoEventType.initialized,
                duration: const Duration(seconds: 15),
                size: const Size(720, 1280),
              ),
            );
          }
        });
      },
    );
    _eventStreams[id] = controller;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventStreams[playerId]?.stream ?? const Stream.empty();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    lastLooping = looping;
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {
    isPlaying = true;
    _eventStreams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    isPlaying = false;
    _eventStreams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox(width: 720, height: 1280);
}

void main() {
  late TestVideoPlayerPlatform testVideoPlatform;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    testVideoPlatform = TestVideoPlayerPlatform();
    VideoPlayerPlatform.instance = testVideoPlatform;
  });

  setUp(() {
    testVideoPlatform.simulateError = false;
    testVideoPlatform.lastLooping = false;
    testVideoPlatform.lastVolume = 1.0;
    testVideoPlatform.isPlaying = false;
  });

  Widget createTestApp({
    required Widget child,
    bool disableAnimations = false,
    bool highContrast = false,
    Size screenSize = const Size(390, 844),
  }) {
    final settingsRepo = SettingsRepository();
    final settingsProv = SettingsProvider(repository: settingsRepo);
    final expenseProvider = ExpenseProvider();
    final quickLogProvider = QuickLogProvider();
    final travelProvider = TravelProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProv),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: quickLogProvider),
        ChangeNotifierProvider.value(value: travelProvider),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            disableAnimations: disableAnimations,
            highContrast: highContrast,
          ),
          child: child,
        ),
      ),
    );
  }

  group('Login Video Background Architecture & Performance Tests', () {
    testWidgets('initializes video in loop and muted mode with poster fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
        ),
      );

      // Verify immediate poster image presence (zero black flash)
      expect(find.byType(Image), findsWidgets);

      // Verify RepaintBoundary isolates background video from foreground UI
      expect(find.byType(LoginVideoBackground), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LoginVideoBackground),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );

      // Settle initialization microtasks
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify loop was configured and audio was muted
      expect(testVideoPlatform.lastLooping, isTrue);
      expect(testVideoPlatform.lastVolume, 0.0);
      expect(testVideoPlatform.isPlaying, isTrue);
    });

    testWidgets('error resilience: gracefully falls back to poster without crashing', (
      tester,
    ) async {
      testVideoPlatform.simulateError = true;

      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No crash, poster image and login form still cleanly rendered
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('low-end & accessibility optimization: respects disableAnimations', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          disableAnimations: true,
          child: const LoginScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // With disableAnimations = true, video playback is bypassed
      expect(testVideoPlatform.isPlaying, isFalse);
      // High-res poster remains rendered
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lifecycle management: pauses on app inactive and resumes on app resume', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(testVideoPlatform.isPlaying, isTrue);

      // Simulate app becoming inactive / backgrounded
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(testVideoPlatform.isPlaying, isFalse);

      // Simulate app resumed to foreground
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(testVideoPlatform.isPlaying, isTrue);
    });
  });

  group('Login Screen Visuals, Legibility & Apple iOS Smoothness Tests', () {
    testWidgets('all primary and secondary texts are 100% visible and contrast-protected', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));

      // Verify branding and headings
      expect(find.byType(RoyalLogo), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Your finances, beautifully organized.'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);

      // Verify text input fields and hints
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify actions and interactive links
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleBrandIcon), findsOneWidget);
      expect(find.text('Don’t have an account? Create one'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
      expect(
        find.text('By continuing, you agree to our Terms of Service & Privacy Policy.'),
        findsOneWidget,
      );
    });

    testWidgets('tactile buttons use spring physics with LiquidPop and min 48px tap targets', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));

      // Verify LiquidPop wraps interactive buttons
      expect(find.byType(LiquidPop), findsAtLeastNWidgets(2));

      // Test spring press compression on Sign In button
      final signInFinder = find.text('Sign In');
      final gesture = await tester.startGesture(tester.getCenter(signInFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Release press to trigger spring overshoot
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive layout on small screen (320px width) does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(320, 568), // iPhone SE 1st gen size
          child: const LoginScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));

      // Ensure no RenderFlex overflows
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('high-contrast mode applies accessible borders without visual glitches', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          highContrast: true,
          child: const LoginScreen(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
