import 'dart:async';
import '../../core/services/firestore/firestore_sync_service.dart';
import '../database/database_helper.dart';
import '../models/budget.dart';
import '../models/expense.dart';

abstract class IExpenseRepository {
  Future<List<Expense>> getAllExpenses();
  Future<List<Expense>> getExpensesForMonth(int year, int month);
  Future<List<Expense>> getExpensesForDate(DateTime date, {String? tripId, bool? isIncome}) async {
    final all = await getAllExpenses();
    return all.where((e) {
      final matchesDate = e.date.year == date.year && e.date.month == date.month && e.date.day == date.day;
      if (!matchesDate) return false;
      if (tripId != null && e.tripId != tripId) return false;
      if (isIncome != null && e.isIncome != isIncome) return false;
      return true;
    }).toList();
  }
  Future<List<Expense>> getExpensesForDateRange(DateTime start, DateTime end, {String? tripId, bool? isIncome}) async {
    final all = await getAllExpenses();
    return all.where((e) {
      if (e.date.isBefore(start) || e.date.isAfter(end)) return false;
      if (tripId != null && e.tripId != tripId) return false;
      if (isIncome != null && e.isIncome != isIncome) return false;
      return true;
    }).toList();
  }
  Future<void> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Future<Budget?> getBudget(int year, int month);
  Future<void> saveBudget(Budget budget);
  Future<void> seedRealisticSampleData();
  Future<void> clearAllData();
}

class ExpenseRepository implements IExpenseRepository {
  final DatabaseHelper _dbHelper;
  final FirestoreSyncService _syncService;

  ExpenseRepository({
    DatabaseHelper? dbHelper,
    FirestoreSyncService? syncService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _syncService = syncService ?? FirestoreSyncService.instance;

  @override
  Future<List<Expense>> getAllExpenses() async {
    return await _dbHelper.getAllExpenses();
  }

  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    return await _dbHelper.getExpensesForMonth(year, month);
  }

  @override
  Future<List<Expense>> getExpensesForDate(DateTime date, {String? tripId, bool? isIncome}) async {
    return await _dbHelper.getExpensesForDate(date, tripId: tripId, isIncome: isIncome);
  }

  @override
  Future<List<Expense>> getExpensesForDateRange(DateTime start, DateTime end, {String? tripId, bool? isIncome}) async {
    return await _dbHelper.getExpensesForDateRange(start, end, tripId: tripId, isIncome: isIncome);
  }

  @override
  Future<void> addExpense(Expense expense) async {
    await _dbHelper.unmarkRecordAsDeleted(expense.id);
    await _dbHelper.insertExpense(expense);
    unawaited(_syncService.syncExpense(expense).catchError((_) {}));
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
    unawaited(_syncService.syncExpense(expense).catchError((_) {}));
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _dbHelper.deleteExpense(id);
    unawaited(_syncService.deleteExpense(id).catchError((_) {}));
  }

  @override
  Future<Budget?> getBudget(int year, int month) async {
    return await _dbHelper.getBudgetForMonth(year, month);
  }

  @override
  Future<void> saveBudget(Budget budget) async {
    await _dbHelper.setBudgetForMonth(budget);
    unawaited(_syncService.syncBudget(budget).catchError((_) {}));
  }

  @override
  Future<void> seedRealisticSampleData() async {
    await _dbHelper.seedRealisticSampleData();
  }

  @override
  Future<void> clearAllData() async {
    await _dbHelper.clearAllExpenses();
    unawaited(_syncService.clearAllCloudExpenses().catchError((_) {}));
  }
}
