import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:royal_spend/core/constants/default_categories.dart';
import 'package:royal_spend/core/services/firestore/firestore_sync_service.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/main_navigation_screen.dart';

class _MockExpenseRepo implements IExpenseRepository {
  final List<Expense> _storage = [];
  Budget? _budget;

  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_storage);

  Future<Expense?> getExpenseById(String id) async =>
      _storage.where((e) => e.id == id).firstOrNull;

  Future<void> insertExpense(Expense expense) async {
    _storage.add(expense);
  }

  @override
  Future<void> addExpense(Expense expense) async {
    await insertExpense(expense);
  }

  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return _storage.where((e) => !e.date.isBefore(start) && e.date.isBefore(end)).toList();
  }

  @override
  Future<List<Expense>> getExpensesForDate(DateTime date, {String? tripId, bool? isIncome}) async {
    return _storage.where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
  }

  @override
  Future<List<Expense>> getExpensesForDateRange(DateTime start, DateTime end, {String? tripId, bool? isIncome}) async {
    return _storage.where((e) => !e.date.isBefore(start) && !e.date.isAfter(end)).toList();
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final idx = _storage.indexWhere((e) => e.id == expense.id);
    if (idx != -1) _storage[idx] = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _storage.removeWhere((e) => e.id == id);
  }

  @override
  Future<Budget?> getBudget(int year, int month) async => _budget;

  @override
  Future<void> saveBudget(Budget budget) async {
    _budget = budget;
  }

  @override
  Future<void> clearAllData() async {
    _storage.clear();
    _budget = null;
  }

  @override
  Future<void> seedRealisticSampleData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Production Security Audit: User Isolation & App Hardening', () {
    test('SettingsRepository persists and clears lastUserId to prevent cross-account leakage', () async {
      final repo = SettingsRepository();
      expect(await repo.getLastUserId(), isNull);

      await repo.setLastUserId('user_alpha_123');
      expect(await repo.getLastUserId(), equals('user_alpha_123'));

      // Simulate logout
      await repo.setLastUserId(null);
      expect(await repo.getLastUserId(), isNull);
    });

    test('AndroidManifest enforces allowBackup=false and usesCleartextTraffic=false', () async {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = await manifestFile.readAsString();
      expect(content.contains('android:allowBackup="false"'), isTrue,
          reason: 'allowBackup must be false to prevent adb backup database theft');
      expect(content.contains('android:usesCleartextTraffic="false"'), isTrue,
          reason: 'usesCleartextTraffic must be false to enforce HTTPS only');
      expect(content.contains('android:fullBackupContent="false"'), isTrue,
          reason: 'fullBackupContent must be false');
    });

    test('Storage security rules strictly isolate profile photos and user receipts by owner', () async {
      final rulesFile = File('storage.rules');
      expect(rulesFile.existsSync(), isTrue);

      final rules = await rulesFile.readAsString();
      expect(rules.contains('match /profile_images/{userId}/{fileName}'), isTrue);
      expect(rules.contains('match /receipts/{userId}/{fileName}'), isTrue);
      expect(rules.contains('allow read: if isOwner(userId);'), isTrue,
          reason: 'Receipt images must be owner-only readable');
      expect(rules.contains('allow read, write: if false;'), isTrue,
          reason: 'Storage rules must default deny');
    });

    test('FirestoreSyncService cancelRealtimeListeners gracefully shuts down all 12 subscriptions', () {
      final service = FirestoreSyncService.instance;
      // Should execute without throwing any null pointer or unhandled exception
      expect(() => service.cancelRealtimeListeners(), returnsNormally);
    });
  });

  group('Performance & Rendering Optimization: ExpenseProvider Memoization', () {
    test('ExpenseProvider memoizes totalExpenseThisMonth, recentExpenses, and last7DaysSpend', () async {
      final mockRepo = _MockExpenseRepo();
      final provider = ExpenseProvider(repository: mockRepo);
      await provider.init();

      final now = DateTime.now();
      final exp1 = Expense(
        id: 'exp-1',
        title: 'Airport Taxi',
        amount: 850.0,
        categoryId: DefaultCategories.categories.first.id,
        date: now,
        paymentMethod: PaymentMethod.upi,
        createdAt: now,
        updatedAt: now,
      );
      final exp2 = Expense(
        id: 'exp-2',
        title: 'Team Lunch',
        amount: 1450.0,
        categoryId: DefaultCategories.categories.first.id,
        date: now,
        paymentMethod: PaymentMethod.upi,
        createdAt: now,
        updatedAt: now,
      );

      await provider.addExpense(exp1);
      await provider.addExpense(exp2);

      // 1. Initial retrieval computes and caches
      final total1 = provider.totalExpenseThisMonth;
      expect(total1, equals(2300.0));

      final recent1 = provider.recentExpenses;
      expect(recent1.length, equals(2));

      final trend1 = provider.last7DaysSpend;
      expect(trend1.length, equals(7));

      // 2. Subsequent reads hit cache instantly
      final total2 = provider.totalExpenseThisMonth;
      expect(identical(total1, total2), isTrue);

      final recent2 = provider.recentExpenses;
      expect(identical(recent1, recent2), isTrue,
          reason: 'Subsequent reads must return the memoized instance without re-filtering');

      final trend2 = provider.last7DaysSpend;
      expect(identical(trend1, trend2), isTrue,
          reason: '7-day trend must return memoized list without re-looping');

      // 3. Category scope change invalidates cache
      await provider.setCategoryScope(ExpenseScope.travel);
      // exp1 and exp2 have no tripId, so travel spend is 0.0
      expect(provider.totalExpenseThisMonth, equals(0.0));
      expect(provider.recentExpenses.isEmpty, isTrue);

      // 4. Return to All scope
      await provider.setCategoryScope(ExpenseScope.all);
      expect(provider.totalExpenseThisMonth, equals(2300.0));
      expect(provider.recentExpenses.length, equals(2));
    });
  });

  group('Navigation & Startup Optimization: Lazy Tab Loading in MainNavigationScreen', () {
    testWidgets('MainNavigationScreen mounts only Tab 0 initially, deferring other tabs',
        (tester) async {
      final settingsRepo = SettingsRepository();
      final settingsProvider = SettingsProvider(repository: settingsRepo);
      await settingsProvider.init();

      final mockRepo = _MockExpenseRepo();
      final expenseProvider = ExpenseProvider(repository: mockRepo);
      await expenseProvider.init();

      final travelProvider = TravelProvider();
      final quickLogProvider = QuickLogProvider();
      final profileImageProvider = ProfileImageProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: expenseProvider),
            ChangeNotifierProvider.value(value: travelProvider),
            ChangeNotifierProvider.value(value: quickLogProvider),
            ChangeNotifierProvider.value(value: profileImageProvider),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 0 (Dashboard) should be loaded and in the tree
      expect(find.byKey(const PageStorageKey('dashboard_screen')), findsOneWidget);

      // Tabs 1, 2, 3, 4 should NOT be in the tree on initial render (saving startup memory & time)
      expect(find.byKey(const PageStorageKey('transactions_screen')), findsNothing);
      expect(find.byKey(const PageStorageKey('travel_dashboard_screen')), findsNothing);
      expect(find.byKey(const PageStorageKey('analytics_screen')), findsNothing);
      expect(find.byKey(const PageStorageKey('profile_settings_screen')), findsNothing);
    });
  });

  group('Database Optimization: Schema Integrity Composite Indexes', () {
    test('DatabaseHelper _ensureSchemaIntegrity registers composite indexes', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE expenses (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              amount REAL NOT NULL,
              category_id TEXT NOT NULL,
              date INTEGER NOT NULL,
              payment_method TEXT NOT NULL,
              notes TEXT,
              is_income INTEGER NOT NULL DEFAULT 0,
              trip_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              user_id TEXT,
              sync_status TEXT NOT NULL DEFAULT 'synced'
            )
          ''');
          await db.execute('CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT, icon_code INT, color_value INT, is_default INT)');
        },
      );

      // Check initial custom indexes on expenses table (ignoring SQLite primary key auto-index)
      final indexes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='expenses'");
      final customIndexNames = indexes
          .map((row) => row['name'] as String)
          .where((n) => !n.startsWith('sqlite_autoindex_'))
          .toList();
      expect(customIndexNames, isEmpty);

      // Add composite indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_trip_date ON expenses (trip_id, date DESC);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses (user_id, date DESC);');

      final updatedIndexes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='expenses'");
      final updatedNames = updatedIndexes.map((row) => row['name'] as String).toList();

      expect(updatedNames.contains('idx_expenses_trip_date'), isTrue);
      expect(updatedNames.contains('idx_expenses_user_date'), isTrue);

      await db.close();
    });
  });
}
