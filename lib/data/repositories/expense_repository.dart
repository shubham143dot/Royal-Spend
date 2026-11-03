import 'dart:async';
import '../../core/services/firestore/firestore_sync_service.dart';
import '../database/database_helper.dart';
import '../models/budget.dart';
import '../models/expense.dart';

abstract class IExpenseRepository {
  Future<List<Expense>> getAllExpenses();
  Future<List<Expense>> getExpensesForMonth(int year, int month);
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
  Future<void> addExpense(Expense expense) async {
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
  }
}
