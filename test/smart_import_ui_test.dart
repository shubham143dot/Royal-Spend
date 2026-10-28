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

class _FakeExpenseRepo implements IExpenseRepository {
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
  testWidgets('AddEditExpenseSheet renders Manual Entry and Smart Import modes', (tester) async {
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

    // Verify Title and Tabs
    expect(find.text('Record Expense'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);
    expect(find.text('Smart Import'), findsOneWidget);

    // Initial default is Manual Entry
    expect(find.text('EXPENSE AMOUNT'), findsOneWidget);
    expect(find.text('TITLE / MERCHANT'), findsOneWidget);

    // Switch to Smart Import
    await tester.tap(find.text('Smart Import'));
    await tester.pumpAndSettle();

    // Verify Smart Import options: Upload Image and Take Photo
    expect(find.text('Upload Image'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('100% On-Device & Private'), findsOneWidget);

    // Switch back to Manual Entry
    await tester.tap(find.text('Manual Entry'));
    await tester.pumpAndSettle();

    expect(find.text('EXPENSE AMOUNT'), findsOneWidget);
    expect(find.text('TITLE / MERCHANT'), findsOneWidget);
  });

  testWidgets('Editing an existing expense directly shows Edit Expense without mode switch', (tester) async {
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
    // Mode switcher should not be visible when editing existing
    expect(find.text('Smart Import'), findsNothing);
  });
}
