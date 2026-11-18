import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/database/database_helper.dart';
import 'package:royal_spend/data/models/expense.dart';
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

  group('Reinstallation & Admin Data Preservation Tests', () {
    testWidgets('Delete Account & Cloud Data feature is completely absent from ProfileSettingsScreen', (tester) async {
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

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ProfileSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Delete Account does NOT appear anywhere in the screen
      expect(find.text('Delete Account & Cloud Data'), findsNothing);
      expect(find.text('Permanently Delete'), findsNothing);
      expect(find.text('Delete Royal Spend Account?'), findsNothing);

      // Verify Log Out is still present and safe
      expect(find.text('Log Out'), findsOneWidget);
    });

    test('FirestoreSyncService.isSampleExpense correctly identifies sample demo records', () {
      final sampleExp1 = Expense(
        id: 'sample-1',
        title: 'Artisan Espresso & Croissant',
        amount: 280.0,
        categoryId: 'food',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
      );
      final sampleExp2 = Expense(
        id: 'sample-2',
        title: 'Uber Premier to Client Office',
        amount: 450.0,
        categoryId: 'transport',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
      );
      final realUserExpense = Expense(
        id: 'real-1',
        title: 'MacBook Pro M3 Max Purchase',
        amount: 250000.0,
        categoryId: 'shopping',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.creditCard,
      );
      final realAdminExpense = Expense(
        id: 'admin-1',
        title: 'Flight Ticket to Zurich & Hotel',
        amount: 85000.0,
        categoryId: 'travel',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.creditCard,
      );

      expect(FirestoreSyncService.isSampleExpense(sampleExp1), isTrue);
      expect(FirestoreSyncService.isSampleExpense(sampleExp2), isTrue);
      expect(FirestoreSyncService.isSampleExpense(realUserExpense), isFalse);
      expect(FirestoreSyncService.isSampleExpense(realAdminExpense), isFalse);
    });

    test('Admin subhamsoudeep@gmail.com is designated administrator with exclusive privileges', () {
      expect(AppConstants.isAdmin('subhamsoudeep@gmail.com'), isTrue);
      expect(AppConstants.isAdmin('SubhamSoudeep@gmail.com'), isTrue);
      expect(AppConstants.isAdmin('other_user@gmail.com'), isFalse);

      expect(AppConstants.isBackToLifeTrip('Back to Life - Swiss Alps Expedition'), isTrue);
      expect(AppConstants.isBackToLifeTrip('Summer Vacation in Bali'), isFalse);
    });

    test('Local SQLite database helper clearAllData completely wipes local tables without wiping cloud', () async {
      final dbHelper = DatabaseHelper.instance;
      // Clear data to start fresh
      await dbHelper.clearAllData();

      final initialExpenses = await dbHelper.getAllExpenses();
      expect(initialExpenses, isEmpty);

      // Insert real user expense
      final testExpense = Expense(
        id: 'preserve-test-1',
        title: 'Genuine Business Lunch',
        amount: 1250.0,
        categoryId: 'food',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
      );
      await dbHelper.insertExpense(testExpense);

      final stored = await dbHelper.getAllExpenses();
      expect(stored.length, 1);
      expect(stored.first.title, 'Genuine Business Lunch');

      // Clear all local data on logout / switch
      await dbHelper.clearAllData();
      final afterLogout = await dbHelper.getAllExpenses();
      expect(afterLogout, isEmpty);
    });
  });
}
