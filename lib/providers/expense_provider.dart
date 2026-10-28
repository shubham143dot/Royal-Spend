import 'package:flutter/foundation.dart';
import '../data/models/budget.dart';
import '../data/models/expense.dart';
import '../data/models/expense_category.dart';
import '../data/repositories/expense_repository.dart';

enum DateFilterType {
  all,
  thisMonth,
  thisWeek,
  today,
}

class ExpenseProvider extends ChangeNotifier {
  final IExpenseRepository _repository;

  ExpenseProvider({IExpenseRepository? repository})
      : _repository = repository ?? ExpenseRepository();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Expense> _allExpenses = [];
  List<Expense> get allExpenses => List.unmodifiable(_allExpenses);
  Budget? _currentBudget;
  Budget? get currentBudget => _currentBudget;

  // Search & Filter state
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedCategoryId;
  String? get selectedCategoryId => _selectedCategoryId;

  DateFilterType _dateFilter = DateFilterType.all;
  DateFilterType get dateFilter => _dateFilter;

  // Initializer
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await refresh();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final now = DateTime.now();
    _allExpenses = await _repository.getAllExpenses();
    _currentBudget = await _repository.getBudget(now.year, now.month);
    notifyListeners();
  }

  // --- Filtered Expense List ---

  List<Expense> get filteredExpenses {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return _allExpenses.where((expense) {
      // Exclusively show expenses
      if (expense.isIncome) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = expense.title.toLowerCase().contains(query);
        final matchesCategory = expense.category.name.toLowerCase().contains(query);
        final matchesNotes = expense.notes?.toLowerCase().contains(query) ?? false;
        final matchesAmount = expense.amount.toString().contains(query);

        if (!matchesTitle && !matchesCategory && !matchesNotes && !matchesAmount) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategoryId != null && expense.categoryId != _selectedCategoryId) {
        return false;
      }

      // Date filter
      switch (_dateFilter) {
        case DateFilterType.today:
          if (expense.date.isBefore(todayStart)) return false;
          break;
        case DateFilterType.thisWeek:
          if (expense.date.isBefore(weekStart)) return false;
          break;
        case DateFilterType.thisMonth:
          if (expense.date.isBefore(monthStart)) return false;
          break;
        case DateFilterType.all:
          break;
      }

      return true;
    }).toList();
  }

  List<Expense> get recentExpenses {
    return _allExpenses.where((e) => !e.isIncome).take(8).toList();
  }

  // --- Financial Calculations ---

  double get monthlyLimit => _currentBudget?.monthlyLimit ?? 35000.0;

  double get totalExpenseThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    return _allExpenses
        .where((e) =>
            !e.isIncome &&
            e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
            e.date.isBefore(nextMonthStart))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalIncomeThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    return _allExpenses
        .where((e) =>
            e.isIncome &&
            e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
            e.date.isBefore(nextMonthStart))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get netBalanceThisMonth => totalIncomeThisMonth - totalExpenseThisMonth;

  double get budgetProgress {
    if (monthlyLimit <= 0) return 0.0;
    return totalExpenseThisMonth / monthlyLimit;
  }

  double get remainingBudget {
    return monthlyLimit - totalExpenseThisMonth;
  }

  bool get isBudgetExceeded => totalExpenseThisMonth > monthlyLimit;
  bool get isBudgetWarning => budgetProgress >= (_currentBudget?.warningThreshold ?? 0.8);

  // --- Category Breakdown ---

  Map<ExpenseCategory, double> get categorySpendThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final monthExpenses = _allExpenses.where((e) =>
        !e.isIncome &&
        e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
        e.date.isBefore(nextMonthStart));

    final Map<ExpenseCategory, double> map = {};
    for (final exp in monthExpenses) {
      final cat = exp.category;
      map[cat] = (map[cat] ?? 0.0) + exp.amount;
    }

    // Sort descending by spend
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  // --- Daily Spending Trend (Last 7 Days) ---

  List<Map<String, dynamic>> get last7DaysSpend {
    final now = DateTime.now();
    final List<Map<String, dynamic>> days = [];

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final total = _allExpenses
          .where((e) =>
              !e.isIncome &&
              e.date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
              e.date.isBefore(end.add(const Duration(milliseconds: 1))))
          .fold(0.0, (sum, item) => sum + item.amount);

      days.add({
        'date': targetDate,
        'weekday': _getWeekdayShort(targetDate.weekday),
        'amount': total,
      });
    }

    return days;
  }

  String _getWeekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  // --- Filter and Search Setters ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setDateFilter(DateFilterType filter) {
    _dateFilter = filter;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _dateFilter = DateFilterType.all;
    notifyListeners();
  }

  // --- CRUD Actions ---

  Future<void> addExpense(Expense expense) async {
    await _repository.addExpense(expense);
    await refresh();
  }

  Future<void> updateExpense(Expense expense) async {
    await _repository.updateExpense(expense);
    await refresh();
  }

  Future<void> deleteExpense(String id) async {
    await _repository.deleteExpense(id);
    await refresh();
  }

  Future<void> setMonthlyBudget(double limit) async {
    final now = DateTime.now();
    final budget = Budget(
      id: '${now.year}-${now.month}',
      monthlyLimit: limit,
      month: now.month,
      year: now.year,
      warningThreshold: 0.8,
    );
    await _repository.saveBudget(budget);
    _currentBudget = budget;
    notifyListeners();
  }

  Future<void> seedRealisticSampleData() async {
    _isLoading = true;
    notifyListeners();

    await _repository.seedRealisticSampleData();
    await refresh();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _isLoading = true;
    notifyListeners();

    await _repository.clearAllData();
    _allExpenses.clear();
    _currentBudget = null;

    _isLoading = false;
    notifyListeners();
  }
}
