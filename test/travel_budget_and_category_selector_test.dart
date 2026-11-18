import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/core/constants/app_constants.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/models/trip.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockExpenseRepository extends IExpenseRepository {
  final List<Expense> _storage;
  Budget? _budget;

  MockExpenseRepository([List<Expense>? initial])
      : _storage = initial != null ? List.from(initial) : [];

  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_storage);

  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    return _storage
        .where((e) => e.date.year == year && e.date.month == month)
        .toList();
  }

  @override
  Future<void> addExpense(Expense expense) async {
    _storage.add(expense);
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
  Future<void> seedRealisticSampleData() async {}

  @override
  Future<void> clearAllData() async {
    _storage.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Travel Budget in Trip Budget Section Tests', () {
    test('Calculates remaining budget and utilization percentage accurately', () {
      const double totalTravelBudget = 15000.0;
      const double totalTravelExpenses = 6000.0;

      final double remainingBudget = totalTravelBudget - totalTravelExpenses;
      final double budgetUtilization = (totalTravelExpenses / totalTravelBudget) * 100;

      expect(remainingBudget, equals(9000.0));
      expect(budgetUtilization, equals(40.0));
    });

    test('Warning triggers: approaching (>=80%) and exceeded (>=100%)', () {
      const double totalBudget = 10000.0;

      // Case 1: Under 80%
      double spent = 5000.0;
      double progress = spent / totalBudget;
      bool isApproaching = progress >= 0.8 && progress < 1.0;
      bool isExceeded = progress >= 1.0;
      expect(isApproaching, isFalse);
      expect(isExceeded, isFalse);

      // Case 2: 80% to 99% (Approaching)
      spent = 8500.0;
      progress = spent / totalBudget;
      isApproaching = progress >= 0.8 && progress < 1.0;
      isExceeded = progress >= 1.0;
      expect(isApproaching, isTrue);
      expect(isExceeded, isFalse);

      // Case 3: 100%+ (Exceeded)
      spent = 11200.0;
      progress = spent / totalBudget;
      isApproaching = progress >= 0.8 && progress < 1.0;
      isExceeded = progress >= 1.0;
      expect(isApproaching, isFalse);
      expect(isExceeded, isTrue);
    });

    test('Each trip maintains independent budget and expenses (zero cross-trip contamination)', () {
      final tripA = Trip(
        id: 'trip_ladakh',
        title: 'Ladakh Roadtrip',
        destination: 'Leh Ladakh',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 10),
        budget: 40000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tripB = Trip(
        id: 'trip_goa',
        title: 'Goa Weekend',
        destination: 'Goa',
        startDate: DateTime(2026, 8, 15),
        endDate: DateTime(2026, 8, 18),
        budget: 15000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expenses = [
        Expense(
          id: 'exp_1',
          title: 'Ladakh Bike Fuel',
          amount: 5000.0,
          date: DateTime(2026, 6, 2),
          categoryId: 'fuel',
          tripId: 'trip_ladakh',
        ),
        Expense(
          id: 'exp_2',
          title: 'Ladakh Homestay',
          amount: 12000.0,
          date: DateTime(2026, 6, 3),
          categoryId: 'hotel',
          tripId: 'trip_ladakh',
        ),
        Expense(
          id: 'exp_3',
          title: 'Goa Resort',
          amount: 14000.0,
          date: DateTime(2026, 8, 15),
          categoryId: 'hotel',
          tripId: 'trip_goa',
        ),
      ];

      // Dynamic calculation for Trip A
      final expensesA = expenses.where((e) => e.tripId == tripA.id && !e.isIncome).toList();
      final spentA = expensesA.fold(0.0, (sum, e) => sum + e.amount);
      final remainingA = tripA.budget - spentA;
      final utilizationA = (spentA / tripA.budget) * 100;

      // Dynamic calculation for Trip B
      final expensesB = expenses.where((e) => e.tripId == tripB.id && !e.isIncome).toList();
      final spentB = expensesB.fold(0.0, (sum, e) => sum + e.amount);
      final remainingB = tripB.budget - spentB;
      final utilizationB = (spentB / tripB.budget) * 100;

      expect(spentA, equals(17000.0));
      expect(remainingA, equals(23000.0));
      expect(utilizationA, equals(42.5));

      expect(spentB, equals(14000.0));
      expect(remainingB, equals(1000.0));
      expect(utilizationB, closeTo(93.33, 0.01));
      expect(utilizationB >= 80.0 && utilizationB < 100.0, isTrue); // Trip B is approaching warning!
    });
  });

  group('2. Expense & History Category Selector Tests', () {
    late MockExpenseRepository mockRepo;
    late ExpenseProvider expenseProvider;

    final now = DateTime.now();
    final personalExpense1 = Expense(
      id: 'p_1',
      title: 'Groceries',
      amount: 1200.0,
      date: DateTime(now.year, now.month, 2),
      categoryId: 'groceries',
      tripId: null, // Personal expense
    );

    final personalExpense2 = Expense(
      id: 'p_2',
      title: 'Coffee & Snacks',
      amount: 350.0,
      date: DateTime(now.year, now.month, 4),
      categoryId: 'food',
      tripId: null, // Personal expense
    );

    final travelExpense1 = Expense(
      id: 't_1',
      title: 'Flight Tickets',
      amount: 6500.0,
      date: DateTime(now.year, now.month, 5),
      categoryId: 'flight',
      tripId: 'trip_manali', // Travel expense
    );

    final travelExpense2 = Expense(
      id: 't_2',
      title: 'Mountain Resort',
      amount: 4000.0,
      date: DateTime(now.year, now.month, 6),
      categoryId: 'hotel',
      tripId: 'trip_manali', // Travel expense
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockExpenseRepository([
        personalExpense1,
        personalExpense2,
        travelExpense1,
        travelExpense2,
      ]);
      expenseProvider = ExpenseProvider(repository: mockRepo);
      await expenseProvider.init();
    });

    test('Default category scope is Mix (all)', () {
      expect(expenseProvider.categoryScope, equals(ExpenseScope.all));
      expect(expenseProvider.categoryScope.displayName, equals('Mix'));
      expect(expenseProvider.categoryScope.key, equals('mix'));
    });

    test('Option 3: Mix mode displays all personal and travel transactions combined', () {
      expect(expenseProvider.categoryScope, equals(ExpenseScope.all));

      final filtered = expenseProvider.filteredExpenses;
      expect(filtered.length, equals(4));

      final totalSpent = expenseProvider.totalExpenseThisMonth;
      expect(totalSpent, equals(1200.0 + 350.0 + 6500.0 + 4000.0)); // 12050.0
    });

    test('Option 1: Personal mode displays ONLY personal expenses and excludes travel', () async {
      await expenseProvider.setCategoryScope(ExpenseScope.personal);
      expect(expenseProvider.categoryScope, equals(ExpenseScope.personal));

      final filtered = expenseProvider.filteredExpenses;
      expect(filtered.length, equals(2));
      expect(filtered.every((e) => e.tripId == null || e.tripId!.isEmpty), isTrue);
      expect(filtered.any((e) => e.title == 'Flight Tickets'), isFalse);
      expect(filtered.any((e) => e.title == 'Mountain Resort'), isFalse);

      final totalSpent = expenseProvider.totalExpenseThisMonth;
      expect(totalSpent, equals(1200.0 + 350.0)); // 1550.0
    });

    test('Option 2: Travel mode displays ONLY travel expenses and excludes personal', () async {
      await expenseProvider.setCategoryScope(ExpenseScope.travel);
      expect(expenseProvider.categoryScope, equals(ExpenseScope.travel));

      final filtered = expenseProvider.filteredExpenses;
      expect(filtered.length, equals(2));
      expect(filtered.every((e) => e.tripId != null && e.tripId!.isNotEmpty), isTrue);
      expect(filtered.any((e) => e.title == 'Groceries'), isFalse);
      expect(filtered.any((e) => e.title == 'Coffee & Snacks'), isFalse);

      final totalSpent = expenseProvider.totalExpenseThisMonth;
      expect(totalSpent, equals(6500.0 + 4000.0)); // 10500.0
    });

    test('Switching category scope updates totals and analytics instantly', () async {
      // 1. Start in Mix
      expect(expenseProvider.totalExpenseThisMonth, equals(12050.0));

      // 2. Switch to Personal
      await expenseProvider.setCategoryScope(ExpenseScope.personal);
      expect(expenseProvider.totalExpenseThisMonth, equals(1550.0));

      // 3. Switch to Travel
      await expenseProvider.setCategoryScope(ExpenseScope.travel);
      expect(expenseProvider.totalExpenseThisMonth, equals(10500.0));

      // 4. Switch back to Mix
      await expenseProvider.setCategoryScope(ExpenseScope.all);
      expect(expenseProvider.totalExpenseThisMonth, equals(12050.0));
    });

    test('User preference persistence and strict multi-account isolation', () async {
      final settingsRepo = SettingsRepository();

      // User A selects 'personal'
      await settingsRepo.setSelectedCategoryScope('personal', userId: 'user_alice');

      // User B selects 'travel'
      await settingsRepo.setSelectedCategoryScope('travel', userId: 'user_bob');

      // Unauthenticated default
      final defaultScope = await settingsRepo.getSelectedCategoryScope();
      expect(defaultScope, equals(AppConstants.defaultCategoryScope)); // 'mix'

      // Verify User A and User B preferences remain completely isolated
      final aliceScope = await settingsRepo.getSelectedCategoryScope(userId: 'user_alice');
      final bobScope = await settingsRepo.getSelectedCategoryScope(userId: 'user_bob');

      expect(aliceScope, equals('personal'));
      expect(bobScope, equals('travel'));

      // Loading preferences into ExpenseProvider
      await expenseProvider.loadCategoryPreference(userId: 'user_alice');
      expect(expenseProvider.categoryScope, equals(ExpenseScope.personal));

      await expenseProvider.loadCategoryPreference(userId: 'user_bob');
      expect(expenseProvider.categoryScope, equals(ExpenseScope.travel));
    });
  });
}
