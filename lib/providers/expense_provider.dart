import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/firestore/firestore_sync_service.dart';
import '../data/models/budget.dart';
import '../data/models/expense.dart';
import '../data/models/expense_category.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/settings_repository.dart';

enum DateFilterType {
  all,
  thisMonth,
  thisWeek,
  today,
}

enum ExpenseScope {
  personal,
  travel,
  all;

  String get displayName {
    switch (this) {
      case ExpenseScope.personal:
        return 'Personal';
      case ExpenseScope.travel:
        return 'Travel';
      case ExpenseScope.all:
        return 'Mix';
    }
  }

  String get key {
    switch (this) {
      case ExpenseScope.personal:
        return 'personal';
      case ExpenseScope.travel:
        return 'travel';
      case ExpenseScope.all:
        return 'mix';
    }
  }

  static ExpenseScope fromKey(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'personal':
        return ExpenseScope.personal;
      case 'travel':
        return ExpenseScope.travel;
      case 'mix':
      case 'all':
      default:
        return ExpenseScope.all;
    }
  }
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

  ExpenseScope _categoryScope = ExpenseScope.all;
  ExpenseScope get categoryScope => _categoryScope;
  String? _activeUserId;
  String? get activeUserId => _activeUserId;

  // Memoized metric caches for zero-jank 120 FPS UI performance
  List<Expense>? _cachedRecentExpenses;
  double? _cachedTotalExpenseThisMonth;
  double? _cachedTotalIncomeThisMonth;
  Map<ExpenseCategory, double>? _cachedCategorySpendThisMonth;
  List<Map<String, dynamic>>? _cachedLast7DaysSpend;

  void _invalidateCachedMetrics() {
    _cachedRecentExpenses = null;
    _cachedTotalExpenseThisMonth = null;
    _cachedTotalIncomeThisMonth = null;
    _cachedCategorySpendThisMonth = null;
    _cachedLast7DaysSpend = null;
  }

  // Search & Filter state
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedCategoryId;
  String? get selectedCategoryId => _selectedCategoryId;

  DateFilterType _dateFilter = DateFilterType.all;
  DateFilterType get dateFilter => _dateFilter;

  // Initializer
  Future<void> init({String? userId}) async {
    _isLoading = true;
    notifyListeners();

    await loadCategoryPreference(userId: userId);
    await refresh();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategoryPreference({String? userId}) async {
    _activeUserId = userId;
    try {
      final savedKey = await SettingsRepository().getSelectedCategoryScope(userId: userId);
      _categoryScope = ExpenseScope.fromKey(savedKey);
    } catch (_) {
      _categoryScope = ExpenseScope.all;
    }
    notifyListeners();

    if (userId != null && userId.isNotEmpty) {
      try {
        final cloudKey = await FirestoreSyncService.instance.getUserCategoryPreference(userId);
        if (cloudKey != null && cloudKey.isNotEmpty) {
          final cloudScope = ExpenseScope.fromKey(cloudKey);
          if (cloudScope != _categoryScope) {
            _categoryScope = cloudScope;
            await SettingsRepository().setSelectedCategoryScope(cloudScope.key, userId: userId);
            notifyListeners();
          }
        } else {
          await FirestoreSyncService.instance.saveUserCategoryPreference(userId, ExpenseScope.all.key);
        }
      } catch (_) {}
    }
  }

  Future<void> setCategoryScope(ExpenseScope scope, {String? userId}) async {
    final effectiveUid = userId ?? _activeUserId;
    if (_categoryScope == scope && _activeUserId == effectiveUid) return;
    _categoryScope = scope;
    _invalidateCachedMetrics();
    notifyListeners();

    await SettingsRepository().setSelectedCategoryScope(scope.key, userId: effectiveUid);
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      unawaited(FirestoreSyncService.instance.saveUserCategoryPreference(effectiveUid, scope.key).catchError((_) {}));
    }
  }

  bool _isRefreshing = false;

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final now = DateTime.now();
      _allExpenses = await _repository.getAllExpenses();
      _currentBudget = await _repository.getBudget(now.year, now.month);
      _invalidateCachedMetrics();
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
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

      // Category Scope Filter: Personal | Travel | Mix
      if (_categoryScope == ExpenseScope.personal) {
        if (expense.tripId != null && expense.tripId!.isNotEmpty) return false;
      } else if (_categoryScope == ExpenseScope.travel) {
        if (expense.tripId == null || expense.tripId!.isEmpty) return false;
      }

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
    if (_cachedRecentExpenses != null) return _cachedRecentExpenses!;
    _cachedRecentExpenses = _allExpenses.where((e) {
      if (e.isIncome) return false;
      if (_categoryScope == ExpenseScope.personal) {
        return e.tripId == null || e.tripId!.isEmpty;
      } else if (_categoryScope == ExpenseScope.travel) {
        return e.tripId != null && e.tripId!.isNotEmpty;
      }
      return true;
    }).take(8).toList();
    return _cachedRecentExpenses!;
  }

  // --- Financial Calculations ---

  double get monthlyLimit => _currentBudget?.monthlyLimit ?? 35000.0;

  double get totalExpenseThisMonth {
    if (_cachedTotalExpenseThisMonth != null) return _cachedTotalExpenseThisMonth!;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    _cachedTotalExpenseThisMonth = _allExpenses
        .where((e) {
          if (e.isIncome) return false;
          if (!e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) ||
              !e.date.isBefore(nextMonthStart)) {
            return false;
          }
          if (_categoryScope == ExpenseScope.personal) {
            return e.tripId == null || e.tripId!.isEmpty;
          } else if (_categoryScope == ExpenseScope.travel) {
            return e.tripId != null && e.tripId!.isNotEmpty;
          }
          return true;
        })
        .fold<double>(0.0, (sum, item) => sum + item.amount);
    return _cachedTotalExpenseThisMonth!;
  }

  double get totalIncomeThisMonth {
    if (_cachedTotalIncomeThisMonth != null) return _cachedTotalIncomeThisMonth!;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    _cachedTotalIncomeThisMonth = _allExpenses
        .where((e) {
          if (!e.isIncome) return false;
          if (!e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) ||
              !e.date.isBefore(nextMonthStart)) {
            return false;
          }
          if (_categoryScope == ExpenseScope.personal) {
            return e.tripId == null || e.tripId!.isEmpty;
          } else if (_categoryScope == ExpenseScope.travel) {
            return e.tripId != null && e.tripId!.isNotEmpty;
          }
          return true;
        })
        .fold<double>(0.0, (sum, item) => sum + item.amount);
    return _cachedTotalIncomeThisMonth!;
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
    if (_cachedCategorySpendThisMonth != null) return _cachedCategorySpendThisMonth!;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final monthExpenses = _allExpenses.where((e) {
      if (e.isIncome) return false;
      if (!e.date.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) ||
          !e.date.isBefore(nextMonthStart)) {
        return false;
      }
      if (_categoryScope == ExpenseScope.personal) {
        return e.tripId == null || e.tripId!.isEmpty;
      } else if (_categoryScope == ExpenseScope.travel) {
        return e.tripId != null && e.tripId!.isNotEmpty;
      }
      return true;
    });

    final Map<ExpenseCategory, double> map = {};
    for (final exp in monthExpenses) {
      final cat = exp.category;
      map[cat] = (map[cat] ?? 0.0) + exp.amount;
    }

    // Sort descending by spend
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _cachedCategorySpendThisMonth = Map.fromEntries(sortedEntries);
    return _cachedCategorySpendThisMonth!;
  }

  // --- Month & Scope Analytics Helpers ---

  List<Expense> getExpensesForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    final monthStart = DateTime(year, month, 1);
    final nextMonthStart = DateTime(year, month + 1, 1);

    return _allExpenses.where((e) {
      if (e.date.isBefore(monthStart) || !e.date.isBefore(nextMonthStart)) {
        return false;
      }
      if (scope == ExpenseScope.personal) {
        return e.tripId == null || e.tripId!.isEmpty;
      } else if (scope == ExpenseScope.travel) {
        return e.tripId != null && e.tripId!.isNotEmpty;
      }
      return true;
    }).toList();
  }

  double getTotalExpenseForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForMonth(year, month, scope: scope)
        .where((e) => !e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double getTotalIncomeForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForMonth(year, month, scope: scope)
        .where((e) => e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<ExpenseCategory, double> getCategorySpendForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    final monthExpenses = getExpensesForMonth(year, month, scope: scope)
        .where((e) => !e.isIncome);

    final Map<ExpenseCategory, double> map = {};
    for (final exp in monthExpenses) {
      final cat = exp.category;
      map[cat] = (map[cat] ?? 0.0) + exp.amount;
    }

    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  bool hasDataForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForMonth(year, month, scope: scope).any((e) => !e.isIncome);
  }

  // --- Date & Daily Analytics Helpers ---

  List<Expense> getExpensesForDate(DateTime date, {ExpenseScope scope = ExpenseScope.all}) {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return _allExpenses.where((e) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) {
        return false;
      }
      if (scope == ExpenseScope.personal) {
        return e.tripId == null || e.tripId!.isEmpty;
      } else if (scope == ExpenseScope.travel) {
        return e.tripId != null && e.tripId!.isNotEmpty;
      }
      return true;
    }).toList();
  }

  double getTotalExpenseForDate(DateTime date, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForDate(date, scope: scope)
        .where((e) => !e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double getTotalIncomeForDate(DateTime date, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForDate(date, scope: scope)
        .where((e) => e.isIncome)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<ExpenseCategory, double> getCategorySpendForDate(DateTime date, {ExpenseScope scope = ExpenseScope.all}) {
    final dayExpenses = getExpensesForDate(date, scope: scope).where((e) => !e.isIncome);
    final Map<ExpenseCategory, double> map = {};
    for (final exp in dayExpenses) {
      final cat = exp.category;
      map[cat] = (map[cat] ?? 0.0) + exp.amount;
    }
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  bool hasDataForDate(DateTime date, {ExpenseScope scope = ExpenseScope.all}) {
    return getExpensesForDate(date, scope: scope).any((e) => !e.isIncome);
  }

  List<int> getActiveExpenseDaysForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    final expenses = getExpensesForMonth(year, month, scope: scope).where((e) => !e.isIncome);
    final Set<int> daySet = {};
    for (final e in expenses) {
      daySet.add(e.date.day);
    }
    final list = daySet.toList()..sort();
    return list;
  }

  Map<int, double> getDailySpendMapForMonth(int year, int month, {ExpenseScope scope = ExpenseScope.all}) {
    final expenses = getExpensesForMonth(year, month, scope: scope).where((e) => !e.isIncome);
    final Map<int, double> map = {};
    for (final e in expenses) {
      map[e.date.day] = (map[e.date.day] ?? 0.0) + e.amount;
    }
    return map;
  }

  List<Expense> getTravelExpensesForDate(DateTime date) {
    return getExpensesForDate(date, scope: ExpenseScope.travel);
  }

  // --- Daily Spending Trend (Last 7 Days) ---

  List<Map<String, dynamic>> get last7DaysSpend {
    if (_cachedLast7DaysSpend != null) return _cachedLast7DaysSpend!;
    final now = DateTime.now();
    final List<Map<String, dynamic>> days = [];

    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final total = _allExpenses
          .where((e) {
            if (e.isIncome) return false;
            if (!e.date.isAfter(start.subtract(const Duration(milliseconds: 1))) ||
                !e.date.isBefore(end.add(const Duration(milliseconds: 1)))) {
              return false;
            }
            if (_categoryScope == ExpenseScope.personal) {
              return e.tripId == null || e.tripId!.isEmpty;
            } else if (_categoryScope == ExpenseScope.travel) {
              return e.tripId != null && e.tripId!.isNotEmpty;
            }
            return true;
          })
          .fold(0.0, (sum, item) => sum + item.amount);

      days.add({
        'date': targetDate,
        'weekday': _getWeekdayShort(targetDate.weekday),
        'amount': total,
      });
    }

    _cachedLast7DaysSpend = days;
    return _cachedLast7DaysSpend!;
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

  void clearAllDataInMemory() {
    _allExpenses.clear();
    _currentBudget = null;
    _invalidateCachedMetrics();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _isLoading = true;
    notifyListeners();

    await _repository.clearAllData();
    _allExpenses.clear();
    _currentBudget = null;
    _invalidateCachedMetrics();

    _isLoading = false;
    notifyListeners();
  }
}
