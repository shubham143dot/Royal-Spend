import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/services/network/network_status_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';

class MemorySettingsRepository extends SettingsRepository {
  String _name = 'Test User';
  String? _email = 'member@royalspend.app';

  @override
  Future<String> getUserName() async => _name;

  @override
  Future<void> setUserName(String name) async {
    _name = name;
  }

  @override
  Future<String?> getUserEmail() async => _email;

  @override
  Future<void> setUserEmail(String? email) async {
    _email = email;
  }

  @override
  Future<bool> isAuthenticated() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    // Reset mock status after each test
    NetworkStatusService.instance.setMockOnline(null);
  });

  group('NetworkStatusService Logic Tests', () {
    test('Default status is online (true)', () {
      NetworkStatusService.instance.setMockOnline(null);
      expect(NetworkStatusService.instance.isConnected, isTrue);
      expect(NetworkStatusService.instance.isOnline.value, isTrue);
    });

    test('Toggling mock online / offline updates ValueNotifier synchronously', () {
      NetworkStatusService.instance.setMockOnline(false);
      expect(NetworkStatusService.instance.isConnected, isFalse);
      expect(NetworkStatusService.instance.isOnline.value, isFalse);

      NetworkStatusService.instance.setMockOnline(true);
      expect(NetworkStatusService.instance.isConnected, isTrue);
      expect(NetworkStatusService.instance.isOnline.value, isTrue);
    });
  });

  group('Accounts & Authentication Online vs Offline UI Tests', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      final repo = MemorySettingsRepository();
      settingsProvider = SettingsProvider(repository: repo);
      await settingsProvider.init();
      await settingsProvider.setUserEmail('alex@example.com');
      await settingsProvider.setUserName('Alex Mercer');
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ExpenseProvider>(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider<TravelProvider>(create: (_) => TravelProvider()),
          ChangeNotifierProvider<ProfileImageProvider>(create: (_) => ProfileImageProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Online state displays "Active" in Accounts and Authentication', (tester) async {
      NetworkStatusService.instance.setMockOnline(true);

      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const ProfileSettingsScreen()));
      await tester.pumpAndSettle();

      // Must find "Active" badge
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);

      // Tap to open Profile Settings sheet
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      // Modal reflects Profile Settings
      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Offline state displays "Offline" instead of Active in Accounts and Authentication', (tester) async {
      NetworkStatusService.instance.setMockOnline(false);

      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const ProfileSettingsScreen()));
      await tester.pumpAndSettle();

      // Must find "Offline" badge and NOT "Active"
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Active'), findsNothing);

      // Tap to open Profile Settings sheet
      await tester.tap(find.text('Offline'));
      await tester.pumpAndSettle();

      // Modal reflects Profile Settings
      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Real-time transition from Online to Offline immediately updates UI', (tester) async {
      NetworkStatusService.instance.setMockOnline(true);

      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const ProfileSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);

      // Simulate network disconnection
      NetworkStatusService.instance.setMockOnline(false);
      await tester.pump();
      await tester.pumpAndSettle();

      // UI automatically reflects Offline state without restarting
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Active'), findsNothing);

      // Simulate network reconnected
      NetworkStatusService.instance.setMockOnline(true);
      await tester.pump();
      await tester.pumpAndSettle();

      // UI immediately switches back to Active
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });
  });
}
