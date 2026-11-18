import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/analytics_screen.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';

class _FakeExpenseRepo extends IExpenseRepository {
  final List<Expense> expenses = [];

  @override
  Future<void> addExpense(Expense expense) async => expenses.add(expense);
  @override
  Future<void> clearAllData() async => expenses.clear();
  @override
  Future<void> deleteExpense(String id) async =>
      expenses.removeWhere((e) => e.id == id);
  @override
  Future<List<Expense>> getAllExpenses() async => List.from(expenses);
  @override
  Future<Budget?> getBudget(int year, int month) async => null;
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async =>
      expenses.where((e) => e.date.year == year && e.date.month == month).toList();
  @override
  Future<void> saveBudget(Budget budget) async {}
  @override
  Future<void> seedRealisticSampleData() async {}
  @override
  Future<void> updateExpense(Expense expense) async {
    final idx = expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) expenses[idx] = expense;
  }
}

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
  });

  group('Date-Based Analytics & Expense Provider Tests', () {
    late _FakeExpenseRepo repo;
    late ExpenseProvider expenseProvider;

    setUp(() async {
      repo = _FakeExpenseRepo();
      expenseProvider = ExpenseProvider(repository: repo);

      // Seed test expenses on distinct dates
      final now = DateTime(2026, 11, 16);
      await expenseProvider.addExpense(Expense(
        id: 'exp1',
        title: 'Morning Coffee',
        amount: 150.0,
        date: now,
        categoryId: 'food',
        paymentMethod: PaymentMethod.upi,
        isIncome: false,
      ));
      await expenseProvider.addExpense(Expense(
        id: 'exp2',
        title: 'Taxi Ride',
        amount: 350.0,
        date: now,
        categoryId: 'transportation',
        paymentMethod: PaymentMethod.upi,
        isIncome: false,
      ));
      await expenseProvider.addExpense(Expense(
        id: 'exp3',
        title: 'Yesterday Dinner',
        amount: 800.0,
        date: DateTime(2026, 11, 15),
        categoryId: 'food',
        paymentMethod: PaymentMethod.creditCard,
        isIncome: false,
      ));
      await expenseProvider.addExpense(Expense(
        id: 'exp4',
        title: 'Travel Hotel',
        amount: 2500.0,
        date: now,
        categoryId: 'accommodation',
        paymentMethod: PaymentMethod.creditCard,
        tripId: 'trip_101',
        isIncome: false,
      ));
    });

    test('getExpensesForDate filters accurately by exact calendar date', () {
      final now = DateTime(2026, 11, 16);
      final todayExpenses = expenseProvider.getExpensesForDate(now);
      expect(todayExpenses.length, 3);
      expect(todayExpenses.any((e) => e.title == 'Morning Coffee'), isTrue);
      expect(todayExpenses.any((e) => e.title == 'Taxi Ride'), isTrue);
      expect(todayExpenses.any((e) => e.title == 'Travel Hotel'), isTrue);

      final yesterdayExpenses = expenseProvider.getExpensesForDate(DateTime(2026, 11, 15));
      expect(yesterdayExpenses.length, 1);
      expect(yesterdayExpenses.first.title, 'Yesterday Dinner');
    });

    test('getTotalExpenseForDate calculates accurate sum for a specific day', () {
      final now = DateTime(2026, 11, 16);
      // exp1 (150) + exp2 (350) + exp4 (2500) = 3000
      expect(expenseProvider.getTotalExpenseForDate(now), 3000.0);
      expect(expenseProvider.getTotalExpenseForDate(DateTime(2026, 11, 15)), 800.0);
      expect(expenseProvider.getTotalExpenseForDate(DateTime(2026, 11, 14)), 0.0);
    });

    test('hasDataForDate returns true only when expenses or income exist', () {
      expect(expenseProvider.hasDataForDate(DateTime(2026, 11, 16)), isTrue);
      expect(expenseProvider.hasDataForDate(DateTime(2026, 11, 15)), isTrue);
      expect(expenseProvider.hasDataForDate(DateTime(2026, 11, 14)), isFalse);
    });

    test('getDailySpendMapForMonth returns keyed map for daily trend charting', () {
      final map = expenseProvider.getDailySpendMapForMonth(2026, 11);
      expect(map[16], 3000.0);
      expect(map[15], 800.0);
      expect(map[14], isNull);
    });

    test('getTravelExpensesForDate isolates trip-tagged expenses on that day', () {
      final now = DateTime(2026, 11, 16);
      final travelExp = expenseProvider.getTravelExpensesForDate(now);
      expect(travelExp.length, 1);
      expect(travelExp.first.title, 'Travel Hotel');
    });
  });

  group('Centralized Name Management & Active Button UI Tests', () {
    late SettingsProvider settingsProvider;
    late _FakeExpenseRepo fakeExpenseRepo;
    late ExpenseProvider expenseProvider;

    setUp(() async {
      final repo = MemorySettingsRepository();
      settingsProvider = SettingsProvider(repository: repo);
      await settingsProvider.init();

      fakeExpenseRepo = _FakeExpenseRepo();
      expenseProvider = ExpenseProvider(repository: fakeExpenseRepo);
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
          ChangeNotifierProvider<TravelProvider>(create: (_) => TravelProvider()),
          ChangeNotifierProvider<ProfileImageProvider>(create: (_) => ProfileImageProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Active button opens Profile Settings modal with profile actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const ProfileSettingsScreen()));
      await tester.pumpAndSettle();

      // Find the Active button / status tile
      final activeFinder = find.text('Active');
      expect(activeFinder, findsAtLeastNWidgets(1));

      // Tap Active tile
      await tester.tap(activeFinder.first);
      await tester.pumpAndSettle();

      // Verify Profile Settings sheet opens
      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('Edit Display Name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Centralized Name Management allows editing and updating user name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const ProfileSettingsScreen()));
      await tester.pumpAndSettle();

      // Find redesigned Edit button on the side of user name
      final editNameFinder = find.byKey(const ValueKey('edit_name_button'));
      expect(editNameFinder, findsOneWidget);

      await tester.tap(editNameFinder);
      await tester.pumpAndSettle();

      // Dialog opens with CupertinoTextField
      expect(find.text('Update Profile Name'), findsOneWidget);
      final inputFinder = find.byType(CupertinoTextField);
      expect(inputFinder, findsOneWidget);

      // Enter a new name
      await tester.enterText(inputFinder, 'Subham Soudeep');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify name updated in settings provider
      expect(settingsProvider.userName, 'Subham Soudeep');
    });

    testWidgets('Analytics Screen displays Monthly and Daily views seamlessly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestApp(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      // Verify segmented control has Monthly and Daily
      expect(find.text('Monthly'), findsAtLeastNWidgets(1));
      expect(find.text('Daily'), findsAtLeastNWidgets(1));

      // Switch to Daily view
      await tester.tap(find.text('Daily').first);
      await tester.pumpAndSettle();

      // In daily view, date navigation and "DAILY TOTAL SPENT" is visible
      expect(find.text('DAILY TOTAL SPENT'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.calendar_today), findsAtLeastNWidgets(1));
    });
  });
}
