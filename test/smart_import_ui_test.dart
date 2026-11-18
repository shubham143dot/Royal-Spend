import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/ui/screens/add_edit_expense_sheet.dart';

class _FakeExpenseRepo extends IExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<void> addExpense(Expense expense) async => _expenses.add(expense);
  @override
  Future<void> clearAllData() async => _expenses.clear();
  @override
  Future<void> deleteExpense(String id) async => _expenses.removeWhere((e) => e.id == id);
  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_expenses);
  @override
  Future<Budget?> getBudget(int year, int month) async => null;
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async => List.from(_expenses);
  @override
  Future<void> saveBudget(Budget budget) async {}
  @override
  Future<void> seedRealisticSampleData() async {}
  @override
  Future<void> updateExpense(Expense expense) async {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) _expenses[idx] = expense;
  }
}

void main() {
  testWidgets('AddEditExpenseSheet renders direct manual entry with NO Smart Import feature', (tester) async {
    final settingsRepo = SettingsRepository();
    final settingsProvider = SettingsProvider(repository: settingsRepo);
    final expenseRepo = _FakeExpenseRepo();
    final expenseProvider = ExpenseProvider(repository: expenseRepo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AddEditExpenseSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title is Record Expense
    expect(find.text('Record Expense'), findsOneWidget);

    // Verify Smart Import and Mode Switchers are completely removed
    expect(find.text('Smart Import'), findsNothing);
    expect(find.text('Manual Entry'), findsNothing);
    expect(find.text('Upload Image'), findsNothing);
    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('100% On-Device & Private'), findsNothing);

    // Manual entry fields must be immediately visible
    expect(find.text('EXPENSE AMOUNT'), findsOneWidget);
    expect(find.text('TITLE / MERCHANT'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('DATE & TIME'), findsOneWidget);
    expect(find.text('PAYMENT METHOD'), findsOneWidget);
    expect(find.text('Save Expense'), findsOneWidget);
  });

  testWidgets('Editing an existing expense shows Edit Expense without any Smart Import controls', (tester) async {
    final settingsRepo = SettingsRepository();
    final settingsProvider = SettingsProvider(repository: settingsRepo);
    final expenseRepo = _FakeExpenseRepo();
    final expenseProvider = ExpenseProvider(repository: expenseRepo);

    final existingExpense = Expense(
      id: 'test-123',
      title: 'Espresso at Cafe',
      amount: 220.0,
      categoryId: 'food',
      date: DateTime(2026, 10, 25),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AddEditExpenseSheet(
              expenseToEdit: existingExpense,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Expense'), findsOneWidget);
    expect(find.text('Update Expense'), findsOneWidget);
    expect(find.text('Smart Import'), findsNothing);
    expect(find.text('Manual Entry'), findsNothing);
  });
}
