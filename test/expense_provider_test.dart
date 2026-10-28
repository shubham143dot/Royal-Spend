import 'package:flutter_test/flutter_test.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';

class MockExpenseRepository implements IExpenseRepository {
  final List<Expense> _storage = [];
  Budget? _budget;

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
  group('ExpenseProvider Financial Calculations & CRUD Tests', () {
    late MockExpenseRepository mockRepo;
    late ExpenseProvider provider;

    setUp(() {
      mockRepo = MockExpenseRepository();
      provider = ExpenseProvider(repository: mockRepo);
    });

    test('Initial state is empty and default budget applies', () {
      expect(provider.filteredExpenses, isEmpty);
      expect(provider.totalExpenseThisMonth, 0.0);
      expect(provider.totalIncomeThisMonth, 0.0);
      expect(provider.monthlyLimit, 35000.0);
      expect(provider.remainingBudget, 35000.0);
      expect(provider.budgetProgress, 0.0);
    });

    test('Adding expenses recalculates monthly totals and budget utilization correctly', () async {
      final now = DateTime.now();

      final exp1 = Expense(
        id: '1',
        title: 'Espresso',
        amount: 250.0,
        categoryId: 'food',
        date: now,
      );

      final exp2 = Expense(
        id: '2',
        title: 'Uber Ride',
        amount: 750.0,
        categoryId: 'transport',
        date: now,
      );

      final income1 = Expense(
        id: '3',
        title: 'Freelance Design',
        amount: 50000.0,
        categoryId: 'salary',
        date: now,
        isIncome: true,
      );

      await provider.addExpense(exp1);
      await provider.addExpense(exp2);
      await provider.addExpense(income1);

      expect(provider.totalExpenseThisMonth, 1000.0);
      expect(provider.totalIncomeThisMonth, 50000.0);
      expect(provider.netBalanceThisMonth, 49000.0);
      expect(provider.remainingBudget, 34000.0);
      expect(provider.budgetProgress, closeTo(1000.0 / 35000.0, 0.001));
    });

    test('Updating an expense modifies the stored item and financial arithmetic', () async {
      final now = DateTime.now();
      final exp = Expense(
        id: 'update-1',
        title: 'Original Title',
        amount: 500.0,
        categoryId: 'shopping',
        date: now,
      );

      await provider.addExpense(exp);
      expect(provider.totalExpenseThisMonth, 500.0);

      final updated = exp.copyWith(
        title: 'Updated Title',
        amount: 1200.0,
      );
      await provider.updateExpense(updated);

      expect(provider.totalExpenseThisMonth, 1200.0);
      expect(provider.filteredExpenses.first.title, 'Updated Title');
    });

    test('Deleting an expense removes it and updates remaining budget', () async {
      final now = DateTime.now();
      final exp = Expense(
        id: 'del-1',
        title: 'Gym membership',
        amount: 2000.0,
        categoryId: 'health',
        date: now,
      );

      await provider.addExpense(exp);
      expect(provider.filteredExpenses.length, 1);

      await provider.deleteExpense('del-1');
      expect(provider.filteredExpenses, isEmpty);
      expect(provider.totalExpenseThisMonth, 0.0);
    });

    test('Search and category filtering filters transactions properly', () async {
      final now = DateTime.now();
      final expFood = Expense(
        id: 'f1',
        title: 'Starbucks Coffee',
        amount: 350.0,
        categoryId: 'food',
        date: now,
      );
      final expTravel = Expense(
        id: 't1',
        title: 'Train ticket to Delhi',
        amount: 1500.0,
        categoryId: 'travel',
        date: now,
      );

      await provider.addExpense(expFood);
      await provider.addExpense(expTravel);

      // Search query 'coffee'
      provider.setSearchQuery('coffee');
      expect(provider.filteredExpenses.length, 1);
      expect(provider.filteredExpenses.first.title, 'Starbucks Coffee');

      // Reset search, filter by category 'travel'
      provider.setSearchQuery('');
      provider.setSelectedCategory('travel');
      expect(provider.filteredExpenses.length, 1);
      expect(provider.filteredExpenses.first.title, 'Train ticket to Delhi');

      // Clear filters
      provider.clearFilters();
      expect(provider.filteredExpenses.length, 2);
      expect(provider.allExpenses.length, 2);
    });

    test('Budget warning and exceeded states trigger accurately', () async {
      final now = DateTime.now();
      await provider.setMonthlyBudget(1000.0);

      expect(provider.isBudgetWarning, false);
      expect(provider.isBudgetExceeded, false);

      // Add expense at 85% of budget (850) -> triggers warning (default threshold is 80%)
      await provider.addExpense(Expense(
        id: 'warn-1',
        title: 'Headphones',
        amount: 850.0,
        categoryId: 'shopping',
        date: now,
      ));

      expect(provider.isBudgetWarning, true);
      expect(provider.isBudgetExceeded, false);

      // Add another expense pushing total to 1100 -> triggers exceeded
      await provider.addExpense(Expense(
        id: 'over-1',
        title: 'Dinner',
        amount: 250.0,
        categoryId: 'food',
        date: now,
      ));

      expect(provider.isBudgetWarning, true);
      expect(provider.isBudgetExceeded, true);
      expect(provider.remainingBudget, -100.0);
    });
  });
}
