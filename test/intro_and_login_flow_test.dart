import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/auth/royal_auth_gateway.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/auth/login_screen.dart';
import 'package:royal_spend/ui/screens/intro/intro_screen.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';
import 'package:royal_spend/ui/widgets/google_brand_icon.dart';
import 'package:royal_spend/ui/widgets/royal_glass_button.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _eventStreams = {};
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    await _eventStreams[playerId]?.close();
    _eventStreams.remove(playerId);
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _nextId++;
    final controller = StreamController<VideoEvent>.broadcast();
    _eventStreams[id] = controller;
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 10),
            size: const Size(1080, 1920),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventStreams[playerId]?.stream ?? const Stream.empty();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {
    _eventStreams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _eventStreams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox(width: 1080, height: 1920);
}

class FakeRoyalAuthGateway implements RoyalAuthGateway {
  int signInCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
  }

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> signInWithGoogle() async {}
}

class FakeSettingsRepository extends SettingsRepository {
  @override
  Future<void> setHasCompletedIntro(bool completed) async {}

  @override
  Future<void> setIsAuthenticated(bool authenticated) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  Widget createTestWidget({required Widget child, SettingsProvider? settings}) {
    final settingsRepo = SettingsRepository();
    final settingsProv = settings ?? SettingsProvider(repository: settingsRepo);
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
        home: child,
      ),
    );
  }

  group('RoyalGlassButton Widget Tests', () {
    testWidgets('renders label, leading icon, and triggers onPressed', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: Center(
              child: RoyalGlassButton(
                label: 'Get Started',
                trailing: const Icon(Icons.arrow_forward),
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(
            body: Center(
              child: RoyalGlassButton(
                label: 'Continue',
                isLoading: true,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });
  });

  group('GoogleBrandIcon Widget Tests', () {
    testWidgets('paints Google brand vector icon crisply without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GoogleBrandIcon(size: 24))),
        ),
      );

      expect(find.byType(GoogleBrandIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen Tests', () {
    testWidgets('renders the galaxy login form, branding, and auth actions', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));

      // Fast forward entrance animations
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // Verify luxury branding typography
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Your finances, beautifully organized.'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Don’t have an account? Create one'), findsOneWidget);

      // Verify Google Authentication button exists
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleBrandIcon), findsOneWidget);

      // Verify Development Skip bypass exists when enabled
      if (AppConstants.enableDevAuthBypass) {
        expect(find.text('Skip for now'), findsOneWidget);
      }

      // Verify Privacy & Terms notice
      expect(
        find.text(
          'By continuing, you agree to our Terms of Service & Privacy Policy.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Google sign-in clearly reports that auth is not configured', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      // Tap Continue with Google
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Google sign-in isn’t connected'), findsOneWidget);
      expect(find.text('Use Demo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Google sign-in isn’t connected'), findsNothing);
      expect(find.text('Google sign-in isn’t connected'), findsNothing);
    });

    testWidgets('empty sign-in shows field-level validation errors', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets(
      'password visibility toggles without replacing the entered value',
      (tester) async {
        await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
        await tester.pump(const Duration(milliseconds: 700));
        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(passwordField, 'private-value');
        await tester.pump();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).at(1))
              .obscureText,
          isTrue,
        );
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).at(1))
              .obscureText,
          isFalse,
        );
        expect(
          tester.widget<TextFormField>(passwordField).controller!.text,
          'private-value',
        );
      },
    );

    testWidgets(
      'forgot password explains that a reset provider is unavailable',
      (tester) async {
        await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'person@example.com',
        );
        await tester.pump();
        await tester.tap(find.text('Forgot Password?'));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.text('Send reset link'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text(
            'Password reset is unavailable until sign-in is connected.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Create Account switches to a validated registration form', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(
        find.text('Don’t have an account? Create one'),
      );
      await tester.tap(find.text('Don’t have an account? Create one'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('create-account-form')),
          matching: find.byType(TextFormField),
        ),
        findsNWidgets(4),
      );
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pump();
      expect(find.text('Enter your name.'), findsOneWidget);
    });

    testWidgets(
      'valid credentials only navigate after the auth gateway succeeds',
      (tester) async {
        final settingsProvider = SettingsProvider(
          repository: FakeSettingsRepository(),
        );
        final authGateway = FakeRoyalAuthGateway();
        await tester.pumpWidget(
          createTestWidget(
            settings: settingsProvider,
            child: LoginScreen(authGateway: authGateway),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'person@example.com',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'correct-horse-battery',
        );
        await tester.ensureVisible(find.text('Sign In'));
        await tester.tap(find.text('Sign In'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(authGateway.signInCalls, 1);
        expect(settingsProvider.isAuthenticated, isTrue);
        expect(settingsProvider.hasCompletedIntro, isTrue);
        expect(find.byType(MainNavigationScreen), findsOneWidget);
      },
    );

    testWidgets('tapping Skip for now marks intro completed and navigates', (
      tester,
    ) async {
      final settingsRepo = SettingsRepository();
      final settingsProv = SettingsProvider(repository: settingsRepo);

      await tester.pumpWidget(
        createTestWidget(settings: settingsProv, child: const LoginScreen()),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 700));

      await tester.ensureVisible(find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(settingsProv.hasCompletedIntro, isTrue);
    });
  });

  group('IntroScreen Tests', () {
    testWidgets(
      'renders intro screen with video player and skip pill, then reveals Get Started on skip',
      (tester) async {
        await tester.pumpWidget(createTestWidget(child: const IntroScreen()));

        // Initial pump to mount and initialize video
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Skip button is present initially during intro
        expect(find.text('Skip'), findsOneWidget);

        // Tap Skip to fast forward to completed intro state
        await tester.tap(find.text('Skip'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Get Started button should now be revealed without any overlay logo covering the video
        expect(find.text('Get Started'), findsOneWidget);
      },
    );

    testWidgets('tapping Get Started initiates transition to LoginScreen', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const IntroScreen()));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Tap Get Started button
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Destination LoginScreen content appears
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
