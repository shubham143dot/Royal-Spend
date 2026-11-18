import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Admin Email Validation Logic', () {
    test('AppConstants.isAdmin correctly validates subhamsoudeep@gmail.com', () {
      expect(AppConstants.adminEmail, 'subhamsoudeep@gmail.com');
      expect(AppConstants.isAdmin('subhamsoudeep@gmail.com'), isTrue);
      expect(AppConstants.isAdmin('SubhamSoudeep@gmail.com'), isTrue);
      expect(AppConstants.isAdmin('  subhamsoudeep@gmail.com  '), isTrue);
      expect(AppConstants.isAdmin('SUBHAMSOUDEEP@GMAIL.COM'), isTrue);

      expect(AppConstants.isAdmin('other@gmail.com'), isFalse);
      expect(AppConstants.isAdmin('subham@gmail.com'), isFalse);
      expect(AppConstants.isAdmin('admin@royalspend.com'), isFalse);
      expect(AppConstants.isAdmin(''), isFalse);
      expect(AppConstants.isAdmin(null), isFalse);
    });

    test('SettingsProvider updates and persists userEmail and isAdmin', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository();
      final settings = SettingsProvider(repository: repo);
      await settings.init();

      expect(settings.userEmail, isNull);
      expect(settings.isAdmin, isFalse);

      await settings.setUserEmail('subhamsoudeep@gmail.com');
      expect(settings.userEmail, 'subhamsoudeep@gmail.com');
      expect(settings.isAdmin, isTrue);

      await settings.setUserEmail('user@gmail.com');
      expect(settings.userEmail, 'user@gmail.com');
      expect(settings.isAdmin, isFalse);

      await settings.setUserEmail(null);
      expect(settings.userEmail, isNull);
      expect(settings.isAdmin, isFalse);
    });
  });

  group('ProfileSettingsScreen Admin Gate UI Tests', () {
    Widget buildSettingsWidget({
      required SettingsProvider settings,
      required ExpenseProvider expenseProvider,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: ProfileSettingsScreen(),
          ),
        ),
      );
    }

    testWidgets('Non-admin user does NOT see Admin Tools or Export Transactions', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_email': 'regular_user@example.com',
      });
      final repo = SettingsRepository();
      final settings = SettingsProvider(repository: repo);
      await settings.init();
      final expenseProvider = ExpenseProvider();

      await tester.pumpWidget(buildSettingsWidget(
        settings: settings,
        expenseProvider: expenseProvider,
      ));
      await tester.pumpAndSettle();

      // Export Transactions must never be shown
      expect(find.text('Export Transactions'), findsNothing);

      // Admin tools must NOT be shown for regular users
      expect(find.text('ADMIN TOOLS'), findsNothing);
      expect(find.text('Load Realistic Sample Data'), findsNothing);
      expect(find.text('Replay Intro & Brand Video'), findsNothing);
      expect(find.text('Clear All Expenses'), findsNothing);
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('Admin user subhamsoudeep@gmail.com sees ADMIN TOOLS and admin options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'user_email': 'subhamsoudeep@gmail.com',
      });
      final repo = SettingsRepository();
      final settings = SettingsProvider(repository: repo);
      await settings.init();
      final expenseProvider = ExpenseProvider();

      await tester.pumpWidget(buildSettingsWidget(
        settings: settings,
        expenseProvider: expenseProvider,
      ));
      await tester.pumpAndSettle();

      // Export Transactions must never be shown anywhere
      expect(find.text('Export Transactions'), findsNothing);

      // Admin tools MUST be visible
      expect(find.text('ADMIN TOOLS'), findsOneWidget);
      expect(find.text('subhamsoudeep@gmail.com'), findsAtLeastNWidgets(1));
      expect(find.text('Load Realistic Sample Data'), findsOneWidget);
      expect(find.text('Replay Intro & Brand Video'), findsOneWidget);
      expect(find.text('Clear All Expenses'), findsOneWidget);
      expect(find.text('Admin'), findsAtLeastNWidgets(1));
    });
  });
}
