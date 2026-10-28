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

  ExpenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

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
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _dbHelper.deleteExpense(id);
  }

  @override
  Future<Budget?> getBudget(int year, int month) async {
    return await _dbHelper.getBudgetForMonth(year, month);
  }

  @override
  Future<void> saveBudget(Budget budget) async {
    await _dbHelper.setBudgetForMonth(budget);
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
