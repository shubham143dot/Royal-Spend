import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/auth/login_screen.dart';
import 'package:royal_spend/ui/screens/auth_gate.dart';
import 'package:royal_spend/ui/screens/intro/intro_screen.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';
import 'package:royal_spend/ui/widgets/sync_status_badge.dart';

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

class MemorySettingsRepository extends SettingsRepository {
  bool _seenIntro = false;
  bool _auth = false;
  String? _photoUrl;
  String _name = 'Test User';

  @override
  Future<bool> hasCompletedIntro() async => _seenIntro;

  @override
  Future<bool> hasSeenIntro() async => _seenIntro;

  @override
  Future<void> setHasSeenIntro(bool seen) async {
    _seenIntro = seen;
  }

  @override
  Future<void> setHasCompletedIntro(bool completed) async {
    _seenIntro = completed;
  }

  @override
  Future<bool> isAuthenticated() async => _auth;

  @override
  Future<void> setIsAuthenticated(bool authenticated) async {
    _auth = authenticated;
  }

  @override
  Future<String?> getUserProfilePhoto() async => _photoUrl;

  @override
  Future<void> setUserProfilePhoto(String? photoUrl) async {
    _photoUrl = photoUrl;
  }

  @override
  Future<String> getUserName() async => _name;

  @override
  Future<void> setUserName(String name) async {
    _name = name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  Widget createTestApp({
    required Widget child,
    required SettingsProvider settings,
    ExpenseProvider? expenseProvider,
    TravelProvider? travelProvider,
  }) {
    final expProv = expenseProvider ?? ExpenseProvider();
    final qkProv = QuickLogProvider();
    final trvProv = travelProvider ?? TravelProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<ExpenseProvider>.value(value: expProv),
        ChangeNotifierProvider<QuickLogProvider>.value(value: qkProv),
        ChangeNotifierProvider<TravelProvider>.value(value: trvProv),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Phase 1: Installation-Level Intro Video Logic Tests', () {
    test('fresh installation starts with hasSeenIntro false', () async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      expect(provider.hasSeenIntro, isFalse);
      expect(provider.hasCompletedIntro, isFalse);
    });

    test('setting hasSeenIntro persists and survives logout', () async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      await provider.setHasSeenIntro(true);
      await provider.setIsAuthenticated(true);
      expect(provider.hasSeenIntro, isTrue);
      expect(provider.isAuthenticated, isTrue);

      // Existing Firebase user logs out
      await provider.logout();

      // hasSeenIntro MUST remain true!
      expect(provider.hasSeenIntro, isTrue);
      expect(provider.isAuthenticated, isFalse);
    });

    test('profile photo url persistence works locally', () async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      expect(provider.profilePhotoUrl, isNull);
      await provider.setProfilePhotoUrl('https://example.com/avatar.jpg');
      expect(provider.profilePhotoUrl, 'https://example.com/avatar.jpg');
    });
  });

  group('Phase 7: Centralized AuthGate Navigation Routing Tests', () {
    testWidgets('fresh install routes directly to IntroScreen', (tester) async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      await tester.pumpWidget(
        createTestApp(child: const AuthGate(), settings: provider),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(IntroScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainNavigationScreen), findsNothing);
    });

    testWidgets('existing install (intro seen, logged out) routes to LoginScreen', (
      tester,
    ) async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();
      await provider.setHasSeenIntro(true);
      await provider.setIsAuthenticated(false);

      await tester.pumpWidget(
        createTestApp(child: const AuthGate(), settings: provider),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Must be on LoginScreen, NEVER IntroScreen!
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(IntroScreen), findsNothing);
    });

    testWidgets('authenticated user routes directly to MainNavigationScreen', (
      tester,
    ) async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();
      await provider.setHasSeenIntro(true);
      await provider.setIsAuthenticated(true);

      await tester.pumpWidget(
        createTestApp(child: const AuthGate(), settings: provider),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MainNavigationScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(IntroScreen), findsNothing);
    });
  });

  group('Phase 6: SyncStatusBadge UI & State Tests', () {
    testWidgets('SyncStatusBadge renders Connected when online', (tester) async {
      FirestoreSyncService.instance.syncStatus.value = SyncStatus.online;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: SyncStatusBadge(isDark: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    });

    testWidgets('SyncStatusBadge renders Working Locally when offline', (
      tester,
    ) async {
      FirestoreSyncService.instance.syncStatus.value = SyncStatus.offline;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: SyncStatusBadge(isDark: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Working Locally'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('SyncStatusBadge renders Syncing when sync in progress', (
      tester,
    ) async {
      FirestoreSyncService.instance.syncStatus.value = SyncStatus.syncing;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: SyncStatusBadge(isDark: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Syncing…'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_2_circlepath), findsOneWidget);
    });

    testWidgets('compact SyncStatusBadge renders icon cleanly', (tester) async {
      FirestoreSyncService.instance.syncStatus.value = SyncStatus.online;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: SyncStatusBadge(isDark: true, compact: true)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      // Compact mode hides the text label
      expect(find.text('Connected'), findsNothing);
    });
  });

  group('Phase 4: Profile Redesign & User Avatar Tests', () {
    testWidgets('renders ProfileSettingsScreen with avatar, camera badge, and account tiles', (
      tester,
    ) async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: ProfileSettingsScreen()),
          settings: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Settings title & Profile section exist
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.camera_fill), findsOneWidget);
      expect(find.text('ACCOUNT & AUTHENTICATION'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('tapping Profile Card opens modal action sheet with photo & name options', (
      tester,
    ) async {
      final repo = MemorySettingsRepository();
      final provider = SettingsProvider(repository: repo);
      await provider.init();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: ProfileSettingsScreen()),
          settings: provider,
        ),
      );
      await tester.pumpAndSettle();

      // Tap profile card
      await tester.tap(find.text('Test User'));
      await tester.pumpAndSettle();

      // Modal options sheet appears
      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('Edit Display Name'), findsOneWidget);
      expect(find.text('Choose Photo from Gallery'), findsOneWidget);
      expect(find.text('Take Photo with Camera'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Phase 3 & 5: Database & Sync Service Architecture Tests', () {
    test('pullCloudData and pushLocalData handle unconfigured environment safely', () async {
      final syncService = FirestoreSyncService();

      // In tests where Firebase is not initialized, sync service gracefully returns 0 without crashing
      final pulled = await syncService.pullCloudData('mock_uid');
      expect(pulled, 0);

      final pushed = await syncService.pushLocalData('mock_uid');
      expect(pushed, 0);
    });

    test('syncAll updates syncStatus cleanly', () async {
      final syncService = FirestoreSyncService();
      expect(syncService.syncStatus.value, SyncStatus.online);

      await syncService.syncAll('mock_uid');
      expect(syncService.syncStatus.value, SyncStatus.synced);
    });
  });
}
