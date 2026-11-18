import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:royal_spend/core/theme/app_theme.dart';
import 'package:royal_spend/data/models/budget.dart';
import 'package:royal_spend/data/models/expense.dart';
import 'package:royal_spend/data/repositories/expense_repository.dart';
import 'package:royal_spend/data/repositories/settings_repository.dart';
import 'package:royal_spend/providers/app_lock_provider.dart';
import 'package:royal_spend/providers/expense_provider.dart';
import 'package:royal_spend/providers/profile_image_provider.dart';
import 'package:royal_spend/providers/quick_log_provider.dart';
import 'package:royal_spend/providers/settings_provider.dart';
import 'package:royal_spend/providers/travel_provider.dart';
import 'package:royal_spend/ui/screens/profile_settings_screen.dart';
import 'package:royal_spend/ui/widgets/privacy_policy_sheet.dart';

import 'travel_multi_plan_isolation_test.dart';

class _FakeExpenseRepo extends IExpenseRepository {
  final List<Expense> _expenses = [];

  @override
  Future<void> addExpense(Expense expense) async => _expenses.add(expense);
  @override
  Future<void> clearAllData() async => _expenses.clear();
  @override
  Future<void> deleteExpense(String id) async =>
      _expenses.removeWhere((e) => e.id == id);
  @override
  Future<List<Expense>> getAllExpenses() async => List.from(_expenses);
  @override
  Future<Budget?> getBudget(int year, int month) async => null;
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async =>
      List.from(_expenses);
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Privacy Policy Document & Compliance Verification', () {
    test('PRIVACY_POLICY.md exists and contains comprehensive legal clauses', () {
      final file = File('PRIVACY_POLICY.md');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Entity & Contact
      expect(content, contains('Royal Shubham Pixel Labs'));
      expect(content, contains('royalshubhampixellabs@gmail.com'));
      expect(content, contains('subhamsoudeep@gmail.com'));
      expect(content, isNot(contains('https://sites.google.com/view/royal-pixels-privacy/home')));
      expect(content, contains('https://sites.google.com/view/royalspend/home'));

      // Core Guarantees & Play Store Compliance
      expect(content, contains('Financial Services Clarification'));
      expect(content, contains('Personal Budgeting Utility'));
      expect(content, contains('Secure Enclave'));
      expect(content, contains('Trusted Execution Environment'));
      expect(content, contains('offline-first'));
      expect(content, contains('royal_spend.db'));
      expect(content, contains('Zero Data Selling'));

      // Regulations
      expect(content, contains('GDPR'));
      expect(content, contains('CCPA'));
      expect(content, contains('Digital Personal Data Protection Act'));

      // Data deletion
      expect(content, contains('Delete My Royal Spend Account'));
      expect(content, contains('thirty (30) days'));
    });

    test('privacy_policy.html exists and is complete standalone webpage', () {
      final file = File('privacy_policy.html');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('<!DOCTYPE html>'));
      expect(content, contains('Privacy Policy'));
      expect(content, contains('Royal Shubham Pixel Labs'));
      expect(content, contains('royalshubhampixellabs@gmail.com'));
      expect(content, isNot(contains('https://sites.google.com/view/royal-pixels-privacy/home')));
      expect(content, contains('https://sites.google.com/view/royalspend/home'));
    });
  });

  group('Privacy Policy In-App UI Verification', () {
    testWidgets('PrivacyPolicySheet renders all sections cleanly in Dark Mode',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivacyPolicySheet(isDark: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('Royal Spend • Royal Shubham Pixel Labs'), findsOneWidget);
      final buttonFinder = find.text('Contact Privacy & Support Team');
      await tester.scrollUntilVisible(buttonFinder, 200);
      expect(buttonFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrivacyPolicySheet renders without overflow in wide landscape',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivacyPolicySheet(isDark: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileSettingsScreen exposes Privacy Policy tile',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsRepo = SettingsRepository();
      final settingsProv = SettingsProvider(repository: settingsRepo);
      final expenseRepo = _FakeExpenseRepo();
      final expenseProv = ExpenseProvider(repository: expenseRepo);
      final travelRepo = MockTravelRepository();
      final travelProv = TravelProvider(repository: travelRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProv),
            ChangeNotifierProvider.value(value: expenseProv),
            ChangeNotifierProvider(create: (_) => QuickLogProvider()),
            ChangeNotifierProvider.value(value: travelProv),
            ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
            ChangeNotifierProvider(create: (_) => AppLockProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ProfileSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal Legal & Privacy and About sections
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();

      final privacyFinder = find.text('Privacy Policy');
      expect(privacyFinder, findsWidgets);
      expect(find.text('LEGAL & PRIVACY'), findsOneWidget);
      expect(find.text('https://sites.google.com/view/royalspend/home'), findsWidgets);
    });
  });
}
