import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/security/app_lock_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/app_lock_provider.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';
import 'package:royal_spend/ui/widgets/security/app_lock_gate.dart';

class FakeAppLockService implements IAppLockService {
  bool isSupported = true;
  bool canCheck = true;
  bool isSecure = true;
  List<BiometricType> biometrics = [BiometricType.fingerprint];
  bool authResult = true;
  bool isAuthenticatingNow = false;
  int authCallCount = 0;
  String? lastReason;

  @override
  bool get isAuthenticating => isAuthenticatingNow;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<bool> isDeviceSecure() async => isSecure;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<bool> authenticate({required String reason}) async {
    authCallCount++;
    lastReason = reason;
    return authResult;
  }

  @override
  Future<void> stopAuthentication() async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppLockProvider Unit & Lifecycle Tests', () {
    late FakeAppLockService fakeService;
    late SettingsRepository settingsRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeService = FakeAppLockService();
      settingsRepo = SettingsRepository();
    });

    test('Initializes with default state (App Lock disabled, app unlocked)', () async {
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );

      await provider.init();

      expect(provider.isAppLockEnabled, isFalse);
      expect(provider.isLocked, isFalse);
      expect(provider.isAuthenticating, isFalse);
      expect(provider.isDeviceSupported, isTrue);
      expect(provider.availableBiometrics, contains(BiometricType.fingerprint));
      expect(provider.securityIcon, Icons.fingerprint);
      expect(provider.biometricDescription, contains('Fingerprint'));
    });

    test('Initializes in locked state when App Lock was previously enabled', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });

      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );

      await provider.init();

      expect(provider.isAppLockEnabled, isTrue);
      // Must be locked on startup to prevent data leakage
      expect(provider.isLocked, isTrue);
    });

    test('Biometric icons and descriptions reflect Face ID and generic security', () async {
      // Face ID
      fakeService.biometrics = [BiometricType.face];
      final faceProvider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await faceProvider.init();
      expect(faceProvider.securityIcon, CupertinoIcons.person_crop_circle_badge_checkmark);
      expect(faceProvider.biometricDescription, contains('Face ID'));

      // Generic / No biometrics (PIN / Pattern only)
      fakeService.biometrics = [];
      final genericProvider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await genericProvider.init();
      expect(genericProvider.securityIcon, CupertinoIcons.lock_shield_fill);
      expect(genericProvider.biometricDescription, contains('PIN, Pattern'));
    });

    testWidgets('enableAppLock fails when device has no screen lock setup', (tester) async {
      fakeService.isSecure = false;
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await provider.enableAppLock(context);
                },
                child: const Text('Enable'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(provider.isAppLockEnabled, isFalse);
      expect(provider.errorMessage, 'Please set up a screen lock on your device to enable App Lock.');
      expect(await settingsRepo.isAppLockEnabled(), isFalse);
    });

    testWidgets('enableAppLock fails when native authentication is cancelled or fails', (tester) async {
      fakeService.isSecure = true;
      fakeService.authResult = false; // Auth fails
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await provider.enableAppLock(context);
                },
                child: const Text('Enable'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(provider.isAppLockEnabled, isFalse);
      expect(provider.errorMessage, contains('cancelled or failed'));
      expect(await settingsRepo.isAppLockEnabled(), isFalse);
    });

    testWidgets('enableAppLock succeeds when authenticated and persists state', (tester) async {
      fakeService.isSecure = true;
      fakeService.authResult = true; // Auth succeeds
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await provider.enableAppLock(context);
                },
                child: const Text('Enable'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(provider.isAppLockEnabled, isTrue);
      expect(provider.isLocked, isFalse);
      expect(provider.errorMessage, isNull);
      expect(await settingsRepo.isAppLockEnabled(), isTrue);
    });

    testWidgets('disableAppLock requires authentication and does not disable if auth fails', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = false; // User cancels auth to disable
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await provider.disableAppLock(context);
                },
                child: const Text('Disable'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();

      expect(provider.isAppLockEnabled, isTrue); // Remains enabled
      expect(provider.errorMessage, contains('Authentication failed'));
      expect(await settingsRepo.isAppLockEnabled(), isTrue);
    });

    testWidgets('disableAppLock disables App Lock on successful authentication', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = true; // User successfully authenticates
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await provider.disableAppLock(context);
                },
                child: const Text('Disable'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();

      expect(provider.isAppLockEnabled, isFalse);
      expect(provider.isLocked, isFalse);
      expect(provider.errorMessage, isNull);
      expect(await settingsRepo.isAppLockEnabled(), isFalse);
    });

    test('unlockApp unlocks app on successful authentication', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = true;
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      expect(provider.isLocked, isTrue);

      final result = await provider.unlockApp();

      expect(result, isTrue);
      expect(provider.isLocked, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('unlockApp remains locked on authentication failure', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = false;
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      expect(provider.isLocked, isTrue);

      final result = await provider.unlockApp();

      expect(result, isFalse);
      expect(provider.isLocked, isTrue);
      expect(provider.errorMessage, contains('Authentication required'));
    });

    test('lockApp manually locks app immediately when enabled', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

      fakeService.authResult = true;
      await provider.unlockApp();
      expect(provider.isLocked, isFalse);

      provider.lockApp();
      expect(provider.isLocked, isTrue);
    });

    test('Lifecycle changes: backgrounding (paused/hidden) does NOT lock the app (locks only on launch/relaunch)', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      fakeService.authResult = true;
      await provider.unlockApp();
      expect(provider.isLocked, isFalse);

      // App backgrounded (paused): should NOT lock the app
      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(provider.isLocked, isFalse);
      expect(provider.backgroundedAt, isNotNull);

      // App resumed: should remain unlocked without prompting auth
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(provider.isLocked, isFalse);
      expect(provider.backgroundedAt, isNull);

      // App hidden in task switcher: should NOT lock the app
      provider.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(provider.isLocked, isFalse);
    });

    test('Lifecycle changes: backgrounding does nothing when App Lock is disabled', () async {
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      expect(provider.isAppLockEnabled, isFalse);
      expect(provider.isLocked, isFalse);

      provider.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(provider.isLocked, isFalse);
    });
  });

  group('AppLockGate & AppLockScreen Widget Tests', () {
    late FakeAppLockService fakeService;
    late SettingsRepository settingsRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeService = FakeAppLockService();
      settingsRepo = SettingsRepository();
    });

    testWidgets('AppLockGate blocks sensitive child view when locked', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = false; // Prevents auto-unlock in post frame callback
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      expect(provider.isLocked, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: AppLockGate(
              child: Scaffold(
                body: Text('CONFIDENTIAL_BANK_BALANCE_\$50,000'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Confidential child data must NOT exist in the widget tree
      expect(find.text('CONFIDENTIAL_BANK_BALANCE_\$50,000'), findsNothing);

      // AppLockScreen must be displayed
      expect(find.text('Royal Spend'), findsOneWidget);
      expect(find.text('App Locked'), findsOneWidget);
      expect(find.text('Unlock Royal Spend'), findsOneWidget);
    });

    testWidgets('AppLockGate renders child view when unlocked', (tester) async {
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();
      expect(provider.isLocked, isFalse);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: AppLockGate(
              child: Scaffold(
                body: Text('CONFIDENTIAL_BANK_BALANCE_\$50,000'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Child data must exist
      expect(find.text('CONFIDENTIAL_BANK_BALANCE_\$50,000'), findsOneWidget);
      // Lock screen must NOT exist
      expect(find.text('App Locked'), findsNothing);
    });

    testWidgets('Tapping Unlock button in AppLockScreen triggers unlock flow', (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAppLockEnabled: true,
      });
      fakeService.authResult = false; // Initially locked
      final provider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await provider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: AppLockGate(
              child: Scaffold(
                body: Text('UNLOCKED_TRANSACTIONS'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unlock Royal Spend'), findsOneWidget);

      // User provides valid biometric / device credential
      fakeService.authResult = true;
      await tester.tap(find.text('Unlock Royal Spend'));
      await tester.pumpAndSettle();

      expect(fakeService.authCallCount, greaterThanOrEqualTo(1));
      expect(provider.isLocked, isFalse);
      expect(find.text('UNLOCKED_TRANSACTIONS'), findsOneWidget);
    });
  });

  group('ProfileSettingsScreen App Lock Settings Integration Tests', () {
    testWidgets('Displays Security section with App Lock toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final fakeService = FakeAppLockService();
      final settingsRepo = SettingsRepository();
      final settings = SettingsProvider(repository: settingsRepo);
      await settings.init();
      final expenseProvider = ExpenseProvider();
      final appLockProvider = AppLockProvider(
        service: fakeService,
        settingsRepo: settingsRepo,
      );
      await appLockProvider.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
            ChangeNotifierProvider.value(value: appLockProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              body: ProfileSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Security section header
      expect(find.text('SECURITY'), findsOneWidget);

      // App Lock tile
      expect(find.text('App Lock'), findsOneWidget);
      expect(find.text("Protect your Royal Spend app using your device's built-in security."), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);

      // Switches should be present
      final switchFinder = find.byType(CupertinoSwitch);
      expect(switchFinder, findsWidgets);

      // Enable App Lock via switch tap
      fakeService.isSecure = true;
      fakeService.authResult = true;

      final appLockSwitch = find.byType(CupertinoSwitch).last;

      await tester.tap(appLockSwitch);
      await tester.pumpAndSettle();

      expect(appLockProvider.isAppLockEnabled, isTrue);
      expect(find.text('Protected'), findsOneWidget);
    });
  });
}
